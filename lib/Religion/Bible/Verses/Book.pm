package Religion::Bible::Verses::Book;
use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Readonly;
use Religion::Bible::Verses::Chapter;

Readonly my $TRANSLATION => 'kjv';

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has ordinal => (is => 'ro', isa => 'Int');

has [qw(shortName longName)] => (is => 'ro', isa => 'Str');

has [qw(chapterCount verseCount)] => (is => 'ro', isa => 'Int');

has testament => (is => 'ro', isa => enum(['old', 'new']));

sub BUILD {
}

sub getVerseByOrdinal {
}

sub searchText {
	my ($self, $text) = @_;
	# TODO: Return list of Verse.pm objects
	# Actually, return Search::Result ?
	for (my $chapterOrdinal = 1; $chapterOrdinal <= $self->chapterCount; $chapterOrdinal++) {
		my $verseKey = $self->__makeVerseKey($chapterOrdinal, 1); # TODO: How do we get the verse count by chapter here?

		die $self->getChapterByOrdinal($chapterOrdinal);
#		die $self->getVerseCountByChapter
		# TODO: You shouldn't access __backend here
		# but you need some more methods in the library to avoid it
		my $text = $self->_library->__backend->getVerseDataByKey($verseKey); # TODO: Perhaps have a getVerseByKey in _library?
		warn $text;
	}
}

sub toString {
	my ($self) = @_;
	return 'Book ' . $self->shortName;
}

sub getChapterByOrdinal {
	my ($self, $ordinal) = @_;
	#use Religion::Bible::Verses::Chapter;
	die 'TODO: make new Chapter object for ' . $self->toString();
}

sub __makeVerseKey {
	my ($self, $chapterOrdinal, $verseOrdinal) = @_;
	return join(':', $TRANSLATION, $self->shortName, $chapterOrdinal, $verseOrdinal);
}

1;
