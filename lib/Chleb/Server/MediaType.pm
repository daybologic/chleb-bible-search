# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Chleb::Server::MediaType;
use Moose;
use strict;
use warnings;

=head1 NAME

Chleb::Server::MediaType

=head1 DESCRIPTION

Accept / Content-Type header

=cut

use Chleb::Exception;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use Moose::Util::TypeConstraints;
use Readonly;
use Scalar::Util qw(blessed);

Readonly my $DEFAULT_HEADER => '*/*';
Readonly my $MINIMUM_LENGTH => 3;

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
		length($_) > 0 && m/^\S+$/ && ! m@^/+$@
	},
	message {
		'incomplete spec'
	};

has [qw(major minor)] => (is => 'ro', required => 1, isa => 'Part');

=back

=head1 METHODS

=over

=item C<BUILD>

Hook called by Moose on object construction.

=cut

sub BUILD {
	my ($self) = @_;
	return;
}

=item C<parseAcceptHeader($str)>

Create and return a new L<Chleb::Server::MediaType>,
or die with a L<Chleb::Exception>.

The header is expected to be the content of an 'Accept' header,
but L<HTTP::Headers> is also accepted, and we'll process the right header.

=cut

sub parseAcceptHeader {
	my ($class, $str) = @_;

	$str = __resolveObject($str);
	if (!defined($str) || length($str) == 0) {
		$str = $DEFAULT_HEADER;
	} elsif (length($str) < $MINIMUM_LENGTH) {
		die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, 'Accept: header too short');
	}

	my @parts = split(m@/@, lc($str), 2);
	my $obj;
	eval {
		$obj = $class->new({
			major => $parts[0],
			minor => $parts[1],
		});
	};

	if (my $evalError = $EVAL_ERROR) {
		if (blessed($evalError) && blessed($evalError) eq 'Moose::Exception::ValidationFailedForTypeConstraint') {
			die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, __extractMessageFromMooseException($evalError))
		} else {
			die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, 'unknown error');
		}
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, 'Accept: wildcard misused')
	    if ($obj->major eq '*' && $obj->minor ne '*');

	return $obj;
}

=back

=head1 PRIVATE METHODS

=over

=item C<__resolveObject($str|$obj)>

Return a string, and resolve and discard an L<HTTP::Headers> object.

=cut

sub __resolveObject {
	my ($str) = @_;

	return $str unless (blessed($str));
	return $str->header('Accept');
}

=item C<__extractMessageFromMooseException($exception)>

=cut

sub __extractMessageFromMooseException {
	my ($exception) = @_;
	my $message = (split(m/:/, $exception->message))[1];
	return "Accept:${message}";
}

=back

=cut

1;