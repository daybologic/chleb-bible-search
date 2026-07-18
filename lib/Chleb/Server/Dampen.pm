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

package Chleb::Server::Dampen;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Server::Dampen::Store::Memcached;
use Chleb::Server::Dampen::Store::Memory;

=head1 NAME

Chleb::Server::Dampen

=head1 DESCRIPTION

Rate-limiting facility for L<Chleb::Server::Moose>.

Three tiers of protection are provided:

=over

=item *

C<dampen> - one request per second per IP address for clients without a session cookie.

=item *

C<dampenSession> - sliding window rate limit for session cookie holders, configurable
via C<rate_limit.session_window_seconds> and C<rate_limit.session_max_requests> in
C<main.yaml>.

=item *

C<dampenChurn> - detects clients that repeatedly discard their session cookie to bypass
the session-based limit, keyed by IP address.  Configurable via
C<rate_limit.session_churn_window_seconds> and C<rate_limit.session_churn_limit>.

=back

When configured, shared memcached storage is used so limits are enforced across
worker processes.  If memcached is unavailable, this object warns and falls back
to per-process memory storage.

=cut

=head1 ATTRIBUTES

=over

=item C<__memoryStore>

The per-process fallback store.

=cut

has __memoryStore => (
	isa => 'Chleb::Server::Dampen::Store::Memory',
	is => 'rw',
	lazy => 1,
	default => sub { Chleb::Server::Dampen::Store::Memory->new({ dic => $_[0]->dic }) },
);

=item C<__sharedStore>

Optional shared store, currently C<memcached> when configured.

=cut

has __sharedStore => (is => 'rw', lazy => 1, builder => '__makeSharedStore');

=back

=head1 METHODS

=over

=item C<dampen($ipAddress)>

Enforces a one-request-per-second limit for unauthenticated clients (those without a
session cookie).  C<$ipAddress> is the remote address string.

Returns C<1> if the request should be denied, C<0> otherwise.

=cut

sub dampen {
	my ($self, $ipAddress) = @_;
	my $currentTime = $self->dic->time->get();

	my $blocked = $self->__checkStore('dampen', $ipAddress, $currentTime);
	if ($blocked) {
		$self->dic->logger->warn(sprintf('Saw %s already this second, denying request', $ipAddress));
		return 1;
	}

	return 0;
}

=item C<dampenSession($tokenValue)>

Enforces a sliding window rate limit for authenticated clients.  C<$tokenValue> is
the raw session token string.

The window size and maximum request count are read from the server configuration
(C<rate_limit.session_window_seconds>, default 60; C<rate_limit.session_max_requests>,
default 100).

Returns C<1> if the request should be denied, C<0> otherwise.

=cut

sub dampenSession {
	my ($self, $tokenValue) = @_;

	my $windowSecs  = $self->dic->config->get('rate_limit', 'session_window_seconds', 60);
	my $maxRequests = $self->dic->config->get('rate_limit', 'session_max_requests',   100);
	my $currentTime = $self->dic->time->get();

	if ($self->__checkStore('dampenSession', $tokenValue, $currentTime, $windowSecs, $maxRequests)) {
		$self->dic->logger->warn(sprintf(
			'Session %s exceeded %d requests in %ds window, denying',
			substr($tokenValue, 0, 8), $maxRequests, $windowSecs,
		));
		return 1;
	}

	return 0;
}

=item C<dampenChurn($ipAddress, $tokenValue)>

Detects clients that discard and replace their session cookie to bypass the
per-session rate limit.  C<$ipAddress> is the remote address string;
C<$tokenValue> is the raw session token string.

The lookback window and maximum number of distinct tokens are read from the server
configuration (C<rate_limit.session_churn_window_seconds>, default 300;
C<rate_limit.session_churn_limit>, default 10).

Returns C<1> if the request should be denied, C<0> otherwise.

=cut

sub dampenChurn {
	my ($self, $ipAddress, $tokenValue) = @_;

	my $churnWindow = $self->dic->config->get('rate_limit', 'session_churn_window_seconds', 300);
	my $churnLimit  = $self->dic->config->get('rate_limit', 'session_churn_limit',          10);
	my $currentTime = $self->dic->time->get();

	if ($self->__checkStore('dampenChurn', {
		ipAddress    => $ipAddress,
		tokenValue   => $tokenValue,
		currentTime  => $currentTime,
		churnWindow  => $churnWindow,
		churnLimit   => $churnLimit,
	})) {
		$self->dic->logger->warn(sprintf(
			'IP %s burned through more than %d session tokens in %ds, denying',
			$ipAddress, $churnLimit, $churnWindow,
		));
		return 1;
	}

	return 0;
}

=item C<__checkStore($method, @args)>

Run a dampening operation against the shared store when one is configured and
available, falling back to the per-process memory store when the shared store
returns C<undef>.

=cut

sub __checkStore {
	my ($self, $method, @args) = @_;

	if (my $store = $self->__sharedStore) {
		my $result = $store->$method(@args);
		return $result if (defined($result));
	}

	return $self->__memoryStore->$method(@args);
}

=item C<__makeSharedStore()>

Build the configured shared dampening store.  C<memcached> creates a
L<Chleb::Server::Dampen::Store::Memcached>; C<memory> disables shared storage.
Unknown backends are logged and treated as C<memory>.

=cut

# Invoked by Moose as the lazy builder for the __sharedStore attribute.
sub __makeSharedStore { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;

	my $backend = $self->dic->config->get('rate_limit', 'backend', 'memory');
	return if ($backend eq 'memory');
	if ($backend eq 'memcached') {
		return Chleb::Server::Dampen::Store::Memcached->new({ dic => $self->dic });
	}

	$self->dic->logger->warn("Unknown rate_limit backend '$backend', falling back to per-process memory store");
	return;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
