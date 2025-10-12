package Chleb::Utils::SecureString;
use strict;
use warnings;
use utf8;

=head1 NAME

Chleb::Utils::SecureString - Detainter

=head1 DESCRIPTION

Store trusted strings

TODO: Convert fancy characters to ASCII, ie. special directional quotes,
phantom spaces to normal spaces etc.

=cut

use Chleb::Exception;
use Chleb::Utils::TypeParserException;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Moose;
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

=item C<stripped>

Indicates that tainted characters have been stripped, when the object
was created in C<$MODE_PERMIT> mode.  This might mean the value carries
little meaning, or that characters have been modified, but it might be fine,
ie. punctuation converted, weird characters taken out.

=cut

has stripped => (is => 'ro', isa => 'Bool', default => 0);

=item C<tainted>

B<read-only> value indicating that the L</value> is tainted, and must not be used,
it does B<not> mean that the bad values have been stripped, for that meaning, see
L</stripped>.

If you construct a C<SecureString> which has not been created via the detaint function,
it will have this flag set.

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

	__checkMode($mode);

	if (!defined($value)) {
		die(Chleb::Utils::TypeParserException->raise(
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
			die(Chleb::Utils::TypeParserException->raise(
				undef,
				sprintf(
					"Wrong \$value ref type (%s) in call to %s/detaint, should be a %s or scalar (Str)",
					ref($value), __PACKAGE__, __PACKAGE__,
				),
				"$value",
			));
		}
	}

	my $stripped = 0;
	my $detaintedValue = '';

	my @chars = split(m//, $value);
	for (my $ci = 0; $ci < scalar(@chars); $ci++) {
		my $c = $chars[$ci];
		my $cv = ord($c);
		my $inAnyRange = 0;

		for (my $rangePointer = 0; $rangePointer < @RANGES; $rangePointer += 2) {
			my ($rangeBegin, $rangeEnd) = ($RANGES[$rangePointer], $RANGES[$rangePointer+1]);
			$rangeEnd = $rangeBegin unless(defined($rangeEnd));
			if ($cv >= $rangeBegin && $cv <= $rangeEnd) {
				$inAnyRange = 1;
				last; # no need to check further ranges
			}
		}

		if ($inAnyRange) {
			$detaintedValue .= $c;
		} else {
			if ($mode && $mode == $MODE_PERMIT) {
				$stripped = 1; # drop character silently
			} else {
				die Chleb::Utils::TypeParserException->raise(
					undef,
					sprintf(
						'$value contains illegal character 0x%X at position %d of %d',
						$cv,
						$ci + 1,
						scalar(@chars),
					),
					$value,
				);
			}
		}
	}

	return __PACKAGE__->new({
		stripped => $stripped,
		tainted  => 0,
		value    => $detaintedValue,
	});
}

sub __checkMode {
	my ($mode) = @_;

	return unless ($mode);
	return if ($mode == $MODE_TRAP);
	return if ($mode == $MODE_PERMIT);

	return die Chleb::Exception->raise(
		HTTP_INTERNAL_SERVER_ERROR,
		'Illegal mode in call to Chleb::Utils::SecureString/detaint',
	);
}

=back

=cut

1;
