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
use Digest::SHA qw(sha1_hex);
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use JSON qw(decode_json encode_json);
use Readonly;

Readonly our $PREFIX => 'chleb-accounts';
Readonly my $PERMANENT_TTL => 0;
Readonly my $NEXT_ID_KEY => "$PREFIX:next-id";

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
		%{ $attributes },
		status => 'pending',
	};
	my $stored = $self->__call(set => $self->__key($id), encode_json($account), $PERMANENT_TTL);
	unless ($stored) {
		$self->__call(delete => $emailKey);
		$self->__call(delete => $usernameKey);
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to store the new account'));
	}

	return $account;
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

sub __indexKey {
	my ($self, $type, $value) = @_;
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
