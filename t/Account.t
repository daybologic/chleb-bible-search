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
	my ($class, $args) = @_;
	return bless({
		password_hash => $args ? $args->{password_hash} : undef,
		status => $args ? $args->{status} : undef,
		session_version => $args ? ($args->{session_version} // 1) : 1,
		global_session_version => $args ? ($args->{global_session_version} // 1) : 1,
	}, $class);
}

sub create {
	my ($self, $attributes) = @_;
	return {
		%{ $attributes },
		id => 123,
		created_at => '1970-01-01T00:00:00+0000',
		role => $Chleb::Account::Role::USER,
		session_version => $self->{session_version},
		status => $self->{status} // 'pending',
	};
}

sub loadVerificationToken {
	return {
		token_id => 7,
		account_id => 123,
		value => 'verification-token',
		expires_at => 4_102_444_800,
	};
}

sub load {
	my ($self) = @_;
	return {
		id => 123,
		created_at => '1970-01-01T00:00:00+0000',
		role => $Chleb::Account::Role::USER,
		title => 'Mr',
		username => 'john.smith',
		email => 'john.smith@example.com',
		name => 'John Smith',
		status => $self->{status} // 'pending',
		password_hash => $self->{password_hash},
		session_version => $self->{session_version},
	};
}

sub loadByUsername {
	my ($self, $username) = @_;
	return $self->load(123) if (lc($username // '') eq 'john.smith');
	return;
}

sub createLoginChallenge {
	return {
		value => 'login-challenge',
		expires_at => 1_060,
	};
}

sub consumeLoginChallenge {
	my ($self, $value, $username) = @_;
	return { username => lc($username) } if ($value eq 'login-challenge');
	return;
}

sub bumpSessionVersion {
	my ($self, $accountId) = @_;
	my $account = $self->load($accountId);
	$account->{session_version}++;
	$self->{session_version} = $account->{session_version};
	return $account;
}

sub loadGlobalSessionVersion {
	my ($self) = @_;
	return $self->{global_session_version};
}

sub bumpGlobalSessionVersion {
	my ($self) = @_;
	return ++$self->{global_session_version};
}

sub consumeVerificationToken {
	return { token_id => 7, account_id => 123 };
}

sub activate {
	my ($self, $accountId) = @_;
	return {
		%{ $self->load($accountId) },
		status => 'active',
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

package FakeSQS;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub SendMessage {
	my ($self, %args) = @_;
	$self->{message} = \%args;
	return 1;
}

package FakeLoginToken;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({ value => 'signed-account-jwt', expires => 1_604_800 }, $class);
}

sub value {
	my ($self) = @_;
	return $self->{value};
}

sub expires {
	my ($self) = @_;
	return $self->{expires};
}

package FakeLoginTokenRepository;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class) = @_;
	return bless({}, $class);
}

sub createAccountToken {
	return FakeLoginToken->new();
}

package FakeAuthenticatedToken;
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;

sub new {
	my ($class, $args) = @_;
	return bless($args, $class);
}

sub loggedIn {
	my ($self) = @_;
	return $self->{logged_in};
}

sub accountId {
	my ($self) = @_;
	return $self->{account_id};
}

sub role {
	my ($self) = @_;
	return $self->{role};
}

sub sessionVersion {
	my ($self) = @_;
	return $self->{session_version};
}

sub sessionStarted {
	my ($self) = @_;
	return $self->{session_started};
}

sub globalSessionVersion {
	my ($self) = @_;
	return $self->{global_session_version};
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
use Chleb::Account::Password;
use Chleb::Account::LoginChallenge;
use Chleb::Account::Role;
use Chleb::Account::VerificationToken;
use Chleb::Account::VerificationQueue;
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
	plan tests => 18;

	my $client = FakeAccountMemcached->new();
	my $store = Chleb::Account::Repository::Memcached->new({
		client => $client,
		dic => $self->sut->dic,
	});
	$self->sut->dic->time->setMockedTime(0);
	my $first = $store->create({ title => 'Mr', username => 'john.smith', email => 'john.smith@example.com', name => 'John Smith' });
	my $secondAccount = $store->create({ title => 'Mrs', username => 'jane.smith', email => 'jane.smith@example.com', name => 'Jane Smith' });

	is($first->{id}, 1, 'first account ID is 1');
	is($secondAccount->{id}, 2, 'second account ID is 2');
	is($first->{status}, 'pending', 'new account status is pending');
	is($first->{created_at}, '1970-01-01T00:00:00+0000', 'new account creation time is stored in UTC');
	is($first->{role}, $Chleb::Account::Role::USER, 'new account is stored with the user role');
	is($first->{session_version}, 1, 'new account starts at session version one');
	is($client->{ttl}->{ 'chleb-accounts:next-id' }, 0, 'account ID counter has permanent TTL');
	is($client->{ttl}->{ 'chleb-accounts:account:1' }, 0, 'first account has permanent TTL');
	is($client->{ttl}->{ 'chleb-accounts:account:2' }, 0, 'second account has permanent TTL');

	my $loaded = $store->load(1);
	is($loaded->{username}, 'john.smith', 'stored account can be loaded');
	is($loaded->{email}, 'john.smith@example.com', 'stored email can be loaded');
	is($loaded->{name}, 'John Smith', 'stored name can be loaded');
	is($loaded->{title}, 'Mr', 'stored title can be loaded');
	is($loaded->{created_at}, '1970-01-01T00:00:00+0000', 'stored account creation time can be loaded');
	is($loaded->{role}, $Chleb::Account::Role::USER, 'stored account role can be loaded');
	is($store->bumpSessionVersion(1)->{session_version}, 2, 'account session version can be incremented');
	is($store->load(1)->{session_version}, 2, 'incremented account session version is persisted');
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

sub testVerificationTokenIsRandomAndExpires {
	my ($self) = @_;
	plan tests => 12;

	my $client = FakeAccountMemcached->new();
	my $store = Chleb::Account::Repository::Memcached->new({
		client => $client,
		dic => $self->sut->dic,
	});
	my $first = $store->createVerificationToken(123);
	my $secondToken = $store->createVerificationToken(123);

	is($first->{account_id}, 123, 'verification token belongs to the account');
	is($first->{token_id}, 1, 'verification token has a numeric ID');
	like($first->{value}, qr{\A[A-Za-z0-9_-]{43}\z}x, 'verification token is URL-safe Base64');
	isnt($first->{value}, $secondToken->{value}, 'verification tokens are random');
	is($first->{expires_at} - $first->{created_at}, 24 * 60 * 60, 'verification token expires after 24 hours');
	is($client->{ttl}->{ 'chleb-accounts:verification-token:' . $first->{token_id} }, 24 * 60 * 60, 'verification token has a 24-hour cache lifetime');
	my $stored = JSON::decode_json($client->{data}->{ 'chleb-accounts:verification-token:' . $first->{token_id} });
	is($stored->{account_id}, 123, 'stored verification token record contains the account ID');
	is($stored->{value}, $first->{value}, 'stored verification token record contains the token value');
	is($store->loadVerificationToken($first->{token_id})->{value}, $first->{value}, 'verification token can be loaded by numeric ID');
	ok($store->consumeVerificationToken($first->{token_id}, 123), 'verification token can be consumed by its account');
	ok(defined($store->loadVerificationToken($first->{token_id})->{consumed_at}), 'consumed verification token records the consumption time');
	ok(!$store->consumeVerificationToken($first->{token_id}, 123), 'verification token cannot be consumed twice');

	return 0;
}

sub testPendingAccountCanBeActivated {
	my ($self) = @_;
	plan tests => 3;

	my $store = Chleb::Account::Repository::Memcached->new({
		client => FakeAccountMemcached->new(),
		dic => $self->sut->dic,
	});
	my $created = $store->create({ title => 'Mr', username => 'john.smith', email => 'john.smith@example.com', name => 'John Smith' });
	my $activated = $store->activate($created->{id});

	is($activated->{status}, 'active', 'pending account becomes active');
	is($store->load($created->{id})->{status}, 'active', 'activated status is persisted');
	is($store->activate($created->{id})->{status}, 'active', 'activating an active account is idempotent');

	return 0;
}

sub testLoginChallengeIsShortLivedAndSingleUse {
	my ($self) = @_;
	plan tests => 8;

	my $client = FakeAccountMemcached->new();
	my $store = Chleb::Account::Repository::Memcached->new({
		client => $client,
		dic => $self->sut->dic,
	});
	$self->sut->dic->time->setMockedTime(1_000);
	my $challenge = $store->createLoginChallenge('John.Smith', 60);
	like($challenge->{value}, qr{\A[A-Za-z0-9_-]{43}\z}x, 'login challenge is URL-safe Base64');
	is($challenge->{username}, 'john.smith', 'login challenge username is normalized');
	is($challenge->{expires_at} - $challenge->{created_at}, 60, 'login challenge uses requested lifetime');
	my $key = 'chleb-accounts:login-challenge:' . Chleb::Account::LoginChallenge::digest($challenge->{value});
	ok(index($client->{data}->{$key}, $challenge->{value}) < 0, 'stored login challenge does not contain its raw value');
	ok(!$store->consumeLoginChallenge($challenge->{value}, 'other.user'), 'wrong username cannot consume login challenge');
	ok($store->consumeLoginChallenge($challenge->{value}, 'JOHN.SMITH'), 'matching username consumes login challenge');
	ok(!$store->consumeLoginChallenge($challenge->{value}, 'john.smith'), 'login challenge cannot be reused');
	my $expired = $store->createLoginChallenge('john.smith', 60);
	$self->sut->dic->time->setMockedTime(1_061);
	ok(!$store->consumeLoginChallenge($expired->{value}, 'john.smith'), 'expired login challenge cannot be consumed');

	return 0;
}

sub testAccountLoginIssuesAuthenticatedToken {
	my ($self) = @_;
	plan tests => 7;

	$self->sut->dic->accountRepo(FakeAccountRepository->new({
		password_hash => Chleb::Account::Password::hash('correct horse battery staple'),
		status => 'active',
	}));
	$self->sut->dic->tokenRepo(FakeLoginTokenRepository->new());
	my $challenge = $self->sut->__accountLoginChallenge({ username => 'JOHN.SMITH' });
	is($challenge->{challenge}, 'login-challenge', 'login challenge is returned');
	my $result = $self->sut->__accountLogin({
		username => 'JOHN.SMITH',
		password => 'correct horse battery staple',
		challenge => $challenge->{challenge},
	});
	is($result->{access_token}, 'signed-account-jwt', 'login returns the access token');
	is($result->{token_type}, 'Bearer', 'login returns Bearer token type');
	is($result->{expires_in}, 15 * 60, 'login returns the configured fifteen-minute lifetime');
	is($result->{account}->{id}, '123', 'login returns the account ID');
	is($result->{account}->{username}, 'john.smith', 'login preserves stored username casing');
	is($result->{account}->{role}, 'user', 'login returns the account role');

	return 0;
}

sub testAccountTokenCanRefreshWithinAbsoluteLifetime {
	my ($self) = @_;
	plan tests => 4;

	$self->sut->dic->time->setMockedTime(1_000);
	$self->sut->dic->accountRepo(FakeAccountRepository->new({ status => 'active' }));
	$self->sut->dic->tokenRepo(FakeLoginTokenRepository->new());
	$self->sut->__sessionToken(FakeAuthenticatedToken->new({
		logged_in => 1,
		account_id => 123,
		role => 'user',
		session_version => 1,
		global_session_version => 1,
		session_started => 900,
	}));
	my $result = $self->sut->__accountRefreshToken();
	is($result->{expires_in}, 15 * 60, 'refresh returns the short JWT lifetime');
	is($result->{account}->{id}, '123', 'refresh returns the account identity');

	$self->sut->dic->time->setMockedTime(900 + 30 * 24 * 60 * 60);
	my $evalOk; $evalOk = eval {
		$self->sut->__accountRefreshToken();
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'refresh is rejected after the absolute session lifetime');

	$self->sut->dic->time->setMockedTime(1_000);
	is($self->sut->__sessionToken->sessionStarted, 900, 'refresh preserves the original session start time');

	return 0;
}

sub testAccountPasswordHashCanBeStored {
	my ($self) = @_;
	plan tests => 2;

	my $store = Chleb::Account::Repository::Memcached->new({
		client => FakeAccountMemcached->new(),
		dic => $self->sut->dic,
	});
	my $created = $store->create({ title => 'Mr', username => 'john.smith', email => 'john.smith@example.com', name => 'John Smith' });
	my $updated = $store->setPasswordHash($created->{id}, '$2a$12$stored-hash');

	is($updated->{password_hash}, '$2a$12$stored-hash', 'password hash is returned after storage');
	is($store->load($created->{id})->{password_hash}, '$2a$12$stored-hash', 'password hash is persisted');

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

sub testUsernameUniquenessIgnoresCaseButPreservesOriginal {
	my ($self) = @_;
	plan tests => 3;

	my $store = Chleb::Account::Repository::Memcached->new({
		client => FakeAccountMemcached->new(),
		dic => $self->sut->dic,
	});
	my $first = $store->create({ title => 'Mr', username => '2e0eol', email => 'lower@example.com', name => 'Lower Case' });
	my $evalOk; $evalOk = eval {
		$store->create({ title => 'Mr', username => '2E0EOL', email => 'upper@example.com', name => 'Upper Case' });
		1;
	} or $evalOk = 0;

	is($first->{username}, '2e0eol', 'original username casing is preserved');
	is($evalOk, 0, 'username uniqueness ignores case');
	is($@->statusCode(), 409, 'case-insensitive username conflict raises conflict');

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

sub testVerificationQueuePublishesOnlyAccountAndTokenIDs {
	my ($self) = @_;
	plan tests => 3;

	my $client = FakeSQS->new();
	my $queue = Chleb::Account::VerificationQueue->new({
		client => $client,
		dic => $self->sut->dic,
	});
	$queue->publish({ account_id => 123, token_id => 7 });

	is($client->{message}->{QueueUrl}, 'https://sqs.eu-west-2.amazonaws.com/979393143841/chleb-account-verification-email', 'verification jobs use the configured queue');
	my $body = JSON::decode_json($client->{message}->{MessageBody});
	is_deeply($body, { account_id => 123, token_id => 7 }, 'verification jobs contain only account and token IDs');
	ok(!exists($body->{value}) && !exists($body->{token}), 'verification jobs do not contain a token value');

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
				created_at => '1970-01-01T00:00:00+0000',
				role => 'user',
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

sub testAccountVerificationActivatesAccount {
	my ($self) = @_;
	plan tests => 2;

	$self->sut->dic->accountRepo(FakeAccountRepository->new());
	my $result = $self->sut->__accountVerify({
		account_id => 123,
		token_id => 7,
		token => 'verification-token',
	});

	is($result->{data}->{id}, '123', 'verification returns the account resource');
	is($result->{data}->{attributes}->{status}, 'active', 'verification returns the active status');

	return 0;
}

sub testAccountVerificationHelpers {
	my ($self) = @_;
	plan tests => 12;

	my $repository = FakeAccountRepository->new();
	my ($accountId, $tokenId, $tokenValue) = Chleb::Server::Moose::__accountVerificationParams({
		account_id => '123',
		token_id => '7',
		token => 'verification-token',
	});
	is($accountId, 123, 'verification parameters convert account ID to an integer');
	is($tokenId, 7, 'verification parameters convert token ID to an integer');
	is($tokenValue, 'verification-token', 'verification parameters preserve token value');

	my ($token, $account) = Chleb::Server::Moose::__loadAccountVerification($repository, 123, 7);
	is($token->{token_id}, 7, 'verification helper loads the token');
	is($account->{id}, 123, 'verification helper loads the account');

	is(Chleb::Server::Moose::__validateAccountVerification($self->sut, 123, 'verification-token', $token, $account), undef,
		'valid verification data is accepted');
	my $evalOk; $evalOk = eval {
		Chleb::Server::Moose::__validateAccountVerification($self->sut, 123, 'wrong-token', $token, $account);
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'wrong verification token is rejected');

	my $activated = Chleb::Server::Moose::__activateVerifiedAccount($repository, 123, 7);
	is($activated->{status}, 'active', 'verification helper activates the account');

	my $resource = Chleb::Server::Moose::__accountResource($activated);
	is($resource->{data}->{type}, 'account', 'account resource has the account type');
	is($resource->{data}->{id}, '123', 'account resource has the account ID');
	is($resource->{data}->{attributes}->{status}, 'active', 'account resource reports active status');
	is(Chleb::Server::Moose::__secureEqual('same', 'same'), 1, 'secure comparison accepts equal values');

	return 0;
}

sub testAccountGetReturnsPublicAccountResource {
	my ($self) = @_;
	plan tests => 4;

	$self->sut->dic->accountRepo(FakeAccountRepository->new());
	my $result = $self->sut->__accountGet('123');
	is($result->{data}->{type}, 'account', 'account GET returns an account resource');
	is($result->{data}->{id}, '123', 'account GET returns the requested account ID');
	is($result->{data}->{attributes}->{username}, 'john.smith', 'account GET returns account attributes');

	my $evalOk; $evalOk = eval {
		$self->sut->__accountGet('not-an-account');
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'account GET rejects a malformed account ID');

	return 0;
}

sub testAccountGetByUsernameReturnsPublicAccountResource {
	my ($self) = @_;
	plan tests => 4;

	$self->sut->dic->accountRepo(FakeAccountRepository->new());
	my $result = $self->sut->__accountGetByUsername('JOHN.SMITH');
	is($result->{data}->{type}, 'account', 'username lookup returns an account resource');
	is($result->{data}->{id}, '123', 'username lookup returns the account ID');
	is($result->{data}->{attributes}->{username}, 'john.smith', 'username lookup preserves stored username casing');

	my $evalOk; $evalOk = eval {
		$self->sut->__accountGetByUsername(undef);
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'username lookup rejects a missing username');

	return 0;
}

sub testAccountLookupAuthorization {
	my ($self) = @_;
	plan tests => 4;

	$self->sut->__sessionToken(FakeAuthenticatedToken->new({ logged_in => 1, account_id => 1, role => 'user' }));
	is($self->sut->__authorizeAccountLookup(1), undef, 'users may look up their own account');

	my $evalOk; $evalOk = eval {
		$self->sut->__authorizeAccountLookup(2);
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'users may not look up another account');

	$self->sut->__sessionToken(FakeAuthenticatedToken->new({ logged_in => 1, account_id => 1, role => 'admin' }));
	is($self->sut->__authorizeAccountLookup(2), undef, 'admins may look up another account');

	$self->sut->__sessionToken(FakeAuthenticatedToken->new({ logged_in => 0, account_id => undef, role => '' }));
	$evalOk = eval {
		$self->sut->__authorizeAccountLookup(1);
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'anonymous requests may not look up an account');

	return 0;
}

sub testAccountSessionVersionInvalidatesTokens {
	my ($self) = @_;
	plan tests => 3;

	my $repository = FakeAccountRepository->new({ session_version => 1 });
	$self->sut->dic->accountRepo($repository);
	$self->sut->__sessionToken(FakeAuthenticatedToken->new({
		logged_in => 1,
		account_id => 123,
		role => 'user',
		session_version => 1,
		global_session_version => 1,
	}));
	is($self->sut->__validateAccountSessionVersion($self->sut->__sessionToken), undef,
		'current account session version is accepted');
	my $result = $self->sut->__accountInvalidateSessions();
	is(JSON::is_bool($result->{invalidated}) ? $result->{invalidated} : undef, JSON::true,
		'session invalidation reports success');

	my $evalOk; $evalOk = eval {
		$self->sut->__validateAccountSessionVersion($self->sut->__sessionToken);
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'an older account session version is rejected');

	return 0;
}

sub testAdminCanInvalidateAllAccountSessions {
	my ($self) = @_;
	plan tests => 4;

	my $repository = FakeAccountRepository->new({ global_session_version => 1 });
	$self->sut->dic->accountRepo($repository);
	$self->sut->__sessionToken(FakeAuthenticatedToken->new({
		logged_in => 1,
		account_id => 123,
		role => 'admin',
		session_version => 1,
		global_session_version => 1,
	}));
	is($self->sut->__validateAccountSessionVersion($self->sut->__sessionToken), undef,
		'current global session version is accepted');
	my $result = $self->sut->__accountInvalidateAllSessions();
	is(JSON::is_bool($result->{invalidated}) ? $result->{invalidated} : undef, JSON::true,
		'global session invalidation reports success');

	my $evalOk; $evalOk = eval {
		$self->sut->__validateAccountSessionVersion($self->sut->__sessionToken);
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'global invalidation rejects the previous administrator token');

	$self->sut->__sessionToken(FakeAuthenticatedToken->new({
		logged_in => 1,
		account_id => 123,
		role => 'user',
		session_version => 1,
		global_session_version => 2,
	}));
	$evalOk = eval {
		$self->sut->__accountInvalidateAllSessions();
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'non-admin accounts cannot invalidate all sessions');

	return 0;
}

sub testAccountPasswordVerificationReturnsOnlyValidity {
	my ($self) = @_;
	plan tests => 9;

	my $passwordHash = Chleb::Account::Password::hash('correct horse battery staple');
	$self->sut->dic->accountRepo(FakeAccountRepository->new({ password_hash => $passwordHash }));
	my $valid = $self->sut->__accountPasswordVerify({ account_id => 123, password => 'correct horse battery staple' });
	is(JSON::is_bool($valid->{valid}) ? $valid->{valid} : undef, JSON::true, 'correct account password is valid');
	$self->sut->dic->logger->isLogged(qr{password\s+verification\s+succeeded.*123.*john[.]smith}x);
	$self->sut->dic->logger->isNotLogged(qr{correct horse battery staple}x);
	$self->sut->dic->logger->isNotLogged(qr{\$2a\$12}x);

	my $invalid = $self->sut->__accountPasswordVerify({ account_id => 123, password => 'wrong password' });
	is(JSON::is_bool($invalid->{valid}) ? $invalid->{valid} : undef, JSON::false, 'incorrect account password is invalid');
	$self->sut->dic->logger->isLogged(qr{password\s+verification\s+failed.*123.*john[.]smith}x);

	my $evalOk; $evalOk = eval {
		$self->sut->__accountPasswordVerify({ account_id => 'not-an-account', password => 'secret' });
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'password verification rejects malformed account IDs');

	$evalOk = eval {
		$self->sut->__accountPasswordVerify({ account_id => 123 });
		1;
	} or $evalOk = 0;
	is($evalOk, 0, 'password verification rejects missing passwords');

	is_deeply([ sort keys %{ $valid } ], [ 'valid' ], 'password verification exposes only validity');

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

sub testSignupRejectsAdjacentUsernameSeparators {
	my ($self) = @_;
	plan tests => 4;

	foreach my $username (qw(john..smith john_-smith .john john-)) {
		$self->sut->dic->accountRepo(FakeAccountRepository->new());
		my $evalOk; $evalOk = eval {
			$self->sut->__accountSignup({
				data => {
					type => 'account',
					attributes => {
						title => 'Mr',
						username => $username,
						email => 'john.smith@example.com',
						name => 'John Smith',
					},
				},
			});
			1;
		} or $evalOk = 0;
		is($evalOk, 0, "signup rejects username '$username'");
	}

	return 0;
}

sub testSignupRejectsUsernameOverMaximumLength {
	my ($self) = @_;
	plan tests => 1;

	$self->sut->dic->accountRepo(FakeAccountRepository->new());
	my $evalOk; $evalOk = eval {
		$self->sut->__accountSignup({
			data => {
				type => 'account',
				attributes => {
					title => 'Mr',
					username => 'a' x 31,
					email => 'john.smith@example.com',
					name => 'John Smith',
				},
			},
		});
		1;
	} or $evalOk = 0;

	is($evalOk, 0, 'signup rejects usernames over 30 characters');

	return 0;
}

sub testSignupNoopValidatesWithoutWriting {
	my ($self) = @_;
	plan tests => 6;

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
	is($result->{meta}->{validated}->{role}, 'user', 'noop response includes default user role');
	is($result->{meta}->{validated}->{status}, 'pending', 'noop response includes pending status');

	return 0;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(AccountTests->new->run());
