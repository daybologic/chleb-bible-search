package Religion::Bible::Verses::Chapter;
use strict;
use warnings;
use Moose;

has book => (is => 'ro', isa => 'Religion::Bible::Verses::Book', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

sub BUILD {
}

1;
