## no critic (RegularExpressions::ProhibitComplexRegexes)
## no critic (RegularExpressions::RequireExtendedFormatting)
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
#!/usr/bin/env perl
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

package SearchResultsToHtmlServerTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server::Dancer2;
use Chleb::Server::Moose;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server::Moose->new());

	return EXIT_SUCCESS;
}

sub testEmpty {
	my ($self) = @_;
	plan tests => 1;

	$self->mock('Chleb::Server::Dancer2', 'fetchStaticPage');

	my %json = ( data => [ ] );
	Chleb::Server::Moose::__searchResultsToHtml(\%json);

	my $mockCalls = $self->mockCallsWithObject('Chleb::Server::Dancer2', 'fetchStaticPage');
	cmp_deeply($mockCalls, [['no_results']], "calls to fetchStaticPage for 'no_results'") or diag(explain($mockCalls));

	return EXIT_SUCCESS;
}

sub testResultsTable {
	my ($self) = @_;
	plan tests => 7;

	my %json = (
		data => [
			{
				attributes => {
					book => 'gen',
					chapter => 1,
					ordinal => 1,
					text => 'In the beginning God created the heaven and the earth.',
					title => "Result 1/1 from Chleb Bible Search 'beginning'",
				},
			},
		],
		included => [
			{
				type => 'book',
				attributes => {
					short_name => 'gen',
					short_name_raw => 'Gen',
				},
			},
		],
	);

	my $html = Chleb::Server::Moose::__searchResultsToHtml(\%json);
	like($html, qr{<a class="vn-link vn-home" href="/">home</a>}, 'home link is present by default');
	like($html, qr{<table class="info-table">}, 'search results use info table');
	like($html, qr{<th>Result</th>}, 'result header is present');
	like($html, qr{<th>Verse</th>}, 'verse header is present');
	like($html, qr{<a href="/1/lookup/gen/1/1">Gen \[1:1\]</a>}, 'verse link is present');
	like($html, qr{<td>In the beginning God created the heaven and the earth\.</td>}, 'verse text is in a table cell');

	my $htmlWithoutHome = Chleb::Server::Moose::__searchResultsToHtml(\%json, { includeHome => 0 });
	unlike($htmlWithoutHome, qr{<a class="vn-link vn-home" href="/">home</a>}, 'home link can be suppressed');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(SearchResultsToHtmlServerTests->new->run());
