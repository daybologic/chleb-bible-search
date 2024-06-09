package Religion::Bible::Verses;
use strict;
use warnings;
use Data::Dumper;
use Moose;

use Religion::Bible::Verses::Backend;
use Religion::Bible::Verses::Search::Query;

has __backend => (is => 'ro', isa => 'Religion::Bible::Verses::Backend', lazy => 1, default => \&__makeBackend);

has bookCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeBookCount);

has books => (is => 'ro', isa => 'ArrayRef[Religion::Bible::Verses::Book]', lazy => 1, default => \&__makeBooks);

sub BUILD {
}

sub getBookByShortName {
	my ($self, $shortName) = @_;

	foreach my $book (@{ $self->books }) {
		next if ($book->shortName ne $shortName);
		return $book;
	}

	die("Short book name '$shortName' is not a book in the bible");
}

sub getBookByLongName {
	my ($self, $longName) = @_;

	foreach my $book (@{ $self->books }) {
		next if ($book->longName ne $longName);
		return $book;
	}

	die("Long book name '$longName' is not a book in the bible");
}

sub getBookByOrdinal {
	my ($self, $ordinal) = @_;

	if ($ordinal > $self->bookCount) {
		die(sprintf('Book ordinal %d out of range, there are %d books in the bible',
		    $ordinal, $self->bookCount));
	}

	return $self->books->[$ordinal - 1];
}

sub newSearchQuery {
	my ($self, @args) = @_;

	my %defaults = ( _library => $self );

	return Religion::Bible::Verses::Search::Query->new({ %defaults, text => $args[0] })
	    if (scalar(@args) == 1);

	my %params = @args;
	return Religion::Bible::Verses::Search::Query->new({ %defaults, %params });
}

sub __makeBackend {
	my ($self) = @_;
	return Religion::Bible::Verses::Backend->new({
		_library => $self,
	});
}

sub __makeBookCount {
	my ($self) = @_;
	return scalar(@{ $self->books });
}

sub __makeBooks {
	my ($self) = @_;
	return $self->__backend->getBooks();
}

1;
