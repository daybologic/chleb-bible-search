# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::VerificationToken;
use strict;
use warnings;
use Carp qw(croak);

use Chleb::Exception;
use Fcntl qw(O_RDONLY);
use HTTP::Status qw(:constants);
use MIME::Base64 qw(encode_base64);
use Readonly;

Readonly our $LIFETIME => 24 * 60 * 60;
Readonly my $RANDOM_BYTES => 32;

=head1 NAME

Chleb::Account::VerificationToken

=head1 DESCRIPTION

Creates cryptographically random account-verification tokens and their
persistable metadata.

=head1 FUNCTIONS

=over

=item C<formatUtc($epoch)>

Format an epoch timestamp as a UTC account timestamp.

=cut

sub formatUtc {
	my ($epoch) = @_;
	my ($secondValue, $minute, $hour, $day, $month, $year) = gmtime(int($epoch));
	return sprintf('%04d-%02d-%02dT%02d:%02d:%02d+0000', $year + 1900, $month + 1, $day, $hour, $minute, $secondValue);
}

=item C<generate($dic, $accountId, $tokenId)>

Generate a 256-bit URL-safe Base64 token and its persistable metadata.

=cut

sub generate {
	my ($dic, $accountId, $tokenId) = @_;
	my $createdAt = int($dic->time->get());
	my $random = '';
	my $opened = sysopen(my $randomHandle, '/dev/urandom', O_RDONLY);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to open the system random source'))
		unless ($opened);

	while (length($random) < $RANDOM_BYTES) {
		my $read = sysread($randomHandle, $random, $RANDOM_BYTES - length($random), length($random));
		last if (!defined($read) || $read <= 0);
	}
	close($randomHandle);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to obtain secure random data'))
		unless (length($random) == $RANDOM_BYTES);

	my $value = encode_base64($random, '');
	$value =~ tr{+/}{-_};
	$value =~ s{=+\z}{}x;
	return {
		account_id => int($accountId),
		token_id => int($tokenId),
		value => $value,
		created_at => $createdAt,
		expires_at => $createdAt + $LIFETIME,
	};
}

=back

=cut

1;
