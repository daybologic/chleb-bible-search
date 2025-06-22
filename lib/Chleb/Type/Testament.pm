# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Chleb::Type::Testament;
use strict;
use warnings;
use Moose;

=head1 NAME

Chleb::Type::Testament - Which half of the bible

=head1 DESCRIPTION

Object representing one testament name within The Holy Bible

=cut

extends 'Chleb::Bible::Base';

use Moose::Util::TypeConstraints;
use Readonly;
use Scalar::Util qw(blessed refaddr);

coerce 'Chleb::Type::Testament',
	from 'Str',
	via {
		Chleb::Type::Testament->new({ value => $_ });
	};

=head1 CONSTANTS

=over

=item C<$ANY>

Either testament is acceptable, if seeking.  If the owning object
represents something already sought, then this means the testament is
unknown, which should not be possible.

=cut

Readonly our $ANY => 'any';

=back

=item C<$OLD>

The Old Testament.

=cut

Readonly our $OLD => 'old';

=back

=item C<$NEW>

The New Testament.

=cut

Readonly our $NEW => 'new';

=back

=head1 ATTRIBUTES

=over

=item C<value>

The testament.

=cut

has value => (
	is => 'ro',
	isa => enum([$ANY, $OLD, $NEW]),
	required => 1,
);

=back

=head1 METHODS

=over

=item C<createFromBackendValue($value)>

=cut

sub createFromBackendValue {
	my ($class, $backendValue) = @_;

	my $value = $NEW;
	$value = $OLD if ($backendValue eq 'O');
	return $class->new({ value => $value });
}

=item C<toString()>

Human-readable representation.

=cut

sub toString {
	my ($self) = @_;
	return $self->value;
}

=item C<equals($other)>

Returns true if this testament object represents the same testament as another.
both strings and objects are supported.

=cut

sub equals {
	my ($self, $other) = @_;

	return 0 if (!$other);
	if (my $blessing = blessed($other)) {
		return 1 if (refaddr($self) == refaddr($other));
		return ($self->value eq $other->value) if ($blessing eq ref($self));
		return 0;
	}

	return ($self->value eq $other);
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
