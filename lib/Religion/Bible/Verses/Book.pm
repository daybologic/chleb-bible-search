package Religion::Bible::Verses::Book;
use strict;
use warnings;
use Moose;

has verseCount => (is => 'ro', isa => 'Int');

has testament => (is => 'ro', isa => enum(['old', 'new']));

sub BUILD {
}

sub getVerseByOrdinal {
}

sub searchText {
	# TODO: Return list of Verse.pm objects
	# Actually, return SearchResult.pm
}

1;
