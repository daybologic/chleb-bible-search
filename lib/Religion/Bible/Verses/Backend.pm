package Religion::Bible::Verses::Backend;
use strict;
use warnings;
use Data::Dumper;
use English qw(-no_match_vars);
use IO::File;
use List::Util qw(sum);
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use Religion::Bible::Verses::Book;
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

#has __file => (is => 'rw', isa => 'IO::File', lazy => 1, default => \&__makeFile);

has path => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makePath);

has data => (is => 'ro', isa => 'ArrayRef', lazy => 1, default => \&__makeData);

sub __makePath {
#	my ($self) = @_;
	return join('/', $DATA_DIR, $BIBLE);
}

#sub __makeFile {
#	my ($self) = @_;
#	return retrieve($self->path);
#}

sub __makeData {
	my ($self) = @_;
	return retrieve($self->path);
}

sub BUILD {
	my ($self) = @_;
	Dumper $self->data;

	if ($self->__fsck() != EXIT_SUCCESS) {
		die(sprintf("'%s' is corrupt", $self->path));
	}

	return;
}

sub getBooks { # returns ARRAY of Religion::Bible::Verses::Book
	my ($self) = @_;

	my @books = ( );
	my $bookCount = scalar(@{ $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES] });
	#die Dumper $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES];
	for (my $bookIndex = 0; $bookIndex < $bookCount; $bookIndex++) {
		my $shortName = $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES]->[$bookIndex];
		my $bookInfo = $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$shortName};
		my $bookOrdinal = $bookIndex + 1;
		$books[$bookIndex] = Religion::Bible::Verses::Book->new({
			ordinal    => $bookOrdinal,
			shortName  => $shortName,
			longName   => $bookInfo->{n},
			chapterCount => $bookInfo->{c},
			verseCount => sum(values(%{ $bookInfo->{v} })),
			testament  => ($bookInfo->{t} eq 'O') ? 'old' : 'new',
		});
	}

	return \@books;
}

sub __fsck {
	my ($self) = @_;
	return EXIT_FAILURE if ($self->__validateSig());
	return EXIT_FAILURE if ($self->__validateVersion());
	return EXIT_SUCCESS;
}

sub __validateSig {
	my ($self) = @_;
	my $sig = $self->data->[$MAIN_OFFSET_SIG];
	return EXIT_SUCCESS if (defined($sig) && $sig eq $FILE_SIG);
	return EXIT_FAILURE;
}

sub __validateVersion {
	my ($self) = @_;
	my $version = $self->data->[$MAIN_OFFSET_VERSION];
	# Until we reach version 1.0.0 of the package (stable release), we only accept the exact correct version of the file!
	# this gives us more flexibility to make changes.
	return EXIT_SUCCESS if (defined($version) && length($version) <= 5 && $version =~ m/^\d+$/ && $version == $FILE_VERSION);
	return EXIT_FAILURE;
}

1;
