#!/usr/bin/env perl

package main;
use strict;
use warnings;

use Data::Dumper;
use English qw(-no_match_vars);
use IO::File;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use Storable qw(nstore);

Readonly my $OT_COUNT => 39;

Readonly my $DATA_DIR   => 'data';
Readonly my $BOOK_INPUT => 'static/kjv/index.cvs';
Readonly my $INPUT      => 'kjv-verses.txt';
Readonly my $OUTPUT     => 'kjv.bin';

Readonly my $FILE_SIG     => '3aa67e06-237c-11ef-8c58-f73e3250b3f3';
Readonly my $FILE_VERSION => 7;

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

sub writeOutput {
	my ($data) = @_;

	eval {
		nstore($data, join('/', $DATA_DIR, $OUTPUT));
	};

	if (my $evalError = $EVAL_ERROR) {
		print "Error writing to file: $evalError" if ($evalError);
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}

sub main {
	my $data = [ ];

	$data->[$MAIN_OFFSET_SIG] = $FILE_SIG;
	$data->[$MAIN_OFFSET_VERSION] = $FILE_VERSION;

	my @bookShortNames;
	my %bookNameMap = ( );
	my $bookIndex = -1;
	my %bookShortNameToOrdinal = ( );
	if (my $fh = IO::File->new(join('/', $DATA_DIR, $BOOK_INPUT), 'r')) {
		while (my $line = <$fh>) {
			my @bookData = split(m/;/, $line);
			my ($bookShortName, undef, $bookLongName) = @bookData;
			$bookNameMap{$bookShortName} = $bookLongName;
			$bookShortNames[++$bookIndex] = $bookShortName;
			$bookShortNameToOrdinal{$bookShortName} = $bookIndex + 1;
		}
		undef($fh);
	}

	$data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES] = \@bookShortNames;

	if (my $fh = IO::File->new(join('/', $DATA_DIR, $INPUT), 'r')) {
		while (my $line = <$fh>) {
			my @verseData = split(m/::/, $line, 2);
			my ($verseKey, $verseText) = @verseData;
			my ($translation, $bookShortName, $chapterNumber, $verseNumber)
			    = split(m/:/, $verseKey, 4);

			# initialization, TODO: Separate function?
			$data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName} = {
				c => 0,
				n => $bookNameMap{$bookShortName},
				t => $bookShortNameToOrdinal{$bookShortName} > $OT_COUNT ? 'N' : 'O',
				v => { },
			} unless ($data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName});

			$data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName}->{c} = $chapterNumber
			    if ($data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName}->{c} < $chapterNumber);

			$data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName}->{v}->{$chapterNumber} = 0
			    unless (exists($data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName}->{v}->{$chapterNumber}));

			$data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName}->{v}->{$chapterNumber} = $verseNumber
			    if ($data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$bookShortName}->{v}->{$chapterNumber} < $verseNumber);

			chomp($verseText);
			$data->[$MAIN_OFFSET_DATA]->{$verseKey} = $verseText;
		}
		undef($fh);
	}

	return writeOutput($data);
}

exit(main()) unless (caller());
