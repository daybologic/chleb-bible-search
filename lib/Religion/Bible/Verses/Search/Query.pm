package Religion::Bible::Verses::Search::Query;
use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Religion::Bible::Verses::Search::Results;

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has limit => (is => 'rw', isa => 'Int', default => 25);

has testament => (is => 'ro', isa => enum(['old', 'new']), required => 0);

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
	$self->_library->getBookByShortName('Hag');
	$self->_library->getBookByShortName('Rev');
#	$self->_library->getBookByOrdinal(73);
	return Religion::Bible::Verses::Search::Results->new({
		verses => [],
	});
}

sub toString {
	return 'TODO';
}

1;
