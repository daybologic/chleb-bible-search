package Chleb::Utils;
use strict;
use warnings;

=head1 NAME

Chleb::Utils - Functions for miscellaneous internal purposes

=head1 DESCRIPTION

Functions for miscellaneous internal purposes

=cut

use Chleb::Utils::BooleanParserSystemException;
use Chleb::Utils::BooleanParserUserException;
use Readonly;
use Scalar::Util qw(blessed);

=head1 PRIVATE CONSTANTS

=over

=item C<@TRUE_VALUES>

known true values; a fixed list.

=cut

Readonly my @TRUE_VALUES => ('1', 'true', 'on', 'yes');

=item C<@FALSE_VALUES>

known false values; a fixed list.

=cut

Readonly my @FALSE_VALUES => ('0', 'false', 'off', 'no');

=back

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
	my %blacklist = map { $_ => 1 } (qw(accept book chapter translation verse version when)); # TODO: We should aim to eliminate this hack

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

=item C<parse($key, $value, [$defaultValue])>

Parse a user-supplied config boolean into a simple type.

The value may be undef or anything supplied by the user, without sanity checking,
if the value is recognized from one of the known values: true/false, 1/0,
enabled/disabled, on/off, yes/no and so on, we return a simple scalar value.

If the value is undef and a default value is specified, that default will be returned.
If no default is specified, the value is considered mandatory and L<Chleb::Utils::BooleanParserUserException> is
thrown.  If the default is not properly specified and not undef, we throw
L<Chleb::Utils::BooleanParserSystemException>, which means you need to fix your code.

@param key String
@param value String
@param defaultValue String
@return boolean
@throws BooleanParserUserException
@throws BooleanParserSystemException

=cut

sub boolean {
	my ($key, $value, $defaultValue) = @_;
	my $defaultValueReturned = 0;

	my $isTrue = sub {
		my ($v) = @_;

		foreach my $trueValues (@TRUE_VALUES) {
			return 1 if ($v eq $trueValues);
		}

		return ($v =~ m/^enable/);
	};

	my $isFalse = sub {
		my ($v) = @_;

		foreach my $falseValues (@FALSE_VALUES) {
			return 1 if ($v eq $falseValues);
		}

		return ($v =~ m/^disable/);
	};

	# Let's run this block first so we trap invalid defaults even when they aren't used
	if (defined($defaultValue)) {
		$defaultValue = lc($defaultValue);
		if ($isTrue->($defaultValue)) {
			$defaultValueReturned = 1;
		} elsif (!$isFalse->($defaultValue)) {
			die(Chleb::Utils::BooleanParserSystemException->raise(
				undef,
				"Illegal default value: '$defaultValue' for key '$key'",
				$key,
			));
		}
	}

	if (defined($value)) {
		my $trim = sub {
			my ($v) = @_;
			$v =~ s/^\s+//;
			$v =~ s/\s+$//;
			return $v;
		};

		$value = $trim->($value);
		if (length($value) > 0) {
			$value = lc($value);

			return 1 if ($isTrue->($value));
			return 0 if ($isFalse->($value));

			die(Chleb::Utils::BooleanParserUserException->raise(
				undef,
				"Illegal user-supplied value: '$value' for key '$key'",
				$key,
			));
		}
	}

	return $defaultValueReturned if (defined($defaultValue)); # Apply default, if supplied/available

	die(Chleb::Utils::BooleanParserUserException->raise(
		undef,
		"Mandatory value for key '$key' not supplied",
		$key,
	));
}

=back

=cut

1;
