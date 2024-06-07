#!/usr/bin/env perl

package main;
use strict;
use warnings;
use lib 'lib';

use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses;

sub main {
	my $bible = Religion::Bible::Verses->new();

	my $query = $bible->newSearchQuery(text => 'dwelt')->setLimit(10);
	# FIXME: Need to limit to one book?  should be able to do this via Query.pm

	my $results = $query->run();
	printf("There were %d results for query %s\n", $results->count, $query->toString()); # TODO: Use Log4Perl

	return EXIT_SUCCESS;
}


exit(main()) unless (caller());
