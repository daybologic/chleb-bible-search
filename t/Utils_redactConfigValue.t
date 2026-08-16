#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package UtilsRedactConfigValueTests;
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Utils;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testNonSecretUnchanged {
	my ($self) = @_;
	plan tests => 2;

	is(Chleb::Utils::redactConfigValue('issuer', 'chleb'), 'chleb', 'ordinary value is unchanged');
	is(Chleb::Utils::redactConfigValue(undef, 'chleb'), 'chleb', 'value without a key is unchanged');

	return EXIT_SUCCESS;
}

sub testSecretRedacted {
	my ($self) = @_;
	plan tests => 4;

	is(Chleb::Utils::redactConfigValue('secret', 'sensitive'), '***', 'secret is redacted');
	is(Chleb::Utils::redactConfigValue('SECRET', 'sensitive'), '***', 'matching is case insensitive');
	is(Chleb::Utils::redactConfigValue('client_secret', 'sensitive'), '***', 'compound secret key is redacted');
	is(Chleb::Utils::redactConfigValue('secret', { nested => 'sensitive' }), '***', 'entire secret structure is redacted');

	return EXIT_SUCCESS;
}

sub testRedactingDumper {
	my ($self) = @_;
	plan tests => 6;

	my $input = {
		public => 'visible',
		nested => {
			secret => 'hidden',
		},
		list => [
			{ client_secret => 'also-hidden' },
			'ordinary',
		],
	};
	my $dump = Chleb::Utils::redactingDumper($input);

	like($dump, qr{ \Q'public' => 'visible'\E }x, 'ordinary hash value is dumped');
	like($dump, qr{ \Q'secret' => '***'\E }x, 'nested secret is redacted');
	like($dump, qr{ \Q'client_secret' => '***'\E }x, 'secret nested within an array is redacted');
	unlike($dump, qr{ \Qhidden\E }x, 'nested secret content is absent');
	is($input->{nested}->{secret}, 'hidden', 'source hash is not modified');
	is($input->{list}->[0]->{client_secret}, 'also-hidden', 'source array content is not modified');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(UtilsRedactConfigValueTests->new->run());
