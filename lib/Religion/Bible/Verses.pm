package Religion::Bible::Verses;
use strict;
use warnings;
use Moose;

use Religion::Bible::Verses::Search::Query;

has bookCount => (is => 'ro', isa => 'Int');

sub BUILD {
}

sub getBookByShortName {
}

sub getBookByLongName {
}

sub getBookByOrdinal {
}

sub newSearchQuery {
	my ($self, @args) = @_;

	return Religion::Bible::Verses::Search::Query->new({ text => $args[0] })
	    if (scalar(@args) == 1);

	my %params = @args;
	return Religion::Bible::Verses::Search::Query->new(\%params);
}

1;
