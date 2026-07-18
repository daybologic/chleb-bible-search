# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Chleb::Token::Repository::JWT;
use strict;
use warnings;
use Moose;

extends 'Chleb::Token::Repository::Base';

use Chleb::Exception;
use Chleb::Token;
use Digest::SHA qw(hmac_sha256);
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use JSON::PP;
use MIME::Base64 qw(decode_base64url encode_base64url);
use Readonly;

=head1 NAME

Chleb::Token::Repository::JWT

=head1 CONFIG

	session_tokens:
	  backend_jwt:
	    secret: replace-with-a-long-random-secret
	  load_order:
	    - JWT
	  save_order:
	    - JWT

=head1 DESCRIPTION

Stateless JWT-backed session token repository.

Tokens are encoded as HS256 JSON Web Tokens.  The signed payload contains the
same token metadata used by the stateful repositories, except for the token
value itself.  The internal C<created> and C<expires> fields are represented by
the registered JWT C<iat> and C<exp> claims.  Because the token is
self-contained, saving re-signs the token and stores the new JWT value on the
L<Chleb::Token> object instead of writing to external storage.

=head1 CONSTANTS

=over

=item C<$ALGORITHM>

The JWT algorithm identifier.  This backend supports C<HS256>.

=item C<$TYPE>

The JWT type header value.  This backend emits C<JWT>.

=back

=cut

Readonly my $ALGORITHM => 'HS256';
Readonly my $TYPE => 'JWT';

=head1 ATTRIBUTES

=over

=item C<__json>

Private L<JSON::PP> encoder/decoder used for deterministic JWT header and
payload serialization.

=cut

has __json => (is => 'ro', isa => 'JSON::PP', lazy => 1, builder => '__makeJson');

=item C<__secret>

Private HMAC secret loaded from C<session_tokens.backend_jwt.secret>.

=cut

has __secret => (is => 'ro', isa => 'Str', lazy => 1, builder => '__makeSecret');

=back

=head1 METHODS

=over

=item C<create()>

Creates a new L<Chleb::Token> using this JWT repository as the source and signs
it immediately, so C<value> is a usable JWT before the caller saves it again
with request-specific metadata.

=cut

sub create {
	my ($self) = @_;

	my $token = Chleb::Token->new({
		dic     => $self->dic,
		ttl     => $self->_ttl,
		_repo   => $self->repo,
		_source => $self,
	});

	$self->save($token);
	return $token;
}

=item C<load($value)>

Verifies and decodes a JWT string or C<Dancer2::Core::Cookie>, rebuilds the
L<Chleb::Token>, checks the token data version and expiry time, and returns the
token.  Invalid, tampered, stale, or expired values are raised as
L<Chleb::Exception> instances in the same style as the other repositories.

=cut

sub load {
	my ($self, $value) = @_;

	$value = $value->value if (ref($value) && $value->isa('Dancer2::Core::Cookie'));
	$self->_valueValidate($value);

	my $data = eval {
		$self->__decode($value);
	};

	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->debug($evalError);
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'sessionToken unrecognized via ' . __PACKAGE__);
	}

	my $token;
	eval {
		$token = Chleb::Token->fromJWTClaims($data, {
			dic       => $self->dic,
			_repo     => $self->repo,
			_source   => $self,
			_value    => $value,
		});
	};

	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->error($evalError);
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Token cannot be rebuilt using stored data');
	} elsif ($token->major != $Chleb::Token::DATA_VERSION_MAJOR) {
		$self->dic->logger->error(sprintf('Version mismatch in %s, (store %d, expect %d), stale data?', $token->toString(), $token->major, $Chleb::Token::DATA_VERSION_MAJOR));
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, "Sorry, the token went stale because of a version mismatch, remove your sessionToken cookie and you'll get a new one");
	} elsif ($token->expired) {
		die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'sessionToken expired via ' . __PACKAGE__);
	}

	$token->dirty(0);
	$token->isNew(0);

	return $token;
}

=item C<save($token)>

Signs the current token metadata into a JWT and writes that JWT back to the
token's internal value.  No external state is written.

