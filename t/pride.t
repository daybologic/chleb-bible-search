#!/usr/bin/env perl

package PrideTests;
use strict;
use warnings;
use Moose;

extends 'Test::Module::Runnable';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses;
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Religion::Bible::Verses->new());

	return EXIT_SUCCESS;
}

sub testPride {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->fetch('Prov', 16, 18);
	cmp_deeply($verse, all(
		isa('Religion::Bible::Verses::Verse'),
		methods(
			book    => methods(
				ordinal   => 20,
				longName  => 'Proverbs',
				shortName => 'Prov',
				testament => 'old',
			),
			chapter => methods(
				ordinal => 16,
			),
			ordinal => 18,
			text    => 'Pride [goeth] before destruction, and an haughty spirit before a fall.',
		),
	), 'verse inspection') or diag(explain($verse));
	diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub testBadBook {
	my ($self) = @_;
	plan tests => 1;

	throws_ok { $self->sut->fetch('Mormon', 16, 18) } qr/Long book name 'Mormon' is not a book in the bible/,
	    'exception thrown';

	return EXIT_SUCCESS;
}

sub testBadChapter {
	my ($self) = @_;
	plan tests => 1;

	throws_ok { $self->sut->fetch('Prov', 36, 1) } qr/Chapter 36 not found in Prov/,
	    'exception thrown';

	return EXIT_SUCCESS;
}

sub testBadVerse {
	my ($self) = @_;
	plan tests => 1;

	throws_ok { $self->sut->fetch('Luke', 24, 54) } qr/Verse 54 not found in Luke 24/,
	    'exception thrown';

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(PrideTests->new->run());
