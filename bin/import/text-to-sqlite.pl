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
use English qw(-no_match_vars);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use JSON;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;

Readonly my $OT_COUNT => 39;

Readonly my $DATA_DIR => 'data';

Readonly my $FILE_SIG     => '178d4220-2531-11f1-8c59-ab2e7e0be878';
Readonly my $FILE_VERSION => 13;

Readonly my %TRANSLATION_META => (
	kjv => { year => 1611, language => 'en' },
	asv => { year => 1901, language => 'en' },
);

Readonly my %BOOK_ORDINAL => (
	Gen   => 1,
	Exo   => 2,
	Lev   => 3,
	Num   => 4,
	Deu   => 5,
	Josh  => 6,
	Judg  => 7,
	Ruth  => 8,
	'1Sam' => 9,
	'2Sam' => 10,
	'1Ki'  => 11,
	'2Ki'  => 12,
	'1Chr' => 13,
	'2Chr' => 14,
	Ezra  => 15,
	Neh   => 16,
	Est   => 17,
	Job   => 18,
	Psa   => 19,
	Prov  => 20,
	Eccl  => 21,
	Song  => 22,
	Isa   => 23,
	Jer   => 24,
	Lam   => 25,
	Ezek  => 26,
	Dan   => 27,
	Hosea => 28,
	Joel  => 29,
	Amos  => 30,
	Oba   => 31,
	Jonah => 32,
	Micah => 33,
	Nahum => 34,
	Hab   => 35,
	Zep   => 36,
	Hag   => 37,
	Zec   => 38,
	Mal   => 39,
	Mat   => 40,
	Mark  => 41,
	Luke  => 42,
	John  => 43,
	Acts  => 44,
	Rom   => 45,
	'1Cor' => 46,
	'2Cor' => 47,
	Gal   => 48,
	Eph   => 49,
	Phil  => 50,
	Col   => 51,
	'1Th'  => 52,
	'2Th'  => 53,
	'1Tim' => 54,
	'2Tim' => 55,
	Titus => 56,
	Phile => 57,
	Heb   => 58,
	James => 59,
	'1Pet' => 60,
	'2Pet' => 61,
	'1John' => 62,
	'2John' => 63,
	'3John' => 64,
	Jude  => 65,
	Rev   => 66,
);

my %bookKeys = ( );
my %chapterKeys = ( );

sub __inputFromTranslation {
	my ($translation) = @_;
	return join('/', 'static', sprintf('%s.txt', $translation));
}

sub __emotionFromTranslation {
	my ($translation) = @_;
	return join('/', 'static', 'emotion', sprintf('%s.json', $translation));
}

sub __createTables {
	my ($dbh) = @_;

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS master (
	sig CHAR(36) NOT NULL,
	version INTEGER NOT NULL,
	built_time TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
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
	id INTEGER PRIMARY KEY,
	code CHAR(8) NOT NULL,
	translation CHAR(8) NOT NULL,
	testament CHAR(1) NOT NULL CHECK (testament IN ('O', 'N')),
	ordinal INTEGER NOT NULL,
	chapter_count INTEGER NOT NULL,
	FOREIGN KEY (translation) REFERENCES translation(code),
	UNIQUE (translation, code)
)
SQL

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS chapter (
	id INTEGER PRIMARY KEY,
	book_id INTEGER NOT NULL,
	translation CHAR(8) NOT NULL,
	book_code CHAR(8) NOT NULL,
	ordinal INTEGER NOT NULL,
	verse_count INTEGER NOT NULL,
	FOREIGN KEY (book_id) REFERENCES book(id),
	FOREIGN KEY (translation) REFERENCES translation(code),
	UNIQUE (book_id, ordinal)
)
SQL

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS verse (
	id INTEGER PRIMARY KEY,
	book_id INTEGER NOT NULL,
	chapter_id INTEGER NOT NULL,
	ordinal_relative_to_book INTEGER NOT NULL,
	ordinal_relative_to_chapter INTEGER NOT NULL,
	text TEXT NOT NULL,
	FOREIGN KEY (book_id) REFERENCES book(id),
	FOREIGN KEY (chapter_id) REFERENCES chapter(id),
	UNIQUE (chapter_id, ordinal_relative_to_chapter)
)
SQL

	return;
}