=cut

sub save {
	my ($self, $token) = @_;

	$token->_setValue($self->__encode($token->TO_JWT()));
	$token->dirty(0);
	$token->isNew(0);

	return;
}

=item C<_valueValidate($value)>

Validates that C<$value> has the three-segment base64url JWT shape expected by
this repository.

=cut

sub _valueValidate {
	my ($self, $value) = @_;
	return 1 if (defined($value) && $value =~ m{ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ }x);

	die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'The sessionToken format must be JWT');
}

=back

=head1 PRIVATE METHODS

=over

=item C<__encode($payload)>

Encodes a payload hash reference as a signed JWT string.

=cut

sub __encode {
	my ($self, $payload) = @_;

	my $header = {
		alg => $ALGORITHM,
		typ => $TYPE,
	};

	my $signingInput = join('.', map {
		$self->__base64urlEncode($self->__json->encode($_));
	} ($header, $payload));

	return join('.', $signingInput, $self->__signature($signingInput));
}

=item C<__decode($value)>

Verifies a JWT signature and decodes the JSON payload.  The JWT header must use
the supported algorithm and, when present, the expected type.

=cut

sub __decode {
	my ($self, $value) = @_;

	my ($encodedHeader, $encodedPayload, $encodedSignature) = split(m{ \. }x, $value, 3);
	my $signingInput = join('.', $encodedHeader, $encodedPayload);
	my $expectedSignature = $self->__signature($signingInput);
	die('JWT signature mismatch') unless (__secureCompare($encodedSignature, $expectedSignature));

	my $header = $self->__json->decode($self->__base64urlDecode($encodedHeader));
	die('JWT algorithm mismatch') unless ($header->{alg} eq $ALGORITHM);
	die('JWT type mismatch') unless (!defined($header->{typ}) || $header->{typ} eq $TYPE);

	my $payload = $self->__json->decode($self->__base64urlDecode($encodedPayload));
	die('JWT missing iat') unless (defined($payload->{iat}));
	die('JWT missing exp') unless (defined($payload->{exp}));

	return $payload;
}

=item C<__signature($signingInput)>

Returns the base64url-encoded HS256 signature for the supplied JWT signing
input.

=cut

sub __signature {
	my ($self, $signingInput) = @_;
	return $self->__base64urlEncode(hmac_sha256($signingInput, $self->__secret));
}

=item C<__base64urlEncode($data)>

Encodes raw data using unpadded base64url encoding.

=cut

sub __base64urlEncode {
	my ($self, $data) = @_;
	my $encoded = encode_base64url($data);
	$encoded =~ s{=+\z}{}x;
	return $encoded;
}

=item C<__base64urlDecode($data)>

Decodes unpadded base64url data.

=cut

sub __base64urlDecode {
	my ($self, $data) = @_;
	my $padding = length($data) % 4;
	$data .= '=' x (4 - $padding) if ($padding);
	return decode_base64url($data);
}

=item C<__makeJson()>

Builds the JSON encoder/decoder used by L</__json>.

=cut

sub __makeJson {
	my ($self) = @_;
	return JSON::PP->new->canonical->utf8->allow_nonref;
}

=item C<__makeSecret()>

Loads and validates the JWT signing secret from configuration.

=cut

sub __makeSecret {
	my ($self) = @_;

	my $config = $self->dic->config->get('session_tokens', 'backend_jwt', { secret => undef });
	my $secret = $config->{secret};
	die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'session_tokens.backend_jwt.secret must be configured')
	    unless (defined($secret) && length($secret));

	return $secret;
}

=item C<__secureCompare($left, $right)>

Compares two strings without returning early after the first differing byte.

=cut

sub __secureCompare {
	my ($left, $right) = @_;
	return 0 unless (defined($left) && defined($right));
	return 0 unless (length($left) == length($right));

	my $diff = 0;
	for (my $i = 0; $i < length($left); $i++) {
		$diff |= ord(substr($left, $i, 1)) ^ ord(substr($right, $i, 1));
	}

	return $diff == 0;
}

=back

=cut

1;
