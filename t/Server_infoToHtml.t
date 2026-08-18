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
	plan tests => 7;

	my $html = Chleb::Server::Moose::__infoToHtml({
		included => [
			{
				type => 'stats',
				attributes => { msec => 123 },
			},
			{
				type => 'book',
				attributes => {
					long_name => 'Genesis',
					short_name => 'gen',
					translation => 'kjv',
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
					translation => 'kjv',
					verse_count => 25,
				},
			},
		],
	});

	like($html, qr{href="/1/lookup/gen/1\?translations=kjv">Genesis</a>}x, 'Book column links to the first chapter');
	like($html, qr{<th>Translation</th>}x, 'chapter table labels the translation column');
	like($html, qr{<td>kjv</td>}x, 'chapter table displays the translation');
	like($html, qr{href="/1/lookup/gen/2\?translations=kjv">2</a>}x, 'Chapter column links to the selected chapter');
	like($html, qr{href="/1/lookup/gen/2/25\?translations=kjv">25</a>}x, 'Verse column links preserve the translation');
	unlike($html, qr{href="/1/lookup/gen/2/1">2</a>}x, 'Chapter column does not link to verse one');
	like($html, qr{Sought \s+ in \s+ 0[.]123 \s+ seconds}x, 'info HTML displays timing');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(InfoToHtmlServerTests->new->run());
