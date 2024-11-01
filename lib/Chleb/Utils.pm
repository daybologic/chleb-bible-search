package Chleb::Utils;
use strict;
use warnings;

=head1 FUNCTIONS

=over

=item C<forceArray($param)>

Given any user input C<$param>, force the content to become an C<ARRAY> ref.

=over

=item *

Comma-separated lists become separate elements.

=item *

Any C<ARRAY> is returned unmodified.

=item *

If undefined, an empty C<ARRAY> is returned.

=back

If the input cannot be handled, contains blessed objects or C<CODE> refs,
the function will throw a fatal error.

=cut

sub forceArray {
	my (@input) = @_;

	my @output = ( );
	foreach my $unknown (@input) {
		next unless (defined($unknown));
		if (ref($unknown) eq 'ARRAY') {
			push(@output, @$unknown);
			next;
		}
		push(@output, split(m/,/, $unknown));
	}

	return \@output;
}

=back

=cut

1;
