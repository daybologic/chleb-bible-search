# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::Repository;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Account::Repository::Memcached;
use Readonly;

Readonly our $BACKEND => 'Memcached';

has __backend => (is => 'ro', lazy => 1, builder => '__makeBackend');

sub create {
	my ($self, $attributes) = @_;
	return $self->__backend->create($attributes);
}

sub __makeBackend { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return Chleb::Account::Repository::Memcached->new({ dic => $self->dic });
}

__PACKAGE__->meta->make_immutable;

1;
