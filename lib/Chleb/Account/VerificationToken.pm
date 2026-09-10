# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::VerificationToken;
use strict;
use warnings;
use Carp qw(croak);

use Chleb::Exception;
use Digest::SHA qw(sha256_hex);
use Fcntl qw(O_RDONLY);
use HTTP::Status qw(:constants);
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

=item C<generate($dic, $accountId)>

Generate a 256-bit hexadecimal token and its persistable metadata.

=cut

sub generate {
	my ($dic, $accountId) = @_;
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

	my $value = sha256_hex($random);
	return {
		account_id => int($accountId),
		token_hash => sha256_hex($value),
		value => $value,
		created_at => $createdAt,
		expires_at => $createdAt + $LIFETIME,
	};
}

=back

=cut

1;