sub __createIndexes {
	my ($fileHandle) = @_;

	# The UNIQUE constraints above already index book(translation, code),
	# chapter(book_id, ordinal) and verse(chapter_id, ordinal_relative_to_chapter);
	# these cover the remaining hot lookups.
	$fileHandle->do('CREATE INDEX IF NOT EXISTS idx_verse_book ON verse(book_id, ordinal_relative_to_book)');
	$fileHandle->do('CREATE INDEX IF NOT EXISTS idx_book_trans ON book(translation, ordinal)');

	$fileHandle->commit();

	return;
}

sub __populateCounts {
	my ($fileHandle) = @_;

	# ordinal_relative_to_book: number each verse sequentially within its book,
	# in canonical order (by chapter ordinal, then verse ordinal).
	$fileHandle->do(<<'SQL');
		UPDATE verse SET ordinal_relative_to_book = ranked.seq
		FROM (
			SELECT v.id AS vid,
			       ROW_NUMBER() OVER (
			           PARTITION BY v.book_id
			           ORDER BY c.ordinal, v.ordinal_relative_to_chapter
			       ) AS seq
			FROM verse v
			JOIN chapter c ON c.id = v.chapter_id
		) AS ranked
		WHERE verse.id = ranked.vid
SQL

	$fileHandle->do(<<'SQL');
		UPDATE chapter SET verse_count =
			(SELECT COUNT(*) FROM verse WHERE verse.chapter_id = chapter.id)
SQL

	$fileHandle->do(<<'SQL');
		UPDATE book SET chapter_count =
			(SELECT COUNT(*) FROM chapter WHERE chapter.book_id = book.id)
SQL

	$fileHandle->commit();

	return;
}

sub __writeMaster {
	my ($fileHandle) = @_;

	my $sth = $fileHandle->prepare(<<'SQL');
		INSERT INTO master (sig, version)
		VALUES(?, ?)
SQL

	$sth->execute($FILE_SIG, $FILE_VERSION);
	$fileHandle->commit();

	return;
}

sub __writeTranslations {
	my ($fileHandle, $translations) = @_;

	my $sth = $fileHandle->prepare(<<'SQL');
		INSERT INTO translation (code, year, language)
		VALUES(?, ?, ?)
SQL

	foreach my $translation (@$translations) {
		my $meta = $TRANSLATION_META{$translation}
		    or die("No metadata (year/language) known for translation '$translation'");
		$sth->execute($translation, $meta->{year}, $meta->{language});
	}

	$fileHandle->commit();

	return;
}

my %idCounters = ( );
sub __uuid {
	my ($domain) = @_;

	$idCounters{$domain} = 0 unless(defined($idCounters{$domain}));
	return ++$idCounters{$domain};
}

sub __connect {
	my ($fileName) = @_;
	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=${fileName}",
		q{},
		q{},
		{
			RaiseError => 1,
			AutoCommit => 0,
		}
	);

	# Foreign-key enforcement is off by default in SQLite and is per-connection;
	# it must be enabled before any transaction begins.
	$dbh->{AutoCommit} = 1;
	$dbh->do('PRAGMA foreign_keys = ON');
	$dbh->{AutoCommit} = 0;

	return $dbh;
}

sub __translationFileName {
	my ($translation) = @_;
	return join('/', $DATA_DIR, "${translation}.sqlite");
}

sub main2 {
	my $translation;
	my $name;

	return EXIT_FAILURE unless (GetOptions(
		'translation|t=s' => \$translation,
		'name|n=s' => \$name,
	));

	unless ($translation) {
		printf(STDERR "You must specify the translation!\n");
		return EXIT_FAILURE;
	}

	unless ($name) {
		printf(STDERR "You must specify the name!\n");
		return EXIT_FAILURE;
	}

	my $translationFileName = __translationFileName($name);
	my $fileHandle = __connect($translationFileName);

	%bookKeys = ( );
	%chapterKeys = ( );

	__createTables($fileHandle);
	__writeMaster($fileHandle);

	if ($translation eq 'core') {
		my @translations = ('asv', 'kjv'); # TODO can we make this list dynamic somehow?  all might need to be an even bigger superset, or we might need to tag inputs from dirs
		__writeTranslations($fileHandle, \@translations);
		foreach my $translation2 (@translations) {
			__processVerses($fileHandle, $translation2);
		}
	} else {
		__writeTranslations($fileHandle, [$translation]);
		__processVerses($fileHandle, $translation);
	}

	__populateCounts($fileHandle);
	__createIndexes($fileHandle);

	$fileHandle->disconnect();

	return EXIT_SUCCESS;
}

