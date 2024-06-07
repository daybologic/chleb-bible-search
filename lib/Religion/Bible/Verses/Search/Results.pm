package Religion::Bible::Verses::Search::Results;
use strict;
use warnings;
use Moose;

has count => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeCount);

has verses => (is => 'ro', isa => 'ArrayRef[Religion::Bible::Verses::Verse]', required => 1);

sub BUILD {
}

sub __makeCount {
	my ($self) = @_;
	return scalar(@{ $self->verses });
}

1;
