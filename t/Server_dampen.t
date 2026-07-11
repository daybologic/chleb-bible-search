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

use Chleb::DI::Config;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server::Dampen;
use File::Temp qw(tempdir);
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	my $dir = tempdir(CLEANUP => 1);
	open(my $fh, '>', "$dir/main.yaml") or die("open $dir/main.yaml: $!");
	print {$fh} <<'EOF';
rate_limit:
  backend: memory
  session_window_seconds: 60
  session_max_requests: 100
  session_churn_window_seconds: 300
  session_churn_limit: 10
EOF
	close($fh) or die("close $dir/main.yaml: $!");

	my $dic = Chleb::DI::Container->instance;
	$dic->config(Chleb::DI::Config->new({ dic => $dic, path => "$dir/main.yaml" }));
	$dic->logger(Chleb::DI::MockLogger->new());
	$self->sut(Chleb::Server::Dampen->new({ dic => $dic }));
	$self->sut->dic->time->set(2_000_000_000);

	return EXIT_SUCCESS;
}

sub testIpDampenDeniesSameSecond {
	my ($self) = @_;

	is($self->sut->dampen('192.0.2.10'), 0, 'first request in second is allowed');
	is($self->sut->dampen('192.0.2.10'), 1, 'second request in same second is denied');
	$self->sut->dic->time->sleep(1);
	is($self->sut->dampen('192.0.2.10'), 0, 'request in next second is allowed');

	return EXIT_SUCCESS;
}

sub testSessionWindowAllows {
	my ($self) = @_;

	my $token = 'token-allow-test';
	my $allowed = 1;
	for (my $requestI = 1; $requestI <= 100; $requestI++) {
		$allowed &&= ($self->sut->dampenSession($token) == 0);
	}
	ok($allowed, 'requests within limit are allowed');

	return EXIT_SUCCESS;
}

sub testSessionWindowDenies {
	my ($self) = @_;

	my $token = 'token-deny-test';
	for (1..100) {
		$self->sut->dampenSession($token);
	}
	is($self->sut->dampenSession($token), 1, 'request over limit is denied');

	return EXIT_SUCCESS;
}

sub testSessionWindowExpiry {
	my ($self) = @_;

	my $token = 'token-expiry-test';
	for (1..100) {
		$self->sut->dampenSession($token);
	}
	$self->sut->dic->time->sleep(61);
	is($self->sut->dampenSession($token), 0, 'expired timestamps are pruned and request is allowed');

	return EXIT_SUCCESS;
}

sub testChurnAllows {
	my ($self) = @_;

	my $ip  = '192.0.2.1';
	my $allowed = 1;
	for my $tokenI (1..10) {
		$allowed &&= ($self->sut->dampenChurn($ip, "token-$tokenI") == 0);
	}
	ok($allowed, 'tokens within churn limit are allowed');

	return EXIT_SUCCESS;
}

sub testChurnDenies {
	my ($self) = @_;

	my $ip  = '192.0.2.2';
	for my $tokenI (1..10) {
		$self->sut->dampenChurn($ip, "token-$tokenI");
	}
	is($self->sut->dampenChurn($ip, 'token-11'), 1, 'exceeding churn limit is denied');

	return EXIT_SUCCESS;
}

sub testChurnExpiry {
	my ($self) = @_;

	my $ip  = '192.0.2.3';
	for my $tokenI (1..10) {
		$self->sut->dampenChurn($ip, "token-$tokenI");
	}
	$self->sut->dic->time->sleep(301);
	is($self->sut->dampenChurn($ip, 'token-fresh'), 0, 'expired churn entries are pruned and request is allowed');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(DampenServerTests->new->run());
