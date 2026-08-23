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

use Carp qw(croak);
use DBI;
use English qw(-no_match_vars);
use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use JSON;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use YAML::XS qw(LoadFile);

Readonly my $DATA_DIR => 'data';
Readonly my $SPINE_FILE => join('/', $DATA_DIR, 'static', 'spine.yaml');

Readonly my $FILE_SIG     => '178d4220-2531-11f1-8c59-ab2e7e0be878';
Readonly my $FILE_VERSION => 17;

Readonly my %TRANSLATION_META => (
	kjv       => { year => 1611, language => 'en', properties => {} },
	asv       => { year => 1901, language => 'en', properties => {} },
	dr        => { year => 1610, language => 'en', properties => {} },
	pickthall => { year => 1930, language => 'en', properties => { chapter_name => 'Surah', chapter_name_plural => 'Surahs' } },
);

my %TRANSLATION_BOOK_CODE = ( );
my %TRANSLATION_BOOK_META = ( );

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

=item C<__canonicalBookCode($translation, $bookShortName)>

Return the canonical book code used by the database for a translation input
book code.

=cut

sub __canonicalBookCode {
	my ($translation, $bookShortName) = @_;
	return ($TRANSLATION_BOOK_CODE{$translation} // {})->{$bookShortName} // $bookShortName;
}

=item C<__spineBookMetadata($bookId, $translation, $metadata, $testament)>

Validate and normalize one translation's book metadata from the spine.

=cut

sub __spineBookMetadata {
	my ($bookId, $translation, $metadata, $testament) = @_;
	my $ordinal = $metadata->{ordinal};
	croak("Spine book '$bookId' has no ordinal for '$translation'")
	    unless (defined($ordinal) && $ordinal =~ m/\A[0-9]+\z/x);
	croak("Spine book '$bookId' has no testament")
	    unless (defined($testament) && $testament =~ m/\A(?:old|new)\z/x);
	my $bookMetadata = {
		ordinal => $ordinal,
		testament => $testament eq 'new' ? 'N' : 'O',
		shortName => $metadata->{short_name},
		shortNameRaw => $metadata->{short_name_raw},
		longName => $metadata->{long_name},
	};
	croak("Spine book '$bookId' has incomplete names for '$translation'")
	    unless (defined($bookMetadata->{shortName})
		&& defined($bookMetadata->{shortNameRaw})
		&& defined($bookMetadata->{longName}));
	return $bookMetadata;
}

=item C<__loadSpineBookCodes()>

Load source-to-canonical book-code mappings from C<spine.yaml>.

=cut

sub __loadSpineBookCodes {
	my $spine = LoadFile($SPINE_FILE);
	croak("Spine file '$SPINE_FILE' does not contain a books array")
	    unless (ref($spine) eq 'HASH' && ref($spine->{books}) eq 'ARRAY');

	%TRANSLATION_BOOK_CODE = ( );
	%TRANSLATION_BOOK_META = ( );
	foreach my $book (@{ $spine->{books} }) {
		my $bookId = $book->{book_id} // '';
		croak("Spine book is missing book_id") if (length($bookId) == 0);

		my $translations = $book->{translations};
		croak("Spine book '$bookId' is missing translations") unless (ref($translations) eq 'HASH');

		my $canonicalCode = $bookId;

		foreach my $translation (keys(%$translations)) {
			my $metadata = $translations->{$translation};
			next if (ref($metadata) ne 'HASH' || $metadata->{absent});
			my $sourceCode = $metadata->{short_name_raw};
			croak("Spine book '$bookId' has no source code for '$translation'")
			if (!defined($sourceCode) || length($sourceCode) == 0);
			if (exists($TRANSLATION_BOOK_CODE{$translation}->{$sourceCode})
			    && $TRANSLATION_BOOK_CODE{$translation}->{$sourceCode} ne $canonicalCode) {
				croak("Spine maps '$translation:$sourceCode' to multiple canonical books");
			}
			$TRANSLATION_BOOK_CODE{$translation}->{$sourceCode} = $canonicalCode;
			my $bookMetadata = __spineBookMetadata($bookId, $translation, $metadata, $book->{testament});
			$TRANSLATION_BOOK_META{$translation}->{$canonicalCode} = $bookMetadata;
		}
	}

	return;
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
CREATE TABLE IF NOT EXISTS properties (
	translation CHAR(8) NOT NULL,
	name TEXT NOT NULL,
	value TEXT NOT NULL,
	PRIMARY KEY (translation, name),
	FOREIGN KEY (translation) REFERENCES translation(code)
)
SQL

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS book (
	id INTEGER PRIMARY KEY,
	code CHAR(8) NOT NULL,
	short_name CHAR(8) NOT NULL,
	short_name_raw CHAR(8) NOT NULL,
	long_name TEXT NOT NULL,
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

	$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS sentiment (
	verse_id INTEGER NOT NULL,
	sentiment TEXT NOT NULL,
	kind TEXT NOT NULL CHECK (kind IN ('emotion', 'tone')),
	PRIMARY KEY (verse_id, kind, sentiment),
	FOREIGN KEY (verse_id) REFERENCES verse(id)
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
	$fileHandle->do('CREATE INDEX IF NOT EXISTS idx_sentiment_kind_value ON sentiment(kind, sentiment)');
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
		    or croak("No metadata (year/language) known for translation '$translation'");
		$sth->execute($translation, $meta->{year}, $meta->{language});
	}

	$fileHandle->commit();

	return;
}

sub __writeProperties {
	my ($fileHandle, $translations) = @_;

	my $sth = $fileHandle->prepare(<<'SQL');
		INSERT INTO properties (translation, name, value)
		VALUES(?, ?, ?)
SQL

	foreach my $translation (@$translations) {
		my $meta = $TRANSLATION_META{$translation}
		    or croak("No metadata (year/language) known for translation '$translation'");
		foreach my $name (keys(%{ $meta->{properties} // {} })) {
			$sth->execute($translation, $name, $meta->{properties}->{$name});
		}
	}

	$fileHandle->commit();

	return;
}

sub __writeSentiment {
	my ($fileHandle, $translation) = @_;

	my $sentiment = getSentiment($translation);
	my $verseRows = $fileHandle->selectall_arrayref(<<'SQL', { Slice => {} }, $translation);
		SELECT verse.id
		  FROM verse
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		 ORDER BY book.ordinal, chapter.ordinal, verse.ordinal_relative_to_chapter
SQL
	croak("Sentiment data for $translation does not match the verse data\n")
	    unless (scalar(@{ $sentiment }) == scalar(@{ $verseRows }));

	my $sth = $fileHandle->prepare(<<'SQL');
		INSERT INTO sentiment (verse_id, sentiment, kind)
		VALUES(?, ?, ?)
SQL

	for (my $i = 0; $i < scalar(@{ $sentiment }); $i++) {
		my $entry = $sentiment->[$i];
		my $emotion = $entry->{emotion} // 'neutral';
		$sth->execute($verseRows->[$i]->{id}, $emotion, 'emotion');
		foreach my $tone (@{ $entry->{tones} // [ ] }) {
			$sth->execute($verseRows->[$i]->{id}, $tone, 'tone');
		}
	}

	$fileHandle->commit();

	return;
}

=item C<__verseCountFromTranslation($translation)>

Return the number of verse records in the translation's input file.

=cut

sub __verseCountFromTranslation {
	my ($translation) = @_;

	my $fileName = join('/', $DATA_DIR, __inputFromTranslation($translation));
	my $fh = IO::File->new($fileName, 'r')
	    or croak(sprintf("Failed to open '%s' -- %s", $fileName, $ERRNO));

	my $verseCount = 0;
	$verseCount++ while (<$fh>);
	$fh->close();

	return $verseCount;
}

my %idCounters = ( );
sub __uuid {
	my ($domain) = @_;

	$idCounters{$domain} = 0 unless(defined($idCounters{$domain}));
	return ++$idCounters{$domain};
}

sub __connect {
	my ($fileName) = @_;
	unlink($fileName);
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

	__loadSpineBookCodes();

	my $translationFileName = __translationFileName($name);
	my $fileHandle = __connect($translationFileName);

	%bookKeys = ( );
	%chapterKeys = ( );

	__createTables($fileHandle);
	__writeMaster($fileHandle);

	if ($translation eq 'free') {
		my @translations = ('asv', 'kjv', 'dr');
		__writeTranslations($fileHandle, \@translations);
		__writeProperties($fileHandle, \@translations);
		foreach my $translation2 (@translations) {
			__processVerses($fileHandle, $translation2);
			__writeSentiment($fileHandle, $translation2);
		}
	} else {
		__writeTranslations($fileHandle, [$translation]);
		__writeProperties($fileHandle, [$translation]);
	__processVerses($fileHandle, $translation);
	__writeSentiment($fileHandle, $translation);
	}

	__populateCounts($fileHandle);
	__createIndexes($fileHandle);

	$fileHandle->disconnect();

	return EXIT_SUCCESS;
}

sub __writeBook {
	my ($fileHandle, $translation, $bookShortName) = @_;

my $sthBook = $fileHandle->prepare(<<'SQL');
	INSERT INTO book (id, code, short_name, short_name_raw, long_name, translation, testament, ordinal, chapter_count)
	VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
SQL

	my $bookKey = join(':', $translation, $bookShortName);
	unless ($bookKeys{$bookKey}) {
		my $metadata = ($TRANSLATION_BOOK_META{$translation} // {})->{$bookShortName}
		    // croak("Missing spine metadata for '$bookShortName' in translation '$translation'");
		my $ordinal = $metadata->{ordinal};
		my $testament = $metadata->{testament};
		my $id = __uuid('book');

		my $chapterCount = 0; # populated after load by __populateCounts()
		$sthBook->execute($id, $bookShortName, $metadata->{shortName}, $metadata->{shortNameRaw},
		    $metadata->{longName}, $translation, $testament, $ordinal, $chapterCount);
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
	my ($fileHandle, $args) = @_;
	my ($translation, $bookShortName, $chapterOrdinal, $verseNumber, $verseText) =
	    @{$args}{qw(translation bookShortName chapterOrdinal verseNumber verseText)};

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
			my @verseData = split(m{ :: }x, $line, 2);
			my ($verseKey, $verseText) = @verseData;
			my ($lineTranslation, $bookShortName, $chapterOrdinal, $verseNumber)
			    = split(m{ : }x, $verseKey, 4);
			$bookShortName = __canonicalBookCode($lineTranslation, $bookShortName);
			chomp($verseText);

			__writeBook($fileHandle, $lineTranslation, $bookShortName);
			__writeChapter($fileHandle, $lineTranslation, $bookShortName, $chapterOrdinal);
			__writeVerse($fileHandle, {
				translation    => $lineTranslation,
				bookShortName  => $bookShortName,
				chapterOrdinal => $chapterOrdinal,
				verseNumber    => $verseNumber,
				verseText      => $verseText,
			});
		}
	}

	$fileHandle->commit();

	return;
}

sub getSentiment {
	my ($translation) = @_;

	my $text;
	if (my $fh = IO::File->new(join('/', $DATA_DIR, __emotionFromTranslation($translation)), 'r')) {
		$text = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
		$fh->close() or croak("Cannot close sentiment data for $translation: $ERRNO");
	}

	my $verseCount = __verseCountFromTranslation($translation);
	return [ map { {} } (1 .. $verseCount) ] unless (defined($text));

	my $data = decode_json($text);
	croak("Sentiment data for $translation is incomplete")
	    unless ($data && ref($data) eq 'ARRAY' && scalar(@$data) == $verseCount);

	return $data;
}

exit(main2()) unless (caller());
