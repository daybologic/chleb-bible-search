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

sub delete { ## no critic (Subroutines::ProhibitBuiltinHomonyms)
	my ($self, $key) = @_;
	delete($self->{data}->{$key});
	delete($self->{ttl}->{$key});
	return 1;
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

package FakeNoopAccountRepository;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use Carp qw(croak);

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub create {
	croak('noop signup called the account repository');
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
use Chleb::Account::Repository::Dynamo;
use Chleb::Account::Repository::Memcached;
use Chleb::DI::MockLogger;
use Chleb::Server::Moose;
use JSON ();
use Test::More 0.96;

sub setUp {
	my ($self) = @_;
	$self->sut(Chleb::Server::Moose->new());
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return 0;
}

sub testMemcachedCreatesPermanentSequentialAccounts {
	my ($self) = @_;
	plan tests => 11;

	my $client = FakeAccountMemcached->new();
	my $store = Chleb::Account::Repository::Memcached->new({
		client => $client,
		dic => $self->sut->dic,
	});
	my $first = $store->create({ title => 'Mr', username => 'john.smith', email => 'john.smith@example.com', name => 'John Smith' });
	my $secondAccount = $store->create({ title => 'Mrs', username => 'jane.smith', email => 'jane.smith@example.com', name => 'Jane Smith' });

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
	is($loaded->{title}, 'Mr', 'stored title can be loaded');
	is($Chleb::Account::Repository::Memcached::PREFIX, 'chleb-accounts', 'account prefix is fixed');

	return 0;
}

sub testEmailSignupIsIdempotent {
	my ($self) = @_;
	plan tests => 2;

	my $store = Chleb::Account::Repository::Memcached->new({
		client => FakeAccountMemcached->new(),
		dic => $self->sut->dic,
	});
	my $first = $store->create({ title => 'Mr', username => 'john.smith', email => 'john.smith@example.com', name => 'John Smith' });
	my $repeat = $store->create({ title => 'Dr', username => 'different', email => 'john.smith@example.com', name => 'Different Name' });

	is($repeat->{id}, $first->{id}, 'same email returns the existing account ID');
	is($repeat->{name}, 'John Smith', 'same email retains the existing account data');

	return 0;
}

sub testUsernameConflictRaises409 {
	my ($self) = @_;
	plan tests => 2;

	my $store = Chleb::Account::Repository::Memcached->new({
		client => FakeAccountMemcached->new(),
		dic => $self->sut->dic,
	});
	$store->create({ title => 'Mr', username => 'john.smith', email => 'john.smith@example.com', name => 'John Smith' });
	my $evalOk; $evalOk = eval {
		$store->create({ title => 'Mrs', username => 'john.smith', email => 'other@example.com', name => 'Other Name' });
		1;
	} or $evalOk = 0;

	is($evalOk, 0, 'duplicate username is rejected');
	is($@->statusCode(), 409, 'duplicate username raises conflict');

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

sub testRepositoryCanSelectDynamoBackend {
	my ($self) = @_;
	plan tests => 1;

	my $repo = Chleb::Account::Repository->new({ dic => $self->sut->dic, backend => 'Dynamo' });
	## no critic (Subroutines::ProtectPrivateSubs)
	isa_ok($repo->__backend(), 'Chleb::Account::Repository::Dynamo', 'DynamoDB repository backend');

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
				title => 'Mr',
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
				title => 'Mr',
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

sub testSignupRejectsInvalidTitle {
	my ($self) = @_;
	plan tests => 1;

	$self->sut->dic->accountRepo(FakeAccountRepository->new());
	## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my $evalOk; $evalOk = eval {
		$self->sut->__accountSignup({
			data => {
				type => 'account',
				attributes => {
					title => 'Reverend',
					username => 'john.smith',
					email => 'john.smith@example.com',
					name => 'John Smith',
				},
			},
		});
		1;
	} or $evalOk = 0;

	is($evalOk, 0, 'signup rejects an invalid account title');

	return 0;
}

sub testSignupNoopValidatesWithoutWriting {
	my ($self) = @_;
	plan tests => 5;

	$self->sut->dic->accountRepo(FakeNoopAccountRepository->new());
	my $result = $self->sut->__accountSignup({
		meta => { noop => JSON::true },
		data => {
			type => 'account',
			attributes => {
				title => 'Mr',
				username => 'john.smith',
				email => 'john.smith@example.com',
				name => 'John Smith',
			},
		},
	});

	is($result->{meta}->{noop}, JSON::true, 'noop response identifies validation-only mode');
	is($result->{data}, undef, 'noop response has no primary resource');
	is($result->{meta}->{validated}->{email}, 'john.smith@example.com', 'noop response includes validated email');
	is($result->{meta}->{validated}->{title}, 'Mr', 'noop response includes validated title');
	is($result->{meta}->{validated}->{status}, 'pending', 'noop response includes pending status');

	return 0;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(AccountTests->new->run());
