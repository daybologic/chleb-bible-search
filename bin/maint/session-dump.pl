#!/usr/bin/env perl

package main;
use strict;
use warnings;
use Data::Dumper;
use POSIX qw(EXIT_SUCCESS);
use Storable qw(retrieve);

sub main {
	my (@argv) = (@ARGV);

	my $session = retrieve($argv[0]);
	print Dumper $session;

	return EXIT_SUCCESS;
}

exit(main()) unless (caller());