sub __writeBook {
	my ($fileHandle, $translation, $bookShortName) = @_;

my $sthBook = $fileHandle->prepare(<<'SQL');
	INSERT INTO book (id, code, translation, testament, ordinal, chapter_count)
	VALUES(?, ?, ?, ?, ?, ?)
SQL

	my $bookKey = join(':', $translation, $bookShortName);
	unless ($bookKeys{$bookKey}) {
		my $ordinal = $BOOK_ORDINAL{$bookShortName} or die("Missing ordinal for '$bookShortName'");
		my $testament = $ordinal > $OT_COUNT ? 'N' : 'O';
		my $id = __uuid('book');

		my $chapterCount = 0; # populated after load by __populateCounts()
		$sthBook->execute($id, $bookShortName, $translation, $testament, $ordinal, $chapterCount);
		$bookKeys{$bookKey} = $id;
	}

	return;
}

sub __writeChapter {
	my ($fileHandle, $translation, $bookShortName, $chapterOrdinal) = @_;

my $sthChapter = $fileHandle->prepare(<<'SQL');
	INSERT INTO chapter (id, book_id, translation, book_code, ordinal, verse_count)
	VALUES(?, ?, ?, ?, ?, ?)
SQL

	my $bookKey = join(':', $translation, $bookShortName);
	my $chapterKey = join(':', $bookKey, $chapterOrdinal);
	unless ($chapterKeys{$chapterKey}) {
		my $id = __uuid('chapter');
		my $bookId = $bookKeys{$bookKey};

		my $verseCount = 0; # populated after load by __populateCounts()
		$sthChapter->execute($id, $bookId, $translation, $bookShortName, $chapterOrdinal, $verseCount);
		$chapterKeys{$chapterKey} = $id;
	}

	return;
}

sub __writeVerse {
	my ($fileHandle, $translation, $bookShortName, $chapterOrdinal, $verseNumber, $verseKey, $verseText) = @_;

my $sthVerse = $fileHandle->prepare(<<'SQL');
	INSERT INTO verse (id, book_id, chapter_id, ordinal_relative_to_book, ordinal_relative_to_chapter, text)
	VALUES(?, ?, ?, ?, ?, ?)
SQL

	my $bookKey = join(':', $translation, $bookShortName);
	my $chapterKey = join(':', $bookKey, $chapterOrdinal);
	my $id = __uuid('verse');
	my $bookId = $bookKeys{$bookKey};
	my $chapterId = $chapterKeys{$chapterKey};

	# ordinal_relative_to_chapter is the verse number from the key.
	# ordinal_relative_to_book cannot be a running counter here because the
	# input is ordered lexically by chapter (1, 10, 11, ... 2, 20), not
	# canonically; it is derived after load by __populateCounts().
	$sthVerse->execute($id, $bookId, $chapterId, 0, $verseNumber, $verseText);

	return;
}

sub __processVerses {
	my ($fileHandle, $translation) = @_;

	if (my $fh = IO::File->new(join('/', $DATA_DIR, __inputFromTranslation($translation)), 'r')) {
		while (my $line = <$fh>) {
			my @verseData = split(m/::/, $line, 2);
			my ($verseKey, $verseText) = @verseData;
			my ($translation, $bookShortName, $chapterOrdinal, $verseNumber)
			    = split(m/:/, $verseKey, 4);
			chomp($verseText);

			__writeBook($fileHandle, $translation, $bookShortName);
			__writeChapter($fileHandle, $translation, $bookShortName, $chapterOrdinal);
			__writeVerse($fileHandle, $translation, $bookShortName, $chapterOrdinal, $verseNumber, $verseKey, $verseText);
		}
	}

	$fileHandle->commit();

	return;
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
