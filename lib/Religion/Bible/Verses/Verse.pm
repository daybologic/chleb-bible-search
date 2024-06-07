package Religion::Bible::Verses::Verse;
use strict;
use warnings;
use Moose;

has book => (is => 'ro', isa => 'Religion::Bible::Verses::Book', required => 1);

has chapter => (is => 'ro', isa => 'Religion::Bible::Verses::Chapter', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

has text => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
}

1;
