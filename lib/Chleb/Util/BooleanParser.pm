package Chleb::Util::BooleanParser;
use strict;
use warnings;

use Readonly;

=item C<@TRUE_VALUES>

known true values; a fixed list.

=cut

Readonly my @TRUE_VALUES => ('1', 'true', 'on', 'yes');

=item C<@FALSE_VALUES>

known false values; a fixed list.

=cut

Readonly my @FALSE_VALUES => ('0', 'false', 'off', 'no');

=item C<parse($key, $value, [$defaultValue])>

Parse a user-supplied config boolean into a simple type.

The value may be null or anything supplied by the user, without sanity checking,
if the value is recognized from one of the known values: true/false, 1/0,
enabled/disabled, on/off, yes/no and so on, we return a simple scalar value.

If the value is null and a default value is specified, that default will be returned.
If no default is specified, the value is considered mandatory and {@link BooleanParserUserException} is
thrown.  If the default is not properly specified and not null, we throw {@link BooleanParserSystemException},
which means you need to fix your code.

	@param key String
	@param value String
	@param defaultValue String
	@return boolean
	@throws BooleanParserUserException
	@throws BooleanParserSystemException

=cut

sub parse {
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
			#die(BooleanParserSystemException->new($key, "Illegal default value: '$defaultValue' for key '$key'"));
			die "Illegal default value: '$defaultValue' for key '$key'";
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

			#die(BooleanParserUserException->new($key, "Illegal user-supplied value: '$value' for key '$key'"));
			die "Illegal user-supplied value: '$value' for key '$key'";
		}
	}

	return $defaultValueReturned if (defined($defaultValue)); # Apply default, if supplied/available
	#die(BooleanParserUserException->new($key, "Mandatory value for key '$key' not supplied"));
	die "Mandatory value for key '$key' not supplied";
}

1;
