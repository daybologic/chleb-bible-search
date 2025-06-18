#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb;
use Chleb::DI::MockLogger;
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb->new());

	return EXIT_SUCCESS;
}

sub testPeaceSearch_defaultTranslation {
	my ($self) = @_;
	plan tests => 2;

	my $query = $self->sut->newSearchQuery('peace on earth')->setLimit(3);
	cmp_deeply($query, all(
		isa('Chleb::Bible::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace on earth',
			translation   => 'kjv',
		),
	), 'query inspection') or diag(explain($query));

	my @bookExpect = (
		all(
			isa('Chleb::Bible::Book'),
			methods(
				chapterCount => 28,
				longName     => 'Matthew',
				ordinal      => 40,
				shortName    => 'mat',
				shortNameRaw => 'Mat',
				testament    => 'new',
				verseCount   => 1_071,
			),
		),
		all(
			isa('Chleb::Bible::Book'),
			methods(
				chapterCount => 24,
				longName     => 'Luke',
				ordinal      => 42,
				shortName    => 'luke',
				shortNameRaw => 'Luke',
				testament    => 'new',
				verseCount   => 1_151,
			),
		),
	);

	my $results = $query->run();
	cmp_deeply($results, all(
		isa('Chleb::Bible::Search::Results'),
		methods(
			count  => 2,
			verses => [
				all(
					isa('Chleb::Bible::Verse'),
					methods(
						book    => $bookExpect[0],
						chapter => all(
							isa('Chleb::Bible::Chapter'),
							methods(
								book       => $bookExpect[0],
								ordinal    => 10,
								verseCount => 42,
							),
						),
						ordinal => 34,
						text    => 'Think not that I am come to send peace on earth: I came not to send peace, but a sword.',
					),
				),
				all(
					isa('Chleb::Bible::Verse'),
					methods(
						book    => $bookExpect[1],
						chapter => all(
							isa('Chleb::Bible::Chapter'),
							methods(
								book       => $bookExpect[1],
								ordinal    => 12,
								verseCount => 59,
							),
						),
						ordinal => 51,
						text    => 'Suppose ye that I am come to give peace on earth? I tell you, Nay; but rather division:',
					),
				),
			],
		),
	), 'results inspection');

	return EXIT_SUCCESS;
}

sub testPeaceSearch_asvTranslation {
	my ($self) = @_;
	plan tests => 6;

	# it's empty because the wording 'peace on earth' does not appear in the asv, only the kjv
	my $query = $self->sut->newSearchQuery(text => 'peace on earth', translation => 'asv')->setLimit(3);
	cmp_deeply($query, all(
		isa('Chleb::Bible::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace on earth',
			translation   => 'asv',
		),
	), "'peace on earth' query inspection") or diag(explain($query));

	my $results = $query->run();
	cmp_deeply($results, all(
		isa('Chleb::Bible::Search::Results'),
		methods(
			count  => 0,
			verses => [],
		),
	), 'results inspection (empty)');

	# we alter the query to 'peace on the earth' to pick up Matthew, but Luke does not match because it
	# says 'peace in the earth'.
	$query = $self->sut->newSearchQuery(text => 'peace on the earth', translation => 'asv')->setLimit(3);
	cmp_deeply($query, all(
		isa('Chleb::Bible::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace on the earth',
			translation   => 'asv',
		),
	), "'peace on the earth' query inspection") or diag(explain($query));

	my @bookExpect = (
		all(
			isa('Chleb::Bible::Book'),
			methods(
				chapterCount => 28,
				longName     => 'Matthew',
				ordinal      => 40,
				shortName    => 'mat',
				shortNameRaw => 'Mat',
				testament    => 'new',
				verseCount   => 1_071,
			),
		),
	);

	$results = $query->run();
	cmp_deeply($results, all(
		isa('Chleb::Bible::Search::Results'),
		methods(
			count  => 1,
			verses => [
				all(
					isa('Chleb::Bible::Verse'),
					methods(
						book    => $bookExpect[0],
						chapter => all(
							isa('Chleb::Bible::Chapter'),
							methods(
								book       => $bookExpect[0],
								ordinal    => 10,
								verseCount => 42,
							),
						),
						ordinal => 34,
						text    => 'Think not that I came to send peace on the earth: I came not to send peace, but a sword.',
					),
				),
			],
		),
	), 'results inspection');

	# we alter the query to 'peace in the earth' to pick up Luke, but Matthew does not match because it
	# says 'peace on the earth'.
	$query = $self->sut->newSearchQuery(text => 'peace in the earth', translation => 'asv')->setLimit(3);
	cmp_deeply($query, all(
		isa('Chleb::Bible::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace in the earth',
			translation   => 'asv',
		),
	), "'peace in the earth' query inspection") or diag(explain($query));

	@bookExpect = (
		all(
			isa('Chleb::Bible::Book'),
			methods(
				chapterCount => 24,
				longName     => 'Luke',
				ordinal      => 42,
				shortName    => 'luke',
				shortNameRaw => 'Luke',
				testament    => 'new',
				verseCount   => 1_151,
			),
		),
	);

	$results = $query->run();
	cmp_deeply($results, all(
		isa('Chleb::Bible::Search::Results'),
		methods(
			count  => 1,
			verses => [
				all(
					isa('Chleb::Bible::Verse'),
					methods(
						book    => $bookExpect[0],
						chapter => all(
							isa('Chleb::Bible::Chapter'),
							methods(
								book       => $bookExpect[0],
								ordinal    => 12,
								verseCount => 59,
							),
						),
						ordinal => 51,
						text    => 'Think ye that I am come to give peace in the earth? I tell you, Nay; but rather division:',
					),
				),
			],
		),
	), 'results inspection');

	return EXIT_SUCCESS;
}

