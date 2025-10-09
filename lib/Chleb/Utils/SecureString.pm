package Chleb::Utils::SecureString;
use strict;
use warnings;

=head1 NAME

Chleb::Utils::SecureString - Detainter

=head1 DESCRIPTION

Store trusted strings

TODO: It is possible to get a tainted string via $MODE_PERMIT,
should we have an optional mode which strips bad characters?

=cut

use Chleb::Utils::TypeParserException;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Readonly;

=head1 CONSTANTS

=over

=item *

$MODE_TRAP (default)

=item *

$MODE_PERMIT

=back

=cut

Readonly our $MODE_TRAP => 0;
Readonly our $MODE_PERMIT => 1;

=head1 PRIVATE CONSTANTS

=over

=item C<@RANGES>

A list of tuples of ranges of acceptable character value ranges.

=cut

Readonly my @RANGES => (
	0x09, undef,
	0x0A, undef,
	0x0D, undef,
	0x20, 0x7E,
	#0xA0, 0xFF,
);

=item C<$MAX_TEXT_LENGTH>

The maximum length of a string.

=cut

Readonly my $MAX_TEXT_LENGTH => 4_096;

=back

=head1 ATTRIBUTES

=over

=item C<tainted>

B<read-only> value indicating that the L</value> is tainted, and must not be used,
it does B<not> mean that the bad values have been stripped!

=cut

has tainted => (is => 'ro', isa => 'Bool', default => 1);

=item C<value>

C<read-only> value which is safe to use, unless L</tainted> is set.
B<mandatory>.

=cut

has value => (is => 'ro', isa => 'Str', required => 1);

=back

=head1 STATIC FUNCTIONS

=over

=item C<detaint($value, [$mode])>

Returns a new L<Chleb::Utils::SecureString> which has been detainted.

The C<value> may be a C<Str> or another L<Chleb::Utils::SecureString>.

Optional C<$mode> may be one of the $MODE_ constants, the default being C<$MODE_TRAP>.
If the C<$value> is C<not> legal, L</tainted> is set, in C<$MODE_PERMIT> mode, otherwise
L<Chleb::Utils::TypeParserException> will be thrown.

An C<undef> value is never valid and will trigger L<Chleb::Utils::TypeParserException>
regardless of mode.

=cut

sub detaint {
	my ($value, $mode) = @_;

	if (!defined($value)) {
		die(Chleb::Utils::BooleanParserUserException->raise(
			undef,
			sprintf(
				"\$value (<undef>) in call to %s/detaint, should be a %s or scalar (Str)",
				__PACKAGE__, __PACKAGE__,
			),
			$value,
		));
	} elsif (ref($value)) {
		if (ref($value) eq __PACKAGE__) {
			my $tainted = $value->tainted;
			$value = $value->value;
			return $value unless ($tainted); # shortcut because we know it's safe
		} else {
			die(Chleb::Utils::BooleanParserUserException->raise(
				undef,
				sprintf(
					"Wrong \$value ref type (%s) in call to %s/detaint, should be a %s or scalar (Str)",
					ref($value), __PACKAGE__, __PACKAGE__,
				),
				$value,
			));
		}
	}

	my $tainted = 0;

	my $l = length($value);
	my @chars = split(m//, $value);
	CHAR: for (my $i = 0; $i < $l; $i++) {
		my $c = $chars[$i];
		my $rangePointer = 0;
		for (my $rangePointer = 0; $rangePointer < scalar(@RANGES); $rangePointer += 2) {
			my ($rangeBegin, $rangeEnd) = ($RANGES[$rangePointer], $RANGES[$rangePointer+1]);
			$rangeEnd = $rangeBegin unless (defined($rangeEnd)); # single char in range
			my $cv = oct($c);
			if ($cv < $rangeBegin || $cv > $rangeEnd) {
				if ($mode && $mode == $MODE_PERMIT) {
					$tainted = 1;
					last CHAR;
				} else {
					die(Chleb::Utils::BooleanParserUserException->raise(
						undef,
						sprintf(
							'$value contains illegal character 0x%X at position %d of %d',
							$cv, $i+1, $l,
						),
						$c,
					));
				}
			}
		}
	}

	return __PACKAGE__->new({
		tainted => $tainted,
		value   => $value,
	});
}

=back

=cut

1;
