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
	my ($self, $critereonText) = @_;
	# TODO: Return list of Verse.pm objects
	# Actually, return Search::Result ?
	for (my $chapterOrdinal = 1; $chapterOrdinal <= $self->chapterCount; $chapterOrdinal++) {
		my $chapter = $self->getChapterByOrdinal($chapterOrdinal);

		for (my $verseOrdinal = 1; $verseOrdinal <= $chapter->verseCount; $verseOrdinal++) {
			my $verseKey = $self->__makeVerseKey($chapterOrdinal, $verseOrdinal);
			# TODO: You shouldn't access __backend here
			# but you need some more methods in the library to avoid it
			# Perhaps have a getVerseByKey in _library?
			my $text = $self->_library->__backend->getVerseDataByKey($verseKey);
			if ($text =~ m/$critereonText/) {
				warn $text;
			}
		}
	}
}

sub toString {
	my ($self) = @_;
	return 'Book ' . $self->shortName;
}

sub getChapterByOrdinal {
	my ($self, $ordinal) = @_;
	my $chapter = Religion::Bible::Verses::Chapter->new({
		_library => $self->_library,
		book     => $self,
		ordinal  => $ordinal,
	});
}

sub __makeVerseKey {
	my ($self, $chapterOrdinal, $verseOrdinal) = @_;
	return join(':', $TRANSLATION, $self->shortName, $chapterOrdinal, $verseOrdinal);
}

1;
