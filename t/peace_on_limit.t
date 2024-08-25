#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package PeaceOnEarthTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses;
use Religion::Bible::Verses::DI::MockLogger;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Religion::Bible::Verses->new());
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub testPeaceSearch {
	my ($self) = @_;
	plan tests => 2;

	my $query = $self->sut->newSearchQuery('peace on')->setLimit(3);
	cmp_deeply($query, all(
		isa('Religion::Bible::Verses::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace on',
		),
	), 'query inspection') or diag(explain($query));

	my @bookExpect = (
		all(
			isa('Religion::Bible::Verses::Book'),
			methods(
				ordinal      => 11,
				shortName    => '1Ki',
				chapterCount => 22,
				verseCount   => 816,
				testament    => 'old',
			),
		),
		all(
			isa('Religion::Bible::Verses::Book'),
			methods(
				ordinal      => 40,
				shortName    => 'Mat',
				chapterCount => 28,
				verseCount   => 1071,
				testament    => 'new',
			),
		),
		all(
			isa('Religion::Bible::Verses::Book'),
			methods(
				ordinal      => 41,
				shortName    => 'Mark',
				chapterCount => 16,
				verseCount   => 678,
				testament    => 'new',
			),
		),
	);

	my $results = $query->run();
	cmp_deeply($results, all(
		isa('Religion::Bible::Verses::Search::Results'),
		methods(
			count  => 3,
			verses => [
				all(
					isa('Religion::Bible::Verses::Verse'),
					methods(
						book    => $bookExpect[0],
						chapter => all(
							isa('Religion::Bible::Verses::Chapter'),
							methods(
								book       => $bookExpect[0],
								ordinal    => 4,
								verseCount => 34,
							),
						),
						ordinal => 24,
						text => 'For he had dominion over all [the region] on this side the river, from Tiphsah even to Azzah, over all the kings on this side the river: and he had peace on all sides round about him.',
					),
				),
				all(
					isa('Religion::Bible::Verses::Verse'),
					methods(
						book    => $bookExpect[1],
						chapter => all(
							isa('Religion::Bible::Verses::Chapter'),
							methods(
								book       => $bookExpect[1],
								ordinal    => 10,
								verseCount => 42,
							),
						),
						ordinal => 34,
						text    => 'Think not that I am come to send peace on earth: I came not to send peace, but a sword.',
					),
				),
				all(
					isa('Religion::Bible::Verses::Verse'),
					methods(
						book    => $bookExpect[2],
						chapter => all(
							isa('Religion::Bible::Verses::Chapter'),
							methods(
								book       => $bookExpect[2],
								ordinal    => 9,
								verseCount => 50,
							),
						),
						ordinal => 50,
						text    => 'Salt [is] good: but if the salt have lost his saltness, wherewith will ye season it? Have salt in yourselves, and have peace one with another.',
					),
				),
			],
		),
	), 'results inspection');

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Religion::Bible::Verses::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;

exit(PeaceOnEarthTests->new->run());
