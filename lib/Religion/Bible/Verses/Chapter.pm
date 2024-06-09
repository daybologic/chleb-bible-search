package Religion::Bible::Verses::Chapter;
use strict;
use warnings;
use Moose;

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has book => (is => 'ro', isa => 'Religion::Bible::Verses::Book', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

has verseCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeVerseCount);

sub BUILD {
}

sub toString {
	my ($self) = @_;
	return sprintf('%s %d', $self->book->shortName, $self->ordinal);
}

sub __makeVerseCount {
	my ($self) = @_;
	my $bookInfo = $self->_library->__backend->getBookInfoByShortName($self->book->shortName);
	die 'FIXME' unless ($bookInfo);
	my $count = $bookInfo->{v}->{ $self->ordinal };
	die("FIXME: $count") unless ($count);
	return $count;
}

1;
