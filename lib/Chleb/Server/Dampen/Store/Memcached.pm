#!/usr/bin/perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the Daybo Logic nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package Chleb::Server::Dampen::Store::Memcached;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Digest::SHA qw(sha1_hex);
use English qw(-no_match_vars);

=head1 NAME

Chleb::Server::Dampen::Store::Memcached - shared dampening state

=head1 DESCRIPTION

Memcached-backed store for L<Chleb::Server::Dampen>.  The methods return
C<undef> if memcached is unavailable so the caller can fall back to the
per-process memory store without failing the request.

The IP dampener uses atomic C<add>.  Session and churn limits use memcached
counter buckets with short TTLs so worker processes can share state without
serializing mutable arrays.

=cut

=head1 ATTRIBUTES

=over

=item C<client>

Optional pre-built memcached client.  Tests can inject this instead of loading
C<Cache::Memcached> and reading C<main.yaml>.

=cut

has client => (is => 'ro', init_arg => 'client', predicate => '__hasClient');

=item C<__clientObject>

Lazy C<Cache::Memcached> client built from C<rate_limit.backend_memcached>.

=cut

has __clientObject => (is => 'rw', lazy => 1, builder => '__makeClient');

=item C<__available>

Boolean availability flag.  This is cleared when the backend cannot be used so
the caller can fall back to the memory store.

=cut

has __available => (is => 'rw', isa => 'Bool', lazy => 1, builder => '__makeAvailable');

=item C<__warned>

Tracks whether a backend-unavailable warning has already been logged.

=cut

has __warned => (is => 'rw', isa => 'Bool', default => 0);

=item C<__prefix>

Key prefix for dampening data in memcached.

=cut

has __prefix => (is => 'ro', isa => 'Str', lazy => 1, builder => '__makePrefix');

=back

=head1 METHODS

=over

=item C<available()>

Returns true when memcached can currently be used for dampening state.

=cut

sub available {
	my ($self) = @_;
	return $self->__available;
}

=item C<dampen($ipAddress, $currentTime)>

Applies the one-request-per-second unauthenticated IP limit using memcached.
Returns C<1> when the request should be blocked, C<0> when it should be
allowed, or C<undef> when the shared store is unavailable.

=cut

sub dampen {
	my ($self, $ipAddress, $currentTime) = @_;
	return unless ($self->available);

	my $key = $self->__key('ip', $ipAddress, int($currentTime));
	my $added = $self->__call(add => $key, 1, 2);
	return unless (defined($added));

	return $added ? 0 : 1;
}

=item C<dampenSession($tokenValue, $currentTime, $windowSecs, $maxRequests)>

Applies the per-session request limit using a memcached counter bucket.
Returns C<1> when the request should be blocked, C<0> when it should be
allowed, or C<undef> when the shared store is unavailable.

=cut

sub dampenSession {
	my ($self, $tokenValue, $currentTime, $windowSecs, $maxRequests) = @_;
	return unless ($self->available);

	my $bucket = int($currentTime / $windowSecs);
	my $key = $self->__key('session', $tokenValue, $bucket);
	my $count = $self->__increment($key, $windowSecs + 1);
	return unless (defined($count));

	return $count > $maxRequests ? 1 : 0;
}

=item C<dampenChurn($ipAddress, $tokenValue, $currentTime, $churnWindow, $churnLimit)>

Applies the session-token churn limit for an IP address.  Distinct token values
are tracked with C<add>, and a separate counter records how many unique tokens
have appeared in the current bucket.

Returns C<1> when the request should be blocked, C<0> when it should be
allowed, or C<undef> when the shared store is unavailable.

=cut

sub dampenChurn {
	my ($self, $ipAddress, $tokenValue, $currentTime, $churnWindow, $churnLimit) = @_;
	return unless ($self->available);

	my $bucket = int($currentTime / $churnWindow);
	my $tokenKey = $self->__key('churn-token', $ipAddress, $tokenValue, $bucket);
	my $countKey = $self->__key('churn-count', $ipAddress, $bucket);
	my $addedToken = $self->__call(add => $tokenKey, 1, $churnWindow + 1);
	return unless (defined($addedToken));

	my $count;
	if ($addedToken) {
		$count = $self->__increment($countKey, $churnWindow + 1);
	} else {
		$count = $self->__call(get => $countKey) // 0;
	}
	return unless (defined($count));

	return $count > $churnLimit ? 1 : 0;
}

