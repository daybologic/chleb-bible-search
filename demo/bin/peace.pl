#!/usr/bin/env perl

package main;
use strict;
use warnings;
use lib 'lib';

use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses;

sub main {
	my ($query) = (@ARGV);
	my $bible = Religion::Bible::Verses->new();

	$query = $bible->newSearchQuery($query)->setLimit(5);
	# FIXME: Need to limit to one book?  should be able to do this via Query.pm

	my $results = $query->run();
	#printf("There were %d results for query %s\n", $results->count, $query->toString()); # TODO: Use Log4Perl
	printf("There were %d results for query \"%s\"\n", $results->count, $query->text); # TODO: Use Log4Perl
	for (my $resultI = 0; $resultI < $results->count; $resultI++) {
		my $result = $results->verses->[$resultI];
		printf("Result %d/%d: %s %d:%d - \"%s\"\n", $resultI+1, $results->count, $result->book->longName, $result->chapter->ordinal, $result->ordinal, $result->text);
	}

	return EXIT_SUCCESS;
}


exit(main()) unless (caller());
