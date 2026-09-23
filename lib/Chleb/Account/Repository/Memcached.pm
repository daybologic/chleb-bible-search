# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::Repository::Memcached;
use strict;
use warnings;
use Carp qw(croak);
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Exception;
use Chleb::Account::LoginChallenge;
use Chleb::Account::Role;
use Chleb::Account::VerificationToken;
use Digest::SHA qw(sha1_hex);
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use JSON qw(decode_json encode_json);
use Readonly;

Readonly our $PREFIX => 'chleb-accounts';
Readonly our $VERIFICATION_TOKEN_PREFIX => "$PREFIX:verification-token";
Readonly my $PERMANENT_TTL => 0;
Readonly my $NEXT_ID_KEY => "$PREFIX:next-id";
Readonly my $NEXT_TOKEN_ID_KEY => "$PREFIX:verification-token-next-id";
Readonly my $GLOBAL_SESSION_VERSION_KEY => "$PREFIX:global-session-version";
Readonly my $CONSUME_LOCK_TTL => 30;
Readonly our $LOGIN_CHALLENGE_PREFIX => "$PREFIX:login-challenge";

has client => (is => 'ro', init_arg => 'client', predicate => '__hasClient');
has __clientObject => (is => 'rw', lazy => 1, builder => '__makeClient');

sub create {
	my ($self, $attributes) = @_;
	my $existing = $self->loadByEmail($attributes->{email});
	return $existing if ($existing);

	my $added = $self->__call(add => $NEXT_ID_KEY, 0, $PERMANENT_TTL);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to allocate an account ID'))
		unless (defined($added));

	my $id = $self->__call(incr => $NEXT_ID_KEY);
	if (!defined($id) || $id !~ m{ \A[0-9]+\z }x || int($id) <= 0) {
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to allocate an account ID'));
	}

	my $emailKey = $self->__indexKey('email', $attributes->{email});
	my $emailAdded = $self->__call(add => $emailKey, int($id), $PERMANENT_TTL);
	if (!defined($emailAdded)) {
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to reserve the account email address'));
	}
	if (!$emailAdded) {
		$existing = $self->loadByEmail($attributes->{email});
		return $existing if ($existing);
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'The account email reservation is incomplete'));
	}

	my $usernameKey = $self->__indexKey('username', $attributes->{username});
	my $usernameAdded = $self->__call(add => $usernameKey, int($id), $PERMANENT_TTL);
	if (!defined($usernameAdded)) {
		$self->__call(delete => $emailKey);
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to reserve the account username'));
	}
	if (!$usernameAdded) {
		$self->__call(delete => $emailKey);
		croak(Chleb::Exception->raise(HTTP_CONFLICT, 'The account username is already in use'));
	}

	my $account = {
		id => int($id),
		created_at => Chleb::Account::VerificationToken::formatUtc($self->dic->time->get()),
		role => $Chleb::Account::Role::USER,
		session_version => 1,
		%{ $attributes },
		status => 'pending',
	};
	my $stored = $self->__call(set => $self->__key($id), encode_json($account), $PERMANENT_TTL);
	unless ($stored) {
		$self->__call(delete => $emailKey);
		$self->__call(delete => $usernameKey);
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to store the new account'));
	}

	$account->{_created} = 1;
	return $account;
}

sub createVerificationToken {
	my ($self, $accountId) = @_;
	my $added = $self->__call(add => $NEXT_TOKEN_ID_KEY, 0, $PERMANENT_TTL);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to initialize verification token IDs'))
		unless (defined($added));
	my $tokenId = $self->__call(incr => $NEXT_TOKEN_ID_KEY);
	if (!defined($tokenId) || $tokenId !~ m{ \A[0-9]+\z }x || int($tokenId) <= 0) {
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to allocate a verification token ID'));
	}
	my $token = Chleb::Account::VerificationToken::generate($self->dic, $accountId, $tokenId);
	my $tokenRecord = {
		token_id => $token->{token_id},
		account_id => $token->{account_id},
		value => $token->{value},
		created_at => $token->{created_at},
		expires_at => $token->{expires_at},
	};
	my $stored = $self->__call(set => $self->__verificationTokenKey($token->{token_id}), encode_json($tokenRecord), $Chleb::Account::VerificationToken::LIFETIME);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to store the account verification token'))
		unless ($stored);
	return $token;
}

