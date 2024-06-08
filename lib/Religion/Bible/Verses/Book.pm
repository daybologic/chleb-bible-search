package Religion::Bible::Verses::Book;
use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints qw(enum);

has ordinal => (is => 'ro', isa => 'Int');

has [qw(shortName longName)] => (is => 'ro', isa => 'Str');

has [qw(chapterCount verseCount)] => (is => 'ro', isa => 'Int');

has testament => (is => 'ro', isa => enum(['old', 'new', 'unknown'])); # FIXME: unknown will go away in the future

sub BUILD {
}

sub getVerseByOrdinal {
}

sub searchText {
	# TODO: Return list of Verse.pm objects
	# Actually, return SearchResult.pm
}

1;
