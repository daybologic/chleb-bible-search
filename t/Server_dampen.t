#!/usr/bin/env perl
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

package DampenServerTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server::Dampen;
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server::Dampen->new());

	return EXIT_SUCCESS;
}

sub testSessionWindowAllows {
	my ($self) = @_;

	my $token = 'token-allow-test';
	my $now   = time();

	# inject 99 timestamps within the window — 100th should be allowed
	$self->sut->{__sessionWindows}{$token} = [ ($now) x 99 ];
	is($self->sut->dampenSession($token), 0, '100th request within limit is allowed');

	return EXIT_SUCCESS;
}

sub testSessionWindowDenies {
	my ($self) = @_;

	my $token = 'token-deny-test';
	my $now   = time();

	# inject 100 timestamps — next request must be denied
	$self->sut->{__sessionWindows}{$token} = [ ($now) x 100 ];
	is($self->sut->dampenSession($token), 1, 'request over limit is denied');

	return EXIT_SUCCESS;
}

sub testSessionWindowExpiry {
	my ($self) = @_;

	my $token = 'token-expiry-test';
	my $old   = time() - 120; # 2 minutes ago, outside default 60s window

	# 100 old timestamps — all should be pruned, so request is allowed
	$self->sut->{__sessionWindows}{$token} = [ ($old) x 100 ];
	is($self->sut->dampenSession($token), 0, 'expired timestamps are pruned and request is allowed');

	return EXIT_SUCCESS;
}

sub testChurnAllows {
	my ($self) = @_;

	my $ip  = '192.0.2.1';
	my $now = time();

	# 9 distinct tokens already seen; new one brings total to 10, exactly at limit — should be allowed
	my @entries = map { [ "token-$_", $now ] } (1..9);
	$self->sut->{__sessionsByIp}{$ip} = \@entries;
	is($self->sut->dampenChurn($ip, 'token-10'), 0, 'exactly at churn limit is allowed');

	return EXIT_SUCCESS;
}

sub testChurnDenies {
	my ($self) = @_;

	my $ip  = '192.0.2.2';
	my $now = time();

	# 11 distinct tokens already seen — next should be denied
	my @entries = map { [ "token-$_", $now ] } (1..11);
	$self->sut->{__sessionsByIp}{$ip} = \@entries;
	is($self->sut->dampenChurn($ip, 'token-new'), 1, 'exceeding churn limit is denied');

	return EXIT_SUCCESS;
}

sub testChurnExpiry {
	my ($self) = @_;

	my $ip  = '192.0.2.3';
	my $old = time() - 600; # 10 minutes ago, outside default 300s window

	# 11 old tokens — all should be pruned, so request is allowed
	my @entries = map { [ "token-$_", $old ] } (1..11);
	$self->sut->{__sessionsByIp}{$ip} = \@entries;
	is($self->sut->dampenChurn($ip, 'token-fresh'), 0, 'expired churn entries are pruned and request is allowed');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(DampenServerTests->new->run());
