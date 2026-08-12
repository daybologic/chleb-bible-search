#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

package InfoToHtmlServerTests;
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Server::Moose;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testBookLinks {
	my ($self) = @_;
	plan tests => 3;

	my $html = Chleb::Server::Moose::__infoToHtml({
		included => [
			{
				type => 'book',
				attributes => {
					long_name => 'Genesis',
					short_name => 'gen',
					ordinal => 1,
					chapter_count => 1,
					testament => 'old',
					verse_count => 31_102,
					sample_verse_text => 'In the beginning',
					sample_verse_chapter_ordinal => 1,
					sample_verse_ordinal_in_chapter => 1,
				},
			},
			{
				type => 'chapter',
				attributes => {
					book => 'gen',
					ordinal => 2,
					verse_count => 25,
				},
			},
		],
	});

	like($html, qr{href="/1/lookup/gen/1">Genesis</a>}x, 'Book column links to the first chapter');
	like($html, qr{href="/1/lookup/gen/2">2</a>}x, 'Chapter column links to the selected chapter');
	unlike($html, qr{href="/1/lookup/gen/2/1">2</a>}x, 'Chapter column does not link to verse one');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(InfoToHtmlServerTests->new->run());
