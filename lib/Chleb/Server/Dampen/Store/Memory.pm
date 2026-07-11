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

package Chleb::Server::Dampen::Store::Memory;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

=head1 NAME

Chleb::Server::Dampen::Store::Memory - per-process dampening state

=head1 DESCRIPTION

In-memory fallback store for L<Chleb::Server::Dampen>.  This keeps the original
per-process behavior for deployments where shared storage is unavailable.

=cut

=head1 ATTRIBUTES

=over

=item C<__dampenTime>

Last observed request time by IP address for the one-request-per-second
unauthenticated limit.

=cut

has __dampenTime => (isa => 'HashRef[Str]', is => 'rw', lazy => 1, default => sub {{}});

=item C<__sessionWindows>

Sliding request timestamp windows by session token value.

=cut

has __sessionWindows => (isa => 'HashRef[ArrayRef[Int]]', is => 'rw', lazy => 1, default => sub {{}});

=item C<__sessionsByIp>

Recent session token values by IP address for churn detection.

=cut

has __sessionsByIp => (isa => 'HashRef[ArrayRef]', is => 'rw', lazy => 1, default => sub {{}});

=back

=head1 METHODS

=over

=item C<dampen($ipAddress, $currentTime)>

Applies the one-request-per-second unauthenticated IP limit in process memory.
Returns C<1> when the request should be blocked and C<0> when it should be
allowed.

=cut

sub dampen {
	my ($self, $ipAddress, $currentTime) = @_;

	my $previousTime = $self->__dampenTime->{$ipAddress};
	if ($previousTime && $previousTime == $currentTime) {
		return 1;
	}

	$self->__dampenTime->{$ipAddress} = $currentTime;
	return 0;
}

=item C<dampenSession($tokenValue, $currentTime, $windowSecs, $maxRequests)>

Applies the per-session request limit by retaining timestamps inside the
configured sliding window.

Returns C<1> when the request should be blocked and C<0> when it should be
allowed.

=cut

sub dampenSession {
	my ($self, $tokenValue, $currentTime, $windowSecs, $maxRequests) = @_;
	my $cutoff = $currentTime - $windowSecs;

	my $timestamps = $self->__sessionWindows->{$tokenValue} //= [];
	@{$timestamps} = grep { $_ > $cutoff } @{$timestamps};

	if (scalar(@{$timestamps}) >= $maxRequests) {
		return 1;
	}

	push(@{$timestamps}, $currentTime);
	return 0;
}

=item C<dampenChurn($ipAddress, $tokenValue, $currentTime, $churnWindow, $churnLimit)>

Applies the session-token churn limit by tracking distinct token values recently
seen from an IP address.

Returns C<1> when the request should be blocked and C<0> when it should be
allowed.

=cut

sub dampenChurn {
	my ($self, $ipAddress, $tokenValue, $currentTime, $churnWindow, $churnLimit) = @_;
	my $cutoff = $currentTime - $churnWindow;

	my $entries = $self->__sessionsByIp->{$ipAddress} //= [];
	@{$entries} = grep { $_->[1] > $cutoff } @{$entries};

	my %seen = map { $_->[0] => 1 } @{$entries};
	unless ($seen{$tokenValue}) {
		push(@{$entries}, [ $tokenValue, $currentTime ]);
	}

	my $distinctTokens = scalar(keys %{{ map { $_->[0] => 1 } @{$entries} }});
	return $distinctTokens > $churnLimit ? 1 : 0;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
