# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::Role;
use strict;
use warnings;
use Carp qw(croak);

use Chleb::Exception;
use HTTP::Status qw(:constants);
use Readonly;

Readonly our $USER => 1;
Readonly our $MODERATOR => 2;
Readonly our $ADMIN => 3;
Readonly our %VALUES => (
	user => $USER,
	moderator => $MODERATOR,
	admin => $ADMIN,
);
Readonly my %NAMES => reverse(%VALUES);

=head1 NAME

Chleb::Account::Role

=head1 DESCRIPTION

Maps the public account-role names to their numeric persisted values.

=head1 FUNCTIONS

=over

=item C<name($value)>

Return the public role name for a persisted numeric role value.

=cut

sub name {
	my ($value) = @_;
	return $NAMES{$value}
		if (defined($value) && exists($NAMES{$value}));
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, "Unknown account role value '$value'"));
}

=back

=cut

1;
