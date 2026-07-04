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

has client => (is => 'ro', init_arg => 'client', predicate => '__hasClient');
has __clientObject => (is => 'rw', lazy => 1, builder => '__makeClient');
has __available => (is => 'rw', isa => 'Bool', lazy => 1, builder => '__makeAvailable');
has __warned => (is => 'rw', isa => 'Bool', default => 0);
has __prefix => (is => 'ro', isa => 'Str', lazy => 1, builder => '__makePrefix');

sub available {
	my ($self) = @_;
	return $self->__available;
}

sub dampen {
	my ($self, $ipAddress, $currentTime) = @_;
	return unless ($self->available);

	my $key = $self->__key('ip', $ipAddress, int($currentTime));
	my $added = $self->__call(add => $key, 1, 2);
	return unless (defined($added));

	return $added ? 0 : 1;
}

sub dampenSession {
	my ($self, $tokenValue, $currentTime, $windowSecs, $maxRequests) = @_;
	return unless ($self->available);

	my $bucket = int($currentTime / $windowSecs);
	my $key = $self->__key('session', $tokenValue, $bucket);
	my $count = $self->__increment($key, $windowSecs + 1);
	return unless (defined($count));

	return $count > $maxRequests ? 1 : 0;
}

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

sub __client {
	my ($self) = @_;
	return $self->client if ($self->__hasClient);
	return $self->__clientObject;
}

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

sub __key {
	my ($self, @parts) = @_;
	my @encoded = map { sha1_hex($_ // '') } @parts;
	return join(':', $self->__prefix, @encoded);
}

sub __makePrefix {
	my ($self) = @_;
	my $config = $self->dic->config->get('rate_limit', 'backend_memcached', {});
	return $config->{prefix} // 'chleb:dampen';
}

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

__PACKAGE__->meta->make_immutable;

1;
