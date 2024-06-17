#!/usr/bin/env perl

package PeaceOnEarthTests;
use strict;
use warnings;
use Moose;

extends 'Test::Module::Runnable';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Religion::Bible::Verses->new());

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

package main;
use strict;
use warnings;

exit(PeaceOnEarthTests->new->run());