sub loadVerificationToken {
	my ($self, $tokenId) = @_;
	my $encoded = $self->__call(get => $self->__verificationTokenKey($tokenId));
	return unless (defined($encoded));
	my $tokenRecord;
	my $evalOk; $evalOk = eval {
		$tokenRecord = decode_json($encoded);
		1;
	} or $evalOk = 0;
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Invalid verification token data for token '$tokenId': $EVAL_ERROR"))
		unless ($evalOk && ref($tokenRecord) eq 'HASH');
	return $tokenRecord;
}

sub consumeVerificationToken {
	my ($self, $tokenId, $accountId) = @_;
	my $tokenRecord = $self->loadVerificationToken($tokenId);
	return unless ($tokenRecord && int($tokenRecord->{account_id}) == int($accountId));
	return if (defined($tokenRecord->{consumed_at}));
	return if (int($tokenRecord->{expires_at}) <= int($self->dic->time->get()));
	my $lockKey = $self->__verificationTokenLockKey($tokenId);
	my $locked = $self->__call(add => $lockKey, 1, $CONSUME_LOCK_TTL);
	return unless ($locked);
	$tokenRecord = $self->loadVerificationToken($tokenId);
	if (!$tokenRecord || int($tokenRecord->{account_id}) != int($accountId) || defined($tokenRecord->{consumed_at}) || int($tokenRecord->{expires_at}) <= int($self->dic->time->get())) {
		$self->__call(delete => $lockKey);
		return;
	}
	$tokenRecord->{consumed_at} = int($self->dic->time->get());
	my $stored = $self->__call(set => $self->__verificationTokenKey($tokenId), encode_json($tokenRecord), $Chleb::Account::VerificationToken::LIFETIME);
	$self->__call(delete => $lockKey);
	return $tokenRecord if ($stored);
	return;
}

sub loadByEmail {
	my ($self, $email) = @_;
	return $self->__loadIndex('email', $email);
}

sub loadByUsername {
	my ($self, $username) = @_;
	return $self->__loadIndex('username', $username);
}

sub load {
	my ($self, $id) = @_;
	my $encoded = $self->__call(get => $self->__key($id));
	return unless (defined($encoded));

	my $account;
	my $evalOk; $evalOk = eval {
		$account = decode_json($encoded);
		1;
	} or $evalOk = 0;
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Invalid account data for account '$id': $EVAL_ERROR"))
		unless ($evalOk && ref($account) eq 'HASH');

	return $account;
}

=head1 setPasswordHash

Store a bcrypt password hash on an existing account and return the account.

=cut

sub setPasswordHash {
	my ($self, $id, $passwordHash) = @_;
	my $account = $self->load($id);
	return unless ($account);
	$account->{password_hash} = $passwordHash;
	my $stored = $self->__call(set => $self->__key($id), encode_json($account), $PERMANENT_TTL);
	return $account if ($stored);
	return;
}

=head1 bumpSessionVersion

Increment the account session version, invalidating previously issued JWTs.

=cut

