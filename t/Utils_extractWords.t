#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

package UtilsExtractWordsTests;
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use utf8;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Utils;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testExtractsWords {
	my ($self) = @_;
	plan tests => 1;

	is_deeply(
		Chleb::Utils::extractWords("Dropping, dripping; mother-in-law John's 123 café."),
		[ 'Dropping', 'dripping', 'mother-in-law', "John's", '123', 'café' ],
		'extracts words with supported punctuation and Unicode',
	);

	return EXIT_SUCCESS;
}

sub testEmptyInput {
	my ($self) = @_;
	plan tests => 2;

	is_deeply(Chleb::Utils::extractWords(), [], 'undefined input has no words');
	is_deeply(Chleb::Utils::extractWords(''), [], 'empty input has no words');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(UtilsExtractWordsTests->new->run());
