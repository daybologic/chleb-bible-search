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

package Chleb::Server::MediaType::Item;
use Moose;
use strict;
use warnings;

=head1 NAME

Chleb::Server::MediaType::Item

=head1 DESCRIPTION

One media item type from an Accept header

=cut

use Chleb::Args::Base;
use Moose::Util::TypeConstraints;

=head1 ATTRIBUTES

=over

=item C<major>

The major media type, such as 'application', or 'text'.

=item C<minor>

The minor media type, such as 'html', or 'json'.

=cut

subtype 'Part',
	as 'Str',
	where {
		defined($_) && length($_) > 0 && m/^\S+$/ && ! m@^/+$@
	},
	message {
		'incomplete spec'
	};

has [qw(major minor)] => (is => 'ro', required => 1, isa => 'Part');

=item C<weight>

The weight, whose default is always 1.0.  Lower values indicate a backup priority only.
Valid values are between 0.000 and 1.000.  Greater precisions are not permitted.

=cut

has weight => (is => 'ro', required => 1, isa => 'Num', default => 1.0, required => 1, trigger => \&__triggerWeight);

=back

=head1 METHODS

=over

=item C<toString([$args])>

Return the media type in the standard major/minor format.

C<$args> must be a L<Chleb::Server::MediaType::Args::ToString> object, if present.

=cut

sub toString {
	my ($self, $args) = @_;
	$args = Chleb::Args::Base::makeDummy('Chleb::Server::MediaType::Args::ToString', $args);

	my $str = join('/', $self->major, $self->minor);

	$str .= sprintf(';q=%.3f', $self->weight)
	    if ($args->verbose);

	return $str;
}

=back

=head1 PRIVATE METHODS

=over

=item C<__triggerWeight>

Special handler for accesses to L</weight>.
We check that the value does not have too much precison.

=cut

sub __triggerWeight {
	my ($self) = @_;

	my $str4 = sprintf('%.4f', abs($self->weight));
	my $str3 = sprintf('%.3f', abs($self->weight));

	my $v = $str4 - $str3;
	die("weight (qValue) precisions are limited to 3 digits\n") if ($v > 0);

	return;
};

=back

=cut

1;
