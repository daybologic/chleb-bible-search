#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the project nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

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
Readonly my $BOOK_INPUT => 'static/kjv.cvs';

Readonly my $FILE_SIG     => '3aa67e06-237c-11ef-8c58-f73e3250b3f3';
Readonly my $FILE_VERSION => 10;

my $offsetMaster = -1;
Readonly my $MAIN_OFFSET_SIG     => ++$offsetMaster; # string
Readonly my $MAIN_OFFSET_VERSION => ++$offsetMaster; # int
Readonly my $MAIN_OFFSET_BOOKS   => ++$offsetMaster; # array, see $BOOK_*
Readonly my $MAIN_OFFSET_VERSES  => ++$offsetMaster; # global array of verses to key names
Readonly my $MAIN_OFFSET_DATA    => ++$offsetMaster; # main verse map

$offsetMaster = -1;
Readonly my $BOOK_OFFSET_SHORT_NAMES    => ++$offsetMaster; # array of book names in canon order
Readonly my $BOOK_OFFSET_BOOK_INFO      => ++$offsetMaster; # hash of book info keyed by short book name
Readonly my $BOOK_OFFSET_VERSES_TO_KEYS => ++$offsetMaster; # Relative book verse offsets to keys ($MAIN_OFFSET_DATA) ie. 'Gen:1533' -> 'Gen:50:26'

# nb. book info structure is as follows:
# c - chapterCount
# n - bookLongName
# t - testamentEnum ('N', 'O')
# v - verse count map (keys are the chapter number, there is no zero, and values are the verse counts)

sub writeOutput {
	my ($data, $translation) = @_;

	eval {
		nstore($data, __outputFromTranslation($translation));
	};

	if (my $evalError = $EVAL_ERROR) {
		print("Error writing to file: $evalError");
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}

sub __inputFromTranslation {
	my ($translation) = @_;
	return join('/', 'static', sprintf('%s.txt', $translation));
}

sub __outputFromTranslation {
	my ($translation) = @_;
	return join('/', $DATA_DIR, sprintf('%s.bin', $translation));
}

sub main {
	my ($translation) = @ARGV;
	my $data = [ ];

	unless ($translation) {
		printf(STDERR "You must specify the translation!\n");
		return EXIT_FAILURE;
	}

	$data->[$MAIN_OFFSET_SIG] = $FILE_SIG;
	$data->[$MAIN_OFFSET_VERSION] = $FILE_VERSION;

	my @bookShortNames;
	my %bookNameMap = ( );
	my $bookIndex = -1;
	my %bookShortNameToOrdinal = ( );
	my $fileName = join('/', $DATA_DIR, $BOOK_INPUT);
	if (my $fh = IO::File->new($fileName, 'r')) {
		while (my $line = <$fh>) {
			my @bookData = split(m/;/, $line);
			my ($bookShortName, undef, $bookLongName) = @bookData;
			$bookNameMap{$bookShortName} = $bookLongName;
			$bookShortNames[++$bookIndex] = $bookShortName;
			$bookShortNameToOrdinal{$bookShortName} = $bookIndex + 1;
		}
		undef($fh);
	} else {
		die(sprintf("Failed to open '%s' -- %s", $fileName, $ERRNO));
	}

	$data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES] = \@bookShortNames;

	if (my $fh = IO::File->new(join('/', $DATA_DIR, __inputFromTranslation($translation)), 'r')) {
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

		my $verseOrdinalRelativeBible = 0;
		BOOK: foreach my $bookShortName (@bookShortNames) {
			my $verseOrdinalRelativeBook = 0;
			CHAPTER: for (my $chapterOrdinal = 1; $chapterOrdinal > 0; $chapterOrdinal++) {
				VERSE: for (my $verseOrdinal = 1; $verseOrdinal > 0; $verseOrdinal++) {
					my $verseKey = join(':', $translation, $bookShortName, $chapterOrdinal, $verseOrdinal);
					last VERSE unless ($data->[$MAIN_OFFSET_DATA]->{$verseKey});
					my $verseKeyRelativeBook = join(':', $translation, $bookShortName, ++$verseOrdinalRelativeBook);
					$data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_VERSES_TO_KEYS]->{$verseKeyRelativeBook} = $verseKey;
					$data->[$MAIN_OFFSET_VERSES]->[++$verseOrdinalRelativeBible] = $verseKey;
				}

				# if the chapter ordinal is out of range, the first verse of that chapter won't exist
				my $firstVerseKey = join(':', $translation, $bookShortName, $chapterOrdinal, 1);
				last CHAPTER unless ($data->[$MAIN_OFFSET_DATA]->{$firstVerseKey});
			}
		}

	}

	return writeOutput($data, $translation);
}

exit(main()) unless (caller());
