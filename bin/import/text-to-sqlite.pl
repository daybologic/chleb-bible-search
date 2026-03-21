#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (2E0EOL),
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

use DBI;
use Data::Dumper;
use English qw(-no_match_vars);
use IO::File;
use JSON;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use Storable qw(nstore);

Readonly my $OT_COUNT => 39;

Readonly my $DATA_DIR   => 'data';
Readonly my $BOOK_INPUT => 'static/kjv.cvs';

Readonly my $FILE_SIG     => '178d4220-2531-11f1-8c59-ab2e7e0be878';
Readonly my $FILE_VERSION => 13;

my $offsetMaster = -1;
Readonly my $MAIN_OFFSET_SIG     => ++$offsetMaster; # string
Readonly my $MAIN_OFFSET_VERSION => ++$offsetMaster; # int
Readonly my $MAIN_OFFSET_BOOKS   => ++$offsetMaster; # array, see $BOOK_*
Readonly my $MAIN_OFFSET_VERSES  => ++$offsetMaster; # global array of verses to key names
Readonly my $MAIN_OFFSET_DATA    => ++$offsetMaster; # main verse map
Readonly my $MAIN_OFFSET_EMOTION => ++$offsetMaster; # global array of verses to emotion
Readonly my $MAIN_OFFSET_TONES   => ++$offsetMaster; # global array of verses to tone lists
Readonly my $MAIN_OFFSET_VERSE_KEYS_TO_ABSOLUTE_ORDINALS => ++$offsetMaster; # verse keys back to absolute positions in the bible (1 - 31,102+)

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

sub __emotionFromTranslation {
	my ($translation) = @_;
	return join('/', 'static', 'emotion', sprintf('%s.json', $translation));
}

sub __outputFromTranslation {
	my ($translation) = @_;
	return join('/', $DATA_DIR, sprintf('%s.bin', $translation));
}

sub __createTables {
	my ($dbh) = @_;

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS master (
	sig CHAR(36) NOT NULL,
	version INTEGER NOT NULL,
	built DATETIME NOT NULL
)
SQL

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS translation (
	code CHAR(8) PRIMARY KEY,
	year INTEGER NOT NULL,
	language CHAR(2) NOT NULL
)
SQL

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS book (
	id CHAR(36) PRIMARY KEY,
	code CHAR(8) NOT NULL,
	translation_code CHAR(8) NOT NULL,
	ordinal INTEGER NOT NULL
)
SQL

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS chapter (
	id CHAR(36) PRIMARY KEY,
	translation_code CHAR(8) NOT NULL,
	book_code CHAR(8) NOT NULL,
	ordinal INTEGER NOT NULL
)
SQL

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS verse (
	id CHAR(36) PRIMARY KEY,
	chapter_id CHAR(36) NOT NULL,
	ordinal INTEGER NOT NULL,
	text TEXT NOT NULL
)
SQL

	return;
}

sub __writeMaster {
	my ($dbh) = @_;

my $sth = $dbh->prepare(<<'SQL');
		INSERT INTO master (sig, version, built)
		VALUES(?, ?, ?)
SQL

		$sth->execute($FILE_SIG, $FILE_VERSION, 'NOW()'); # FIXME, 'NOW()' is verbatim.  Look up proper idiom
		$dbh->commit();

	return;
}

sub main2 {
	my ($translation) = @ARGV;
	my $dbFile = "${translation}.sqlite";

	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=$dbFile",
		q{},
		q{},
		{
			RaiseError => 1,
			AutoCommit => 0,
		}
	);

	__createTables($dbh);
	__writeMaster($dbh);

my $sth = $dbh->prepare(<<'SQL');
	INSERT INTO translation (code, year, language)
	VALUES(?, ?, ?)
SQL
	$sth->execute($translation, 1066, 'en');
	$dbh->commit();

$sth = $dbh->prepare(<<'SQL');
	INSERT INTO book (code, translation_code)
	VALUES(?, ?)
SQL
	$sth->execute('Gen', $translation);

$sth = $dbh->prepare(<<'SQL');
	INSERT INTO chapter (id, book_id, ordinal)
	VALUES(?, ?, ?)
SQL
	$sth->execute('f9f8dece-253d-11f1-a839-ffa8ae726ac3', '01e9ca62-253e-11f1-a83a-174fbcaa35a9', 1);

$sth = $dbh->prepare(<<'SQL');
	INSERT INTO verse (translation_code, book, chapter, ordinal, text)
	VALUES(?, ?, ?, ?, ?)
SQL

	# 1 -- FIMXE: shall be book_id
	$sth->execute($translation, 1, 3, 16, 'For God so loved the world...');
	$sth->execute($translation, 1, 1, 1, 'In the beginning God created the heaven and the earth.');
	$sth->execute($translation, 1, 23, 1, 'The LORD is my shepherd; I shall not want.');

	print "Database '$dbFile' is ready, and sample verses have been inserted.\n";

	$sth->finish();
	$dbh->commit();
	$dbh->disconnect();

	exit 0;
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

	my $sentiment = getSentiment($translation);

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
					$data->[$MAIN_OFFSET_VERSE_KEYS_TO_ABSOLUTE_ORDINALS]->{$verseKey} = $verseOrdinalRelativeBible;
					$data->[$MAIN_OFFSET_EMOTION]->[$verseOrdinalRelativeBible] = $sentiment->[$verseOrdinalRelativeBible - 1]->{emotion};
					$data->[$MAIN_OFFSET_TONES]->[$verseOrdinalRelativeBible] = $sentiment->[$verseOrdinalRelativeBible - 1]->{tones};
				}

				# if the chapter ordinal is out of range, the first verse of that chapter won't exist
				my $firstVerseKey = join(':', $translation, $bookShortName, $chapterOrdinal, 1);
				last CHAPTER unless ($data->[$MAIN_OFFSET_DATA]->{$firstVerseKey});
			}
		}

	}

	return writeOutput($data, $translation);
}

sub getSentiment {
	my ($translation) = @_;

	my $text;
	if (my $fh = IO::File->new(join('/', $DATA_DIR, __emotionFromTranslation($translation)), 'r')) {
		$text = do { local $/; <$fh> };
		$fh = undef;
	}

	my $data = decode_json($text);
	die("Sentiment data for $translation is incomplete") unless ($data && ref($data) eq 'ARRAY' && scalar(@$data) == 31_102);

	return $data;
}

exit(main2()) unless (caller());
