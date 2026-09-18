# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::Repository;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Account::Repository::Memcached;
use Chleb::Account::Repository::Dynamo;
use Chleb::Account::VerificationToken;
use Readonly;

Readonly our $BACKEND => 'Memcached';

has backend => (is => 'ro', isa => 'Str', default => $BACKEND);
has __backend => (is => 'ro', lazy => 1, builder => '__makeBackend');

sub create {
	my ($self, $attributes) = @_;
	return $self->__backend->create($attributes);
}

sub load {
	my ($self, $accountId) = @_;
	return $self->__backend->load($accountId);
}

sub loadByUsername {
	my ($self, $username) = @_;
	return $self->__backend->loadByUsername($username);
}

sub createVerificationToken {
	my ($self, $accountId) = @_;
	return $self->__backend->createVerificationToken($accountId);
}

sub loadVerificationToken {
	my ($self, $tokenId) = @_;
	return $self->__backend->loadVerificationToken($tokenId);
}

sub consumeVerificationToken {
	my ($self, $tokenId, $accountId) = @_;
	return $self->__backend->consumeVerificationToken($tokenId, $accountId);
}

=head1 activate

Activate an account after successful verification.

=cut

sub activate {
	my ($self, $accountId) = @_;
	return $self->__backend->activate($accountId);
}

sub __makeBackend { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	my %backends = (
		Dynamo => 'Chleb::Account::Repository::Dynamo',
		Memcached => 'Chleb::Account::Repository::Memcached',
	);
	croak("Unknown account repository backend '" . $self->backend . "'")
		unless (exists($backends{ $self->backend }));
	return $backends{ $self->backend }->new({ dic => $self->dic });
}

__PACKAGE__->meta->make_immutable;

1;
