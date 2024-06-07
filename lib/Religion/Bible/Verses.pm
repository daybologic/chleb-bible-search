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
	my ($self, %params) = @_;
	return Religion::Bible::Verses::Search::Query->new(\%params);
}

1;
