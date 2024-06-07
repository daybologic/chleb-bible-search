package Religion::Bible::Verses::Backend;
use strict;
use warnings;
use Data::Dumper;
use English qw(-no_match_vars);
use IO::File;
use Moose;
use Readonly;
use Storable;

Readonly my $DATA_DIR => 'data';
Readonly my $BIBLE    => 'kjv.bin';

Readonly my $FILE_SIG     => '3aa67e06-237c-11ef-8c58-f73e3250b3f3';
Readonly my $FILE_VERSION => 1;

my $offsetMaster = -1;
Readonly my $MAIN_OFFSET_SIG     => ++$offsetMaster; # string
Readonly my $MAIN_OFFSET_VERSION => ++$offsetMaster; # int
Readonly my $MAIN_OFFSET_BOOKS   => ++$offsetMaster; # array, see $BOOK_*
Readonly my $MAIN_OFFSET_DATA    => ++$offsetMaster; # main verse map

$offsetMaster = -1;
Readonly my $BOOK_OFFSET_SHORT_NAMES => ++$offsetMaster; # array of book names in canon order
Readonly my $BOOK_OFFSET_BOOK_INFO   => ++$offsetMaster; # hash of book info keyed by short book name

# nb. book info structure is as follows:
# c - chapterCount
# n - bookLongName
# t - testamentEnum ('N', 'O')
# v - verse count map (keys are the chapter number, there is no zero, and values are the verse counts)

has path => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makePath);

has file => (is => 'rw', isa => 'IO::File', lazy => 1, default => \&__makeFile);

sub __makePath {
#	my ($self) = @_;
	return join('/', $DATA_DIR, $BIBLE);
}

sub __makeFile {
	my ($self) = @_;
	return retrieve($self->path);
}

sub BUILD {
	my ($self) = @_;
	return Dumper $self->file;
}

1;
