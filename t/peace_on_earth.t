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
	), 'query inspection');

	my $results = $query->run();
	cmp_deeply($results, all(
		isa('Religion::Bible::Verses::Search::Results'),
		methods(
			count  => 0,
			verses => [],
		),
	), 'results inspection');

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(PeaceOnEarthTests->new->run());
