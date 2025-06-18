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

package Chleb::Bible::Base;
use Moose;

use Chleb::DI::Container;

use DateTime;
use DateTime::Format::Strptime;
use English qw(-no_match_vars);
use Scalar::Util qw(blessed refaddr);

# TODO: Do we need a trap to ensure a fatal error occurs if the dic is constructed more than once?
has dic => (isa => 'Chleb::DI::Container', is => 'rw', lazy => 1, default => \&__makeDIContainer);

has _library => (isa => 'Chleb', is => 'rw', required => 0, init_arg => 'library'); # TODO: Can we make this required, or provide a default?

sub __makeDIContainer {
	my ($self) = @_;
	return Chleb::DI::Container->instance;
}

sub _resolveISO8601 {
	my ($self, $iso8601) = @_;

	$iso8601 ||= DateTime->now; # The default is the current time
	if (my $ref = blessed($iso8601)) {
		if ($ref->isa('DateTime')) {
			$self->dic->logger->error('NULL in _resolveISO8601!') unless (defined($iso8601));
			return $iso8601;
		} else {
			die('Unsupported blessed time format');
		}
	}

	$iso8601 =~ s/ /+/g; # Fix bad client behavior
	$self->dic->logger->trace("parsing date string '$iso8601'");

	my $format = DateTime::Format::Strptime->new(pattern => '%FT%T%z');
	eval {
		$iso8601 = $format->parse_datetime($iso8601);
	};

	if (my $evalError = $EVAL_ERROR) {
		die('Unsupported ISO-8601 time format: ' . $evalError);
	}

	$self->dic->logger->error('NULL in _resolveISO8601!') unless (defined($iso8601));
	return $iso8601;
}

=item C<_cmpAddress($a, $b)>

Compare the addresses of two objects and return a true value if they are the same.
If both objects are C<undef>, if this also considered success.  Logs at trace level
the actual addresses of the objects involved.

=cut

sub _cmpAddress {
	my ($self, @object) = @_;

	my @ci = caller(0);
	my $logMsg = sprintf('(%s L%d) ', $ci[1], $ci[2]);
	my @result = ( );

	my $c = 2;
	if ($c != scalar(@object)) {
		$logMsg .= sprintf('Must pass two objects to _cmpAddress, expected %d, received %d', $c, scalar(@object));
		die($logMsg);
	}

	for (my $i = 0; $i < $c; $i++) {
		if (my $address = refaddr($object[$i])) {
			$result[$i] = $address;
			$logMsg .= sprintf('0x%x', $address);
		} else {
			$result[$i] = 0;
			$logMsg .= '0x0';
		}

		$logMsg .= ' == ' if ($i == 0);
	}

	if ($result[0] == $result[1]) {
		$logMsg .= ' (*MATCH*)';
	} else {
		$logMsg .= ' (*mismatch*)';
	}

	$self->dic->logger->trace($logMsg);

	return ($result[0] == $result[1]);
}

__PACKAGE__->meta->make_immutable;

1;
