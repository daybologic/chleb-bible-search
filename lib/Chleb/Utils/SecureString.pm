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

=item *

$MODE_COERCE

=item *

$MODE_TRIM

=back

=cut

Readonly our $MODE_TRAP   => 1 << 0;  # 0x0001
Readonly our $MODE_PERMIT => 1 << 1;  # 0x0002
Readonly our $MODE_COERCE => 1 << 2;  # 0x0004
Readonly our $MODE_TRIM   => 1 << 3;  # 0x0008

=head1 PRIVATE CONSTANTS

=over

=item C<%COERCIONS>

A list of Unicode characters and their LATIN-1 translations.
You need tm specify L</$MODE_COERCE> in order to take advantage of these.

=cut

Readonly my %COERCIONS => (
	"\x{A0}"   => ' ',
	"\x{2002}" => ' ',
	"\x{2003}" => ' ',
	"\x{2009}" => ' ',
	"\x{200A}" => ' ',
	"\x{2008}" => ' ',
	"\x{3000}" => ' ',
	"\x{200B}" => ' ',
	"\x{FEFF}" => ' ',

	"\x{201C}" => '"',
	"\x{201D}" => '"',
	"\x{201E}" => '"',
	"\x{AB}"   => '"',
	"\x{BB}"   => '"',
	"\x{301D}" => '"',
	"\x{301E}" => '"',

	"\x{2018}" => "'",
	"\x{2019}" => "'",
	"\x{201A}" => "'",
	"\x{2018}" => "'",
	"\x{2019}" => "'",
	"\x{2BB}"  => "'",
	"\x{2BB}"  => "'",
	"\x{3010}" => "'",
	"\x{3011}" => "'",

	"\x{2013}" => '-',
);

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

=item C<coerced>

Indicates that characters have been coerced for stylistic characters, such
as special spaces and quotes to raw LATIN-1.

=cut

has coerced => (is => 'ro', isa => 'Bool', default => 0);

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

=item C<trimmed>

True if, and only if, whitespace has been trimmed, which requires C<$MODE_TRIM> to be requested.

=cut

has trimmed => (is => 'ro', isa => 'Bool', default => 0);

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
	my $coerced = 0;
	my $detaintedValue = '';

	my @chars = split(m//, $value);
	for (my $ci = 0; $ci < scalar(@chars); $ci++) {
		my $thisCharCoerced = 0;
		my $c = $chars[$ci];
		my $cv = ord($c);

		if (defined($mode) && ($mode & $MODE_COERCE) == $MODE_COERCE) {
			COERCE_LOOP: while (my ($bad, $good) = each(%COERCIONS)) {
				next COERCE_LOOP if ($cv != ord($bad));

				$c = $chars[$ci] = $good;
				$cv = ord($c);
				$coerced = $thisCharCoerced = 1;
			}
		}

		my $inAnyRange = 0;
		if ($thisCharCoerced) {
			$inAnyRange = 1;
		} else {
			for (my $rangePointer = 0; $rangePointer < @RANGES; $rangePointer += 2) {
				my ($rangeBegin, $rangeEnd) = ($RANGES[$rangePointer], $RANGES[$rangePointer+1]);
				$rangeEnd = $rangeBegin unless(defined($rangeEnd));
				if ($cv >= $rangeBegin && $cv <= $rangeEnd) {
					$inAnyRange = 1;
				}
			}
		}

		if ($inAnyRange) {
			$detaintedValue .= $c;
		} else {
			if (defined($mode) && ($mode & $MODE_PERMIT) == $MODE_PERMIT) {
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

	my $preTrim = $detaintedValue;
	if (defined($mode) && ($mode & $MODE_TRIM) == $MODE_TRIM) {
		$detaintedValue =~ s/^\s+//;
		$detaintedValue =~ s/\s+$//;
		$detaintedValue =~ s/\s+/ /g;
	}

	return __PACKAGE__->new({
		coerced  => $coerced,
		stripped => $stripped,
		tainted  => 0,
		trimmed  => (length($preTrim) > length($detaintedValue)),
		value    => $detaintedValue,
	});
}

sub __checkMode {
	my ($mode) = @_;

	return unless (defined($mode));
	my @modes = ($MODE_TRAP, $MODE_PERMIT, $MODE_COERCE, $MODE_TRIM);
	foreach my $checkMode (@modes) {
		return if (($mode & $checkMode) == $checkMode);
	}

	return die Chleb::Exception->raise(
		HTTP_INTERNAL_SERVER_ERROR,
		'Illegal mode in call to Chleb::Utils::SecureString/detaint',
	);
}

=back

=cut

1;