=item C<__makeAvailable()>

Builds the availability flag by creating a client and probing memcached with a
short-lived key.

=cut

sub __makeAvailable {
	my ($self) = @_;

	return 0 unless ($self->__client());

	my $probeKey = $self->__key('probe', $$);
	my $ok = $self->__call(set => $probeKey, 1, 5);
	if ($ok) {
		return 1;
	}

	$self->__warnUnavailable('memcached unavailable for dampening, falling back to per-process memory store');
	return 0;
}

=item C<__client()>

Returns the injected client when present, otherwise returns the lazy client
object.

=cut

sub __client {
	my ($self) = @_;
	return $self->client if ($self->__hasClient);
	return $self->__clientObject;
}

=item C<__makeClient()>

Loads C<Cache::Memcached> and builds a client from
C<rate_limit.backend_memcached.servers>.  Returns C<undef> after logging a
fallback warning if the module or client cannot be created.

=cut

sub __makeClient {
	my ($self) = @_;

	eval {
		require Cache::Memcached;
		Cache::Memcached->import();
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->__warnUnavailable("Cannot load Cache::Memcached for dampening: $evalError");
		return;
	}

	my $config = $self->dic->config->get('rate_limit', 'backend_memcached', {});
	my $servers = $config->{servers} // [ '127.0.0.1:11211' ];
	$servers = [ $servers ] unless (ref($servers) eq 'ARRAY');

	my $client;
	eval {
		$client = Cache::Memcached->new({
			servers => $servers,
			compress_threshold => 10_000,
		});
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->__warnUnavailable("Cannot create memcached client for dampening: $evalError");
		return;
	}

	return $client;
}

=item C<__increment($key, $ttl)>

Atomically increments a memcached counter, creating it with C<add> when needed.
If the key expires between C<add> and C<incr>, it retries once.

=cut

sub __increment {
	my ($self, $key, $ttl) = @_;

	my $added = $self->__call(add => $key, 1, $ttl);
	return unless (defined($added));
	return 1 if ($added);

	my $value = $self->__call(incr => $key);
	return $value if (defined($value));

	$added = $self->__call(add => $key, 1, $ttl);
	return unless (defined($added));
	return 1 if ($added);

	return $self->__call(incr => $key);
}

=item C<__call($method, @args)>

Calls a method on the memcached client.  Backend failures mark the store
unavailable, log a fallback warning, and return C<undef>.

=cut

sub __call {
	my ($self, $method, @args) = @_;

	my $result;
	eval {
		$result = $self->__client()->$method(@args);
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->__available(0);
		$self->__warnUnavailable("memcached dampening operation failed: $evalError");
		return;
	}

	return $result;
}

=item C<__key(@parts)>

Builds a namespaced memcached key.  Key parts are SHA-1 encoded so raw IP
addresses and token values are not stored directly in memcached key names.

=cut

sub __key {
	my ($self, @parts) = @_;
	my @encoded = map { sha1_hex($_ // '') } @parts;
	return join(':', $self->__prefix, @encoded);
}

=item C<__makePrefix()>

Reads the memcached key prefix from C<rate_limit.backend_memcached.prefix>, or
uses C<chleb:dampen> when the setting is absent.

=cut

sub __makePrefix {
	my ($self) = @_;
	my $config = $self->dic->config->get('rate_limit', 'backend_memcached', {});
	return $config->{prefix} // 'chleb:dampen';
}

=item C<__warnUnavailable($message)>

Logs the first shared-store fallback warning for this object.  The message is
normalized to mention the per-process memory fallback.

=cut

sub __warnUnavailable {
	my ($self, $message) = @_;
	return if ($self->__warned);
	$self->__warned(1);
	if ($message !~ m/falling back to per-process memory store/) {
		$message .= '; falling back to per-process memory store';
	}
	$self->dic->logger->warn($message);
	return;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
