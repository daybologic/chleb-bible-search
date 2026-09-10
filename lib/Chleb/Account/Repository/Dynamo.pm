# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::Repository::Dynamo;
use strict;
use warnings;
use Carp qw(croak);
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Exception;
use Chleb::Account::VerificationToken;
use Digest::SHA qw(sha1_hex);
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Readonly;

Readonly our $TABLE => 'chleb-accounts';
Readonly my $ACCOUNT_SORT_KEY => 'account';
Readonly my $COUNTER_PARTITION_KEY => 'counter';
Readonly my $COUNTER_SORT_KEY => 'accounts';

has client => (is => 'ro', init_arg => 'client', predicate => '__hasClient');
has table => (is => 'ro', isa => 'Str', lazy => 1, builder => '__makeTable');
has __clientObject => (is => 'rw', lazy => 1, builder => '__makeClient');

sub create {
	my ($self, $attributes) = @_;
	my $existing = $self->loadByEmail($attributes->{email});
	return $existing if ($existing);

	my $id = $self->__allocateId();
	my $account = {
		id => int($id),
		created_at => Chleb::Account::VerificationToken::formatUtc($self->dic->time->get()),
		%{ $attributes },
		status => 'pending',
	};
	my $transaction = [
		{
			Put => {
				TableName => $self->table,
				Item => $self->__accountItem($account),
				ConditionExpression => 'attribute_not_exists(pk)',
			},
		},
		{
			Put => {
				TableName => $self->table,
				Item => $self->__indexItem('email', $attributes->{email}, $id),
				ConditionExpression => 'attribute_not_exists(pk)',
			},
		},
		{
			Put => {
				TableName => $self->table,
				Item => $self->__indexItem('username', $attributes->{username}, $id),
				ConditionExpression => 'attribute_not_exists(pk)',
			},
		},
	];

	my $evalOk; $evalOk = eval {
		$self->__client->TransactWriteItems(TransactItems => $transaction);
		1;
	} or $evalOk = 0;
	unless ($evalOk) {
		$existing = $self->loadByEmail($attributes->{email});
		return $existing if ($existing);
		croak(Chleb::Exception->raise(HTTP_CONFLICT, 'The account username is already in use'))
			if ($self->loadByUsername($attributes->{username}));
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "DynamoDB account transaction failed: $EVAL_ERROR"));
	}

	$account->{_created} = 1;
	return $account;
}

sub createVerificationToken {
	my ($self, $accountId) = @_;
	my $token = Chleb::Account::VerificationToken::generate($self->dic, $accountId);
	my $item = {
		pk => { S => 'verification-token#' . $token->{token_hash} },
		sk => { S => 'token' },
		account_id => { N => q{} . $token->{account_id} },
		token_hash => { S => $token->{token_hash} },
		created_at => { N => q{} . $token->{created_at} },
		expires_at => { N => q{} . $token->{expires_at} },
	};
	my $evalOk; $evalOk = eval {
		$self->__client->PutItem(
			TableName => $self->table,
			Item => $item,
			ConditionExpression => 'attribute_not_exists(pk)',
		);
		1;
	} or $evalOk = 0;
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "DynamoDB verification token storage failed: $EVAL_ERROR"))
		unless ($evalOk);
	return $token;
}

sub load {
	my ($self, $id) = @_;
	my $response = $self->__client->GetItem(
		TableName => $self->table,
		Key => $self->__key($id),
		ConsistentRead => 1,
	);
	return unless ($response && $response->Item);
	return $self->__accountFromItem($response->Item);
}

sub loadByEmail {
	my ($self, $email) = @_;
	return $self->__loadIndex('email', $email);
}

sub loadByUsername {
	my ($self, $username) = @_;
	return $self->__loadIndex('username', $username);
}

sub __allocateId {
	my ($self) = @_;
	my $response = $self->__client->UpdateItem(
		TableName => $self->table,
		Key => {
			pk => { S => $COUNTER_PARTITION_KEY },
			sk => { S => $COUNTER_SORT_KEY },
		},
		UpdateExpression => 'ADD next_id :one',
		ExpressionAttributeValues => { ':one' => { N => '1' } },
		ReturnValues => 'UPDATED_NEW',
	);
	my $id = $response && $response->Attributes && $response->Attributes->{next_id}->{N};
	if (!defined($id) || $id !~ m{ \A[0-9]+\z }x || int($id) <= 0) {
		croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to allocate an account ID'));
	}
	return int($id);
}

sub __loadIndex {
	my ($self, $type, $value) = @_;
	my $response = $self->__client->GetItem(
		TableName => $self->table,
		Key => $self->__indexKey($type, $value),
		ConsistentRead => 1,
	);
	return unless ($response && $response->Item);
	my $id = $response->Item->{account_id}->{N};
	return $self->load($id);
}

sub __accountItem {
	my ($self, $account) = @_;
	return {
		pk => { S => 'account#' . $account->{id} },
		sk => { S => $ACCOUNT_SORT_KEY },
		id => { N => q{} . $account->{id} },
		created_at => { S => $account->{created_at} },
		title => { S => $account->{title} },
		username => { S => $account->{username} },
		email => { S => $account->{email} },
		name => { S => $account->{name} },
		status => { S => $account->{status} },
	};
}

sub __accountFromItem {
	my ($self, $item) = @_;
	return {
		id => int($item->{id}->{N}),
		created_at => $item->{created_at}->{S},
		title => $item->{title}->{S},
		username => $item->{username}->{S},
		email => $item->{email}->{S},
		name => $item->{name}->{S},
		status => $item->{status}->{S},
	};
}

sub __indexItem {
	my ($self, $type, $value, $id) = @_;
	$value = lc($value // '') if ($type eq 'username');
	return {
		pk => { S => "$type#" . sha1_hex($value // '') },
		sk => { S => 'unique' },
		account_id => { N => q{} . $id },
	};
}

sub __indexKey {
	my ($self, $type, $value) = @_;
	$value = lc($value // '') if ($type eq 'username');
	return {
		pk => { S => "$type#" . sha1_hex($value // '') },
		sk => { S => 'unique' },
	};
}

sub __key {
	my ($self, $id) = @_;
	return {
		pk => { S => 'account#' . $id },
		sk => { S => $ACCOUNT_SORT_KEY },
	};
}

sub __makeTable { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return $self->dic->config->get('accounts', 'dynamodb', { table => $TABLE })->{table} // $TABLE;
}

sub __client {
	my ($self) = @_;
	return $self->client if ($self->__hasClient);
	return $self->__clientObject;
}

sub __makeClient { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	my $evalOk; $evalOk = eval {
		require Paws;
		1;
	} or $evalOk = 0;
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Cannot load Paws for DynamoDB accounts: $EVAL_ERROR"))
		unless ($evalOk);

	my $config = $self->dic->config->get('accounts', 'dynamodb', {});
	my %options = ( region => $config->{region} // $ENV{AWS_REGION} // 'eu-west-2' );
	$options{endpoint} = $config->{endpoint} if (defined($config->{endpoint}));
	return Paws->service('DynamoDB', %options);
}

__PACKAGE__->meta->make_immutable;

1;
