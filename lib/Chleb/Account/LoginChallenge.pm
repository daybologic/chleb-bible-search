# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).
# All rights reserved.

package Chleb::Account::LoginChallenge;
use strict;
use warnings;
use Carp qw(croak);

use Chleb::Exception;
use Digest::SHA qw(sha256_hex);
use Fcntl qw(O_RDONLY);
use HTTP::Status qw(:constants);
use MIME::Base64 qw(encode_base64);
use Readonly;

Readonly my $RANDOM_BYTES => 32;

=head1 NAME

Chleb::Account::LoginChallenge

=head1 DESCRIPTION

Creates short-lived, one-time login challenges.  The challenge value is
returned to the client, while repositories persist only its SHA-256 digest.

=head1 FUNCTIONS

=over

=item C<generate($dic, $username, $ttl)>

Create a login challenge record for the normalized username.

=cut

sub generate {
	my ($dic, $username, $ttl) = @_;
	my $createdAt = int($dic->time->get());
	my $value = __randomValue();
	return {
		value => $value,
		digest => sha256_hex($value),
		username => lc($username),
		created_at => $createdAt,
		expires_at => $createdAt + int($ttl),
	};
}

=item C<digest($value)>

Return the repository-safe digest for a challenge value.

=cut

sub digest {
	my ($value) = @_;
	return sha256_hex($value // '');
}

=back

=cut

sub __randomValue {
	my $random = '';
	my $opened = sysopen(my $randomHandle, '/dev/urandom', O_RDONLY);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to open the system random source'))
		unless ($opened);
	while (length($random) < $RANDOM_BYTES) {
		my $read = sysread($randomHandle, $random, $RANDOM_BYTES - length($random), length($random));
		last if (!defined($read) || $read <= 0);
	}
	close($randomHandle);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to obtain secure login challenge data'))
		unless (length($random) == $RANDOM_BYTES);
	my $value = encode_base64($random, '');
	$value =~ tr{+/}{-_};
	$value =~ s{=+\z}{}x;
	return $value;
}

1;
