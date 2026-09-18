#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package AccountPasswordTests;
## no critic (Modules::RequireFilenameMatchesPackage)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Account::Password;
use Test::More 0.96;

sub testBcryptHashCanBeVerified {
	my ($self) = @_;
	plan tests => 5;

	my $hash = Chleb::Account::Password::hash('correct horse battery staple');
	like($hash, qr{\A\$2a\$12\$[./A-Za-z0-9]{53}\z}x, 'password hash uses bcrypt cost 12');
	ok(Chleb::Account::Password::verify('correct horse battery staple', $hash), 'correct password verifies');
	ok(!Chleb::Account::Password::verify('incorrect password', $hash), 'incorrect password does not verify');
	isnt(Chleb::Account::Password::hash('correct horse battery staple'), $hash, 'password hashes use a random salt');
	ok(!Chleb::Account::Password::verify('correct horse battery staple', 'not-a-bcrypt-hash'), 'invalid stored hash does not verify');

	return 0;
}

sub testPasswordHashRejectsEmptyAndOverlongPasswords {
	my ($self) = @_;
	plan tests => 2;

	my $emptyOk; $emptyOk = eval { Chleb::Account::Password::hash(''); 1; } or $emptyOk = 0;
	my $longOk; $longOk = eval { Chleb::Account::Password::hash('x' x 73); 1; } or $longOk = 0;
	is($emptyOk, 0, 'empty password is rejected');
	is($longOk, 0, 'password over bcrypt maximum length is rejected');

	return 0;
}

__PACKAGE__->meta->make_immutable;

exit(AccountPasswordTests->new->run());
