package Chleb::Utils;
use strict;
use warnings;

use Scalar::Util qw(blessed);

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

	my $noObjects = sub {
		my ($item) = @_;
		die('no blessed object support') if (blessed($item));
		die('no CODE support') if (ref($item) eq 'CODE');
		die('no HASH support') if (ref($item) eq 'HASH');
	};

	my @output = ( );
	foreach my $unknown (@input) {
		unless (defined($unknown)) {
			push(@output, undef);
			next;
		}
		$noObjects->($unknown);
		if (ref($unknown) eq 'ARRAY') {
			foreach my $subItem (@$unknown) {
				if (defined($subItem)) {
					$noObjects->($subItem);
					push(@output, split(m/,/, $subItem));
				} else {
					push(@output, $subItem);
				}
			}
			next;
		}
		push(@output, split(m/,/, $unknown));
	}

	return \@output;
}

=back

=cut

1;