sub bumpSessionVersion {
	my ($self, $id) = @_;
	my $account = $self->load($id);
	return unless ($account);
	$account->{session_version} = int($account->{session_version} // 1) + 1;
	my $stored = $self->__call(set => $self->__key($id), encode_json($account), $PERMANENT_TTL);
	return $account if ($stored);
	return;
}

=head1 loadGlobalSessionVersion

Load the global session version, initializing it to one when necessary.

=cut

sub loadGlobalSessionVersion {
	my ($self) = @_;
	my $added = $self->__call(add => $GLOBAL_SESSION_VERSION_KEY, 1, $PERMANENT_TTL);
	return unless (defined($added));
	my $version = $self->__call(get => $GLOBAL_SESSION_VERSION_KEY);
	return int($version // 1);
}

=head1 bumpGlobalSessionVersion

Atomically increment the global session version, invalidating all account JWTs.

=cut

sub bumpGlobalSessionVersion {
	my ($self) = @_;
	my $added = $self->__call(add => $GLOBAL_SESSION_VERSION_KEY, 1, $PERMANENT_TTL);
	return unless (defined($added));
	my $version = $self->__call(incr => $GLOBAL_SESSION_VERSION_KEY);
	return defined($version) ? int($version) : undef;
}

=head1 createLoginChallenge

Store a short-lived login challenge for a normalized username.

=cut

sub createLoginChallenge {
	my ($self, $username, $ttl) = @_;
	my $challenge = Chleb::Account::LoginChallenge::generate($self->dic, $username, $ttl);
	my $challengeRecord = {
		username => $challenge->{username},
		created_at => $challenge->{created_at},
		expires_at => $challenge->{expires_at},
	};
	my $stored = $self->__call(set => $self->__loginChallengeKey($challenge->{digest}), encode_json($challengeRecord), int($ttl));
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to store the account login challenge'))
		unless ($stored);
	return $challenge;
}

=head1 consumeLoginChallenge

Atomically consume a login challenge for a normalized username.

=cut

sub consumeLoginChallenge {
	my ($self, $value, $username) = @_;
	my $digest = Chleb::Account::LoginChallenge::digest($value);
	my $lockKey = $self->__loginChallengeLockKey($digest);
	my $locked = $self->__call(add => $lockKey, 1, $CONSUME_LOCK_TTL);
	return unless ($locked);
	my $encoded = $self->__call(get => $self->__loginChallengeKey($digest));
	my $challengeRecord;
	my $evalOk; $evalOk = eval {
		$challengeRecord = decode_json($encoded) if (defined($encoded));
		1;
	} or $evalOk = 0;
	unless ($evalOk && ref($challengeRecord) eq 'HASH') {
		$self->__call(delete => $lockKey);
		return;
	}
	unless (lc($challengeRecord->{username} // '') eq lc($username // '')) {
		$self->__call(delete => $lockKey);
		return;
	}
	if (int($self->dic->time->get()) >= int($challengeRecord->{expires_at} // 0)) {
		$self->__call(delete => $lockKey);
		return;
	}
	$self->__call(delete => $self->__loginChallengeKey($digest));
	$self->__call(delete => $lockKey);
	return $challengeRecord;
}

=head1 activate

Mark a pending account as active and return the updated account.

=cut

sub activate {
	my ($self, $id) = @_;
	my $account = $self->load($id);
	return unless ($account);
	return $account if (($account->{status} // '') eq 'active');
	return unless (($account->{status} // '') eq 'pending');
	$account->{status} = 'active';
	my $stored = $self->__call(set => $self->__key($id), encode_json($account), $PERMANENT_TTL);
	return $account if ($stored);
	return;
}

sub __call {
	my ($self, $method, @args) = @_;
	my $result;
	my $evalOk; $evalOk = eval {
		$result = $self->__client()->$method(@args);
		1;
	} or $evalOk = 0;
	if (my $evalError = $EVAL_ERROR) {
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Memcached account operation '$method' failed: $evalError"));
	}
	return $result;
}

sub __client {
	my ($self) = @_;
	return $self->client if ($self->__hasClient);
	return $self->__clientObject;
}

sub __makeClient { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	my $evalOk; $evalOk = eval {
		require Cache::Memcached;
		Cache::Memcached->import();
		1;
	} or $evalOk = 0;
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Cannot load Cache::Memcached: $EVAL_ERROR"))
		unless ($evalOk);

	my $config = $self->dic->config->get('rate_limit', 'backend_memcached', {});
	my $servers = $config->{servers} // [ '127.0.0.1:11211' ];
	$servers = [ $servers ] unless (ref($servers) eq 'ARRAY');
	return Cache::Memcached->new({
		servers => $servers,
		compress_threshold => 10_000,
	});
}

sub __key {
	my ($self, $id) = @_;
	return "$PREFIX:account:$id";
}

sub __verificationTokenKey {
	my ($self, $tokenId) = @_;
	return "$VERIFICATION_TOKEN_PREFIX:$tokenId";
}

sub __verificationTokenLockKey {
	my ($self, $tokenId) = @_;
	return "$VERIFICATION_TOKEN_PREFIX:lock:$tokenId";
}

sub __loginChallengeKey {
	my ($self, $digest) = @_;
	return "$LOGIN_CHALLENGE_PREFIX:$digest";
}

sub __loginChallengeLockKey {
	my ($self, $digest) = @_;
	return "$LOGIN_CHALLENGE_PREFIX:lock:$digest";
}

sub __indexKey {
	my ($self, $type, $value) = @_;
	$value = lc($value // '') if ($type eq 'username');
	return "$PREFIX:$type:" . sha1_hex($value // '');
}

sub __loadIndex {
	my ($self, $type, $value) = @_;
	my $id = $self->__call(get => $self->__indexKey($type, $value));
	return unless (defined($id));
	return $self->load($id);
}

__PACKAGE__->meta->make_immutable;

1;
