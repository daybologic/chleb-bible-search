#!/usr/bin/env perl

package PrideTests;
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

sub testPride {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->fetch('Prov', 16, 18);
	cmp_deeply($verse, all(
		isa('Religion::Bible::Verses::Verse'),
		methods(
			#limit         => 3,
			#testament     => undef,
			#bookShortName => undef,
			text          => 'Pride [goeth] before destruction, and an haughty spirit before a fall.',
		),
	), 'verse inspection') or diag(explain($verse));
	diag(explain($verse->text));

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(PrideTests->new->run());
