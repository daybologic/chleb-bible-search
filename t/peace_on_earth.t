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

	my $query = $self->sut->newSearchQuery('peace on earth')->setLimit(3);
	cmp_deeply($query, all(
		isa('Religion::Bible::Verses::Search::Query'),
		methods(
			limit         => 3,
			testament     => undef,
			bookShortName => undef,
			text          => 'peace on earth',
		),
	), 'query inspection') or diag(explain($query));

	my @bookExpect = (
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
				ordinal      => 42,
				shortName    => 'Luke',
				chapterCount => 24,
				verseCount   => 1151,
				testament    => 'new',
			),
		),
	);

	my $results = $query->run();
	cmp_deeply($results, all(
		isa('Religion::Bible::Verses::Search::Results'),
		methods(
			count  => 2,
			verses => [
				all(
					isa('Religion::Bible::Verses::Verse'),
					methods(
						book    => $bookExpect[0],
						chapter => all(
							isa('Religion::Bible::Verses::Chapter'),
							methods(
								book       => $bookExpect[0],
								ordinal    => 10,
								verseCount => 42,
							),
						),
						ordinal => 34,
						text    => "\"Think not that I am come to send peace on earth: I came not to send peace, but a sword.\"\n",
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
								ordinal    => 12,
								verseCount => 59,
							),
						),
						ordinal => 51,
						text    => "\"Suppose ye that I am come to give peace on earth? I tell you, Nay; but rather division:\"\n",
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
