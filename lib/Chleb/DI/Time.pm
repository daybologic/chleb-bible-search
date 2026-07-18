# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Chleb::DI::Time;
use strict;
use warnings;
use Moose;

=head1 NAME

Chleb::DI::Time - mockable wall-clock time

=head1 DESCRIPTION

Central wall-clock service for code which would otherwise call C<time> or
C<sleep> directly.  Tests may pin time with C<setMockedTime()>; once pinned, C<get()>
returns only the pinned value and C<sleep()> advances it without waiting.

=cut

has __value => (is => 'rw', isa => 'Maybe[Num]', predicate => '__hasValue');

=head1 METHODS

=over

=item C<get()>

Returns the mocked time if defined, otherwise returns C<CORE::time()>.

=cut

sub get {
	my ($self) = @_;
	return $self->__value if ($self->__hasValue && defined($self->__value));
	return CORE::time();
}

=item C<setMockedTime($value)>

Sets and returns the mocked time value.

=cut

sub setMockedTime {
	my ($self, $value) = @_;
	return $self->__value($value);
}

=item C<sleep($seconds)>

If mocked time is defined, increments it by C<$seconds> and returns immediately.
Otherwise, calls C<CORE::sleep>.

=cut

sub sleep { ## no critic (Subroutines::ProhibitBuiltinHomonyms)
	my ($self, $seconds) = @_;

	if ($self->__hasValue && defined($self->__value)) {
		return $self->__value($self->__value + $seconds);
	}

	return CORE::sleep($seconds);
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
