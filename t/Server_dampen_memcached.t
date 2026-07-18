## no critic (RegularExpressions::RequireExtendedFormatting)
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
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

package FakeMemcached;
use strict;
use warnings;
use Carp qw(croak);

sub new {
	my ($class, $args) = @_;
	return bless({ data => {}, down => $args->{down} // 0 }, $class);
}

sub set { ## no critic (NamingConventions::ProhibitAmbiguousNames)
	my ($self, $key, $value) = @_;
	return if ($self->{down});
	$self->{data}->{$key} = $value;
	return 1;
}

sub add {
	my ($self, $key, $value) = @_;
	return if ($self->{down});
	return 0 if (exists($self->{data}->{$key}));
	$self->{data}->{$key} = $value;
	return 1;
}

sub incr {
	my ($self, $key) = @_;
	return if ($self->{down});
	return unless (exists($self->{data}->{$key}));
	$self->{data}->{$key}++;
	return $self->{data}->{$key};
}

sub get {
	my ($self, $key) = @_;
	return if ($self->{down});
	return $self->{data}->{$key};
}

package FakeUnavailableStore;
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub dampen {
	return;
}

sub dampenSession {
	return;
}

sub dampenChurn {
	return;
}

package DampenMemcachedTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::DI::Config;
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server::Dampen;
use Chleb::Server::Dampen::Store::Memcached;
use File::Temp qw(tempdir);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

has dic => (is => 'rw', isa => 'Chleb::DI::Container');

sub setUp {
	my ($self) = @_;

	my $dir = tempdir(CLEANUP => 1);
	open(my $fh, '>', "$dir/main.yaml") or croak("open $dir/main.yaml: $!");
	print {$fh} <<'EOF';
rate_limit:
  backend_memcached:
    prefix: test:dampen
EOF
	close($fh) or croak("close $dir/main.yaml: $!");

	$self->dic(Chleb::DI::Container->instance);
	$self->dic->config(Chleb::DI::Config->new({ dic => $self->dic, path => $dir }));
	$self->dic->logger(Chleb::DI::MockLogger->new());

	return EXIT_SUCCESS;
}

sub testIpDampen {
	my ($self) = @_;
	my $store = Chleb::Server::Dampen::Store::Memcached->new({
		dic => $self->dic,
		client => FakeMemcached->new({}),
	});

	is($store->dampen('192.0.2.1', 2_000_000_000), 0, 'first IP request is allowed');
	is($store->dampen('192.0.2.1', 2_000_000_000), 1, 'second IP request in same second is denied');
	is($store->dampen('192.0.2.1', 2_000_000_001), 0, 'IP request in next second is allowed');

	return EXIT_SUCCESS;
}

sub testSessionCounter {
	my ($self) = @_;
	my $store = Chleb::Server::Dampen::Store::Memcached->new({
		dic => $self->dic,
		client => FakeMemcached->new({}),
	});

	is($store->dampenSession('token-a', 2_000_000_000, 60, 3), 0, 'session request 1 is allowed');
	is($store->dampenSession('token-a', 2_000_000_000, 60, 3), 0, 'session request 2 is allowed');
	is($store->dampenSession('token-a', 2_000_000_000, 60, 3), 0, 'session request 3 is allowed');
	is($store->dampenSession('token-a', 2_000_000_000, 60, 3), 1, 'session request 4 is denied');
	is($store->dampenSession('token-a', 2_000_000_060, 60, 3), 0, 'next bucket is allowed');

	return EXIT_SUCCESS;
}

sub testChurnCounter {
	my ($self) = @_;
	my $store = Chleb::Server::Dampen::Store::Memcached->new({
		dic => $self->dic,
		client => FakeMemcached->new({}),
	});

	is($store->dampenChurn({ ipAddress => '192.0.2.2', tokenValue => 'token-1', currentTime => 2_000_000_000, churnWindow => 300, churnLimit => 2 }), 0, 'first distinct token is allowed');
	is($store->dampenChurn({ ipAddress => '192.0.2.2', tokenValue => 'token-2', currentTime => 2_000_000_000, churnWindow => 300, churnLimit => 2 }), 0, 'second distinct token is allowed');
	is($store->dampenChurn({ ipAddress => '192.0.2.2', tokenValue => 'token-2', currentTime => 2_000_000_000, churnWindow => 300, churnLimit => 2 }), 0, 'repeat token is not counted again');
	is($store->dampenChurn({ ipAddress => '192.0.2.2', tokenValue => 'token-3', currentTime => 2_000_000_000, churnWindow => 300, churnLimit => 2 }), 1, 'third distinct token is denied');

	return EXIT_SUCCESS;
}

sub testUnavailableReturnsUndef {
	my ($self) = @_;
	my $logger = Chleb::DI::MockLogger->new();
	$self->dic->logger($logger);
	my $store = Chleb::Server::Dampen::Store::Memcached->new({
		dic => $self->dic,
		client => FakeMemcached->new({ down => 1 }),
	});

	ok(!defined($store->dampen('192.0.2.3', 2_000_000_000)), 'unavailable store returns undef');
	$logger->isLogged(qr/falling back to per-process memory store/);

	return EXIT_SUCCESS;
}

sub testDampenFallsBackToMemory {
	my ($self) = @_;
	my $sut = Chleb::Server::Dampen->new({ dic => $self->dic });
	$sut->__sharedStore(FakeUnavailableStore->new());
	$sut->dic->time->setMockedTime(2_000_000_000);

	is($sut->dampen('192.0.2.4'), 0, 'first request falls back and is allowed');
	is($sut->dampen('192.0.2.4'), 1, 'second request falls back and is denied');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(DampenMemcachedTests->new->run());
