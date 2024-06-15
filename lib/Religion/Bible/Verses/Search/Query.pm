package Religion::Bible::Verses::Search::Query;
use strict;
use warnings;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Religion::Bible::Verses::Search::Results;

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has limit => (is => 'rw', isa => 'Int', default => 25);

has testament => (is => 'ro', isa => enum(['old', 'new']), required => 0);

has bookShortName => (is => 'ro', isa => 'Str', required => 0);

has text => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
}

sub setLimit {
	my ($self, $limit) = @_;
	$self->limit($limit);
	return $self;
}

sub run {
	my ($self) = @_;

	my @booksToQuery = ( );
	if ($self->bookShortName) {
		$booksToQuery[0] = $self->_library->getBookByShortName($self->bookShortName);
	} else {
		@booksToQuery = @{ $self->_library->books };
	}

	my @verses = ( );
	foreach my $book (@booksToQuery) {
		next if ($self->testament && $self->testament ne $book->testament);
		my $bookVerses = $book->searchText($self->text);
		push(@verses, @$bookVerses);
	}

	return Religion::Bible::Verses::Search::Results->new({
		coun   => scalar(@verses),
		verses => \@verses,
	});
}

sub toString {
	return 'TODO';
}

1;