sub testPeaceSearch_asvTranslationViaBible_textParam {
	my ($self) = @_;
	plan tests => 2;

	my $translation = 'asv';
	$self->sut($self->sut->__getBible($translation));
	my $query = $self->sut->newSearchQuery(text => 'peace in the earth')->setLimit(3);

	cmp_deeply($query, all(
		isa('Chleb::Bible::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace in the earth',
			translation   => 'asv',
		),
	), "'peace in the earth' query inspection") or diag(explain($query));

	my @bookExpect = (
		all(
			isa('Chleb::Bible::Book'),
			methods(
				longName     => 'Luke',
				chapterCount => 24,
				ordinal      => 42,
				shortName    => 'luke',
				shortNameRaw => 'Luke',
				testament    => 'new',
				verseCount   => 1_151,
			),
		),
	);

	my $results = $query->run();
	cmp_deeply($results, all(
		isa('Chleb::Bible::Search::Results'),
		methods(
			count  => 1,
			verses => [
				all(
					isa('Chleb::Bible::Verse'),
					methods(
						book    => $bookExpect[0],
						chapter => all(
							isa('Chleb::Bible::Chapter'),
							methods(
								book       => $bookExpect[0],
								ordinal    => 12,
								verseCount => 59,
							),
						),
						ordinal => 51,
						text    => 'Think ye that I am come to give peace in the earth? I tell you, Nay; but rather division:',
					),
				),
			],
		),
	), 'results inspection');

	return EXIT_SUCCESS;
}

sub testPeaceSearch_asvTranslationViaBible_direct {
	my ($self) = @_;
	plan tests => 2;

	my $translation = 'asv';
	$self->sut($self->sut->__getBible($translation));
	my $query = $self->sut->newSearchQuery('peace in the earth')->setLimit(3);

	cmp_deeply($query, all(
		isa('Chleb::Bible::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace in the earth',
			translation   => 'asv',
		),
	), "'peace in the earth' query inspection") or diag(explain($query));

	my @bookExpect = (
		all(
			isa('Chleb::Bible::Book'),
			methods(
				longName     => 'Luke',
				ordinal      => 42,
				shortName    => 'luke',
				shortNameRaw => 'Luke',
				chapterCount => 24,
				verseCount   => 1151,
				testament    => 'new',
			),
		),
	);

	my $results = $query->run();
	cmp_deeply($results, all(
		isa('Chleb::Bible::Search::Results'),
		methods(
			count  => 1,
			verses => [
				all(
					isa('Chleb::Bible::Verse'),
					methods(
						book    => $bookExpect[0],
						chapter => all(
							isa('Chleb::Bible::Chapter'),
							methods(
								book       => $bookExpect[0],
								ordinal    => 12,
								verseCount => 59,
							),
						),
						ordinal => 51,
						text    => 'Think ye that I am come to give peace in the earth? I tell you, Nay; but rather division:',
					),
				),
			],
		),
	), 'results inspection');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(PeaceOnEarthTests->new->run());
