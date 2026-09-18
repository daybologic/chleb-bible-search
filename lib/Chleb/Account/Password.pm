# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Account::Password;
use strict;
use warnings;
use Carp qw(croak);

use Chleb::Exception;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt bcrypt_hash en_base64);
use Fcntl qw(O_RDONLY);
use HTTP::Status qw(:constants);
use Readonly;

Readonly our $COST => 12;
Readonly my $SALT_LENGTH => 16;
Readonly my $BCRYPT_PREFIX => '$2a$';

=head1 NAME

Chleb::Account::Password

=head1 DESCRIPTION

Creates and verifies bcrypt password hashes for account credentials.  Only the
resulting bcrypt hash is intended to be persisted.

=head1 FUNCTIONS

=over

=item C<hash($password)>

Return a bcrypt hash for the supplied password.

=cut

sub hash {
	my ($password) = @_;
	__validatePassword($password);
	my $salt = __randomSalt();
	my $settings = {
		cost => $COST,
		key_nul => 1,
		salt => $salt,
	};
	return $BCRYPT_PREFIX . sprintf('%02d', $COST) . '$' . en_base64($salt) . en_base64(bcrypt_hash($settings, $password));
}

=item C<verify($password, $hash)>

Return true when a password matches a stored bcrypt hash.

=cut

sub verify {
	my ($password, $hash) = @_;
	return 0 unless (defined($password) && defined($hash) && ref($password) eq '' && ref($hash) eq '');
	return 0 unless ($hash =~ m{\A\$2a\$[0-9]{2}\$[./A-Za-z0-9]{22}[./A-Za-z0-9]{31}\z}x);
	my $verified = eval { bcrypt($password, $hash) eq $hash };
	return $verified ? 1 : 0;
}

=back

=cut

sub __validatePassword {
	my ($password) = @_;
	my $valid = defined($password) && ref($password) eq '' && length($password) > 0;
	croak(Chleb::Exception->raise(HTTP_BAD_REQUEST, 'Password must be a non-empty string'))
		if (!$valid);
	my $tooLong = length($password) > 72;
	croak(Chleb::Exception->raise(HTTP_BAD_REQUEST, 'Password is too long'))
		if ($tooLong);
	return;
}

sub __randomSalt {
	my $random = '';
	my $opened = sysopen(my $randomHandle, '/dev/urandom', O_RDONLY);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to open the system random source'))
		unless ($opened);
	while (length($random) < $SALT_LENGTH) {
		my $read = sysread($randomHandle, $random, $SALT_LENGTH - length($random), length($random));
		last if (!defined($read) || $read <= 0);
	}
	close($randomHandle);
	croak(Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Unable to obtain secure password salt'))
		unless (length($random) == $SALT_LENGTH);
	return $random;
}

1;
