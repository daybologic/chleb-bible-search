package Religion::Bible::Verses::Chapter;
use strict;
use warnings;
use Moose;

has book => (is => 'ro', isa => 'Religion::Bible::Verses::Book', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

has verseCount => (is => 'ro', isa => 'Int', required => 1);

sub BUILD {
}

sub toString {
	my ($self) = @_;
	return sprintf('%s %d', $self->book->shortName, $self->ordinal);
}

1;
