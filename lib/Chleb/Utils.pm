package Chleb::Utils;
use strict;
use warnings;

=head1 NAME

Chleb::Utils - Functions for miscellaneous internal purposes

=head1 DESCRIPTION

Functions for miscellaneous internal purposes

=cut

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

=item C<removeArrayEmptyItems($arrayRef)>

Given an C<ARRAY>, remove any item which is not defined or has no length,
and return a new C<ARRAY>.  The original is not modified.

=cut

sub removeArrayEmptyItems {
	my ($arrayRef) = @_;

	my @filtered = ( );
	foreach my $value (@$arrayRef) {
		next if (!defined($value));
		next if (length($value) == 0);
		push(@filtered, $value);
	}
	return \@filtered;
}

sub queryParamsHelper {
	my ($params) = @_;

	my $str = '';
	my $counter = 0;
	my %blacklist = map { $_ => 1 } (qw(book chapter contentType translation verse version when)); # TODO: We should aim to eliminate this hack

	while (my ($k, $v) = each(%$params)) {
		next if ($blacklist{$k});
		$str .= ($counter == 0) ? '?' : '&';
		$v = join(',', @$v) if (ref($v) eq 'ARRAY');
		$v = 'all' if ($v eq 'asv,kjv' && $k eq 'translations'); # TODO: You should do this via a callback
		$str .= "${k}=${v}";
		$counter++;
	}

	return $str;
}

=back

=cut

1;
