package Religion::Bible::Verses;
use strict;
use warnings;
use Data::Dumper;
use Moose;

use Religion::Bible::Verses::Backend;
use Religion::Bible::Verses::Search::Query;

has __backend => (is => 'ro', isa => 'Religion::Bible::Verses::Backend', lazy => 1, default => \&__makeBackend);

has bookCount => (is => 'ro', isa => 'Int');

sub BUILD {
}

sub getBookByShortName {
	my ($self, $shortName) = @_;

	die Dumper $self->__backend->getBooks();
	return $self->getBookByOrdinal(1) if ($shortName eq 'Gen');
	return $self->getBookByOrdinal(39 + 4) if ($shortName eq 'John');
	return $self->getBookByOrdinal(73) if ($shortName eq 'Rev');

	return 0;
}

sub getBookByLongName {
	my ($self, $longName) = @_;

	return $self->getBookByOrdinal(1) if ($longName eq 'Genesis');
	return $self->getBookByOrdinal(39 + 4) if ($longName eq 'John');

	return 0;
}

sub getBookByOrdinal {
	my ($self, $ordinal) = @_;
	die $ordinal;
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
	});
}

1;
