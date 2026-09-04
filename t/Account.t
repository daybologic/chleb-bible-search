#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package FakeAccountMemcached;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({ data => {}, ttl => {} }, $class);
}

sub add {
	my ($self, $key, $value, $ttl) = @_;
	return 0 if (exists($self->{data}->{$key}));
	$self->{data}->{$key} = $value;
	$self->{ttl}->{$key} = $ttl;
	return 1;
}

sub incr {
	my ($self, $key) = @_;
	return unless (exists($self->{data}->{$key}));
	$self->{data}->{$key}++;
	return $self->{data}->{$key};
}

## no critic (NamingConventions::ProhibitAmbiguousNames)
sub set {
	my ($self, $key, $value, $ttl) = @_;
	$self->{data}->{$key} = $value;
	$self->{ttl}->{$key} = $ttl;
	return 1;
}

sub get {
	my ($self, $key) = @_;
	return $self->{data}->{$key};
}

package FakeAccountRepository;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub create {
	my ($self, $attributes) = @_;
	return {
		%{ $attributes },
		id => 123,
		status => 'pending',
	};
}

package AccountTests;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Account::Repository;
use Chleb::Account::Repository::Memcached;
use Chleb::DI::MockLogger;
use Chleb::Server::Moose;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;
	$self->sut(Chleb::Server::Moose->new());
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return 0;
}

sub testMemcachedCreatesPermanentSequentialAccounts {
	my ($self) = @_;
	plan tests => 10;

	my $client = FakeAccountMemcached->new();
	my $store = Chleb::Account::Repository::Memcached->new({
		client => $client,
		dic => $self->sut->dic,
	});
	my $first = $store->create({ username => 'john.smith', email => 'john.smith@example.com', name => 'John Smith' });
	my $secondAccount = $store->create({ username => 'jane.smith', email => 'jane.smith@example.com', name => 'Jane Smith' });

	is($first->{id}, 1, 'first account ID is 1');
	is($secondAccount->{id}, 2, 'second account ID is 2');
	is($first->{status}, 'pending', 'new account status is pending');
	is($client->{ttl}->{ 'chleb-accounts:next-id' }, 0, 'account ID counter has permanent TTL');
	is($client->{ttl}->{ 'chleb-accounts:account:1' }, 0, 'first account has permanent TTL');
	is($client->{ttl}->{ 'chleb-accounts:account:2' }, 0, 'second account has permanent TTL');

	my $loaded = $store->load(1);
	is($loaded->{username}, 'john.smith', 'stored account can be loaded');
	is($loaded->{email}, 'john.smith@example.com', 'stored email can be loaded');
	is($loaded->{name}, 'John Smith', 'stored name can be loaded');
	is($Chleb::Account::Repository::Memcached::PREFIX, 'chleb-accounts', 'account prefix is fixed');

	return 0;
}

sub testRepositoryUsesMemcachedBackend {
	my ($self) = @_;
	plan tests => 1;

	my $repo = Chleb::Account::Repository->new({ dic => $self->sut->dic });
	## no critic (Subroutines::ProhibitPrivateSubs)
	isa_ok($repo->__backend(), 'Chleb::Account::Repository::Memcached', 'repository backend');

	return 0;
}

sub testSignupReturnsJsonApiAccount {
	my ($self) = @_;
	plan tests => 1;

	$self->sut->dic->accountRepo(FakeAccountRepository->new());
	## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my $result = $self->sut->__accountSignup({
		data => {
			type => 'account',
			attributes => {
				username => 'john.smith',
				email => 'john.smith@example.com',
				name => 'John Smith',
			},
		},
	});

	is_deeply($result, {
		data => {
			type => 'account',
			id => '123',
			attributes => {
			username => 'john.smith',
			email => 'john.smith@example.com',
			name => 'John Smith',
			status => 'pending',
			},
		},
	}, 'signup response is JSON:API account data');

	return 0;
}

sub testSignupRejectsMissingAttribute {
	my ($self) = @_;
	plan tests => 1;

	$self->sut->dic->accountRepo(FakeAccountRepository->new());
	## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my $evalOk; $evalOk = eval {
		$self->sut->__accountSignup({
			data => {
				type => 'account',
				attributes => { username => 'john.smith', email => 'john.smith@example.com' },
			},
		});
		1;
	} or $evalOk = 0;

	is($evalOk, 0, 'signup rejects missing account attribute');

	return 0;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(AccountTests->new->run());
