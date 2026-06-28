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

All in-memory stores will leak over time.  A future improvement would switch to a
shared disk-based or memcached backend so that limits are enforced across worker
processes.

=cut

=head1 ATTRIBUTES

=over

=item C<__dampenTime>

Maps IP address to the epoch second of the most recent unauthenticated request.
Used by C<dampen> to enforce the one-request-per-second floor.

=cut

# FIXME: Will leak memory over time, switch to a disk-based cache, or memcached
# additionally, this is a per-process store right now, which is probably not effective enough.
has __dampenTime => (isa => 'HashRef[Str]', is => 'rw', lazy => 1, default => sub {{}});

=item C<__sessionWindows>

Maps session token value to an array of epoch timestamps representing requests
made within the current sliding window.  Timestamps older than
C<rate_limit.session_window_seconds> are pruned on each access.

=cut

has __sessionWindows => (isa => 'HashRef[ArrayRef[Int]]', is => 'rw', lazy => 1, default => sub {{}});

=item C<__sessionsByIp>

Maps IP address to an array of C<[$tokenValue, $firstSeenEpoch]> pairs recording
every distinct session token seen from that address within the churn detection window.
Used by C<dampenChurn> to identify clients rotating tokens to evade rate limits.

=cut

has __sessionsByIp => (isa => 'HashRef[ArrayRef]', is => 'rw', lazy => 1, default => sub {{}});

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
	my $currentTime = time();

	my $previousTime = $self->__dampenTime->{$ipAddress};
	if ($previousTime && $previousTime == $currentTime) {
		$self->dic->logger->warn(sprintf('Saw %s already this second, denying request', $ipAddress));
		return 1;
	}

	$self->__dampenTime->{$ipAddress} = $currentTime;
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
	my $currentTime = time();
	my $cutoff      = $currentTime - $windowSecs;

	my $timestamps = $self->__sessionWindows->{$tokenValue} //= [];
	@{$timestamps} = grep { $_ > $cutoff } @{$timestamps};

	if (scalar(@{$timestamps}) >= $maxRequests) {
		$self->dic->logger->warn(sprintf(
			'Session %s exceeded %d requests in %ds window, denying',
			substr($tokenValue, 0, 8), $maxRequests, $windowSecs,
		));
		return 1;
	}

	push @{$timestamps}, $currentTime;
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
	my $currentTime = time();
	my $cutoff      = $currentTime - $churnWindow;

	my $entries = $self->__sessionsByIp->{$ipAddress} //= [];
	@{$entries} = grep { $_->[1] > $cutoff } @{$entries};

	my %seen = map { $_->[0] => 1 } @{$entries};
	unless ($seen{$tokenValue}) {
		push @{$entries}, [ $tokenValue, $currentTime ];
	}

	my $distinctTokens = scalar(keys %{{ map { $_->[0] => 1 } @{$entries} }});
	if ($distinctTokens > $churnLimit) {
		$self->dic->logger->warn(sprintf(
			'IP %s burned through %d session tokens in %ds, denying',
			$ipAddress, $distinctTokens, $churnWindow,
		));
		return 1;
	}

	return 0;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
