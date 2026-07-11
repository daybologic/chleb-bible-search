# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the Daybo Logic nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package Chleb::Bible::Backend;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use English qw(-no_match_vars);
use IO::File;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use DBI;
use JSON;
use Chleb::Bible::Book;
use Chleb::Type::Testament;

Readonly my $FILE_SIG     => '178d4220-2531-11f1-8c59-ab2e7e0be878';
Readonly my $FILE_VERSION => 13;

Readonly my $OT_COUNT => 39;

my %BOOK_NAMES;
my %SENTIMENT_DATA;

has bible => (is => 'ro', isa => 'Chleb::Bible', required => 1);

has compressedPath => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeCompressedPath);

has data => (is => 'ro', isa => 'Object', lazy => 1, default => \&__makeData);

has cachePath => (is => 'rw', isa => 'Str', lazy => 1, default => \&__makeCachePath);

has dataDir => (is => 'rw', isa => 'Str', lazy => 1, default => \&__makeDataDir);

has cacheDir => (is => 'rw', isa => 'Str', lazy => 1, default => \&__makeCacheDir);

sub __makeCompressedPath {
	my ($self) = @_;
	return join('/', $self->dataDir, $self->__bibleFileName(compressed => 1));
}

sub __makeCachePath {
	my ($self) = @_;

	my $path = join('/', $self->cacheDir, $self->__bibleFileName());
	my $sourceMTime = (stat($self->compressedPath))[9] // 0;
	my $cacheMTime = (stat($path))[9] // 0;
	my $needsRefresh = (!-f $path || $cacheMTime < $sourceMTime);

	if (!$needsRefresh) {
		eval {
			my $dbh = DBI->connect(
				"dbi:SQLite:dbname=${path}",
				q{},
				q{},
				{
					RaiseError => 1,
					AutoCommit => 1,
				}
			);
			my ($badOrdinal) = $dbh->selectrow_array('SELECT 1 FROM verse WHERE ordinal_relative_to_chapter = 0 LIMIT 1');
			$needsRefresh = 1 if ($badOrdinal);
			$dbh->disconnect();
		};
		$needsRefresh = 1 if ($EVAL_ERROR);
	}

	unless (!$needsRefresh) {
		gunzip $self->compressedPath => $path
		   or die("gunzip \"" . $self->compressedPath . "\" failed: $GunzipError\n");
	}

	return $path;
}

sub __makeData {
	my ($self) = @_;

	return DBI->connect(
		"dbi:SQLite:dbname=" . $self->cachePath,
		q{},
		q{},
		{
			RaiseError => 1,
			AutoCommit => 1,
			sqlite_unicode => 1,
		}
	);
}

sub BUILD {
	my ($self) = @_;

	if ($self->__fsck() != EXIT_SUCCESS) {
		die(sprintf("'%s' is corrupt or otherwise cannot be handled", $self->cachePath));
	}

	return;
}

sub getBooks { # returns ARRAY of Chleb::Bible::Book
	my ($self) = @_;

	my @books = ( );
	my $sth = $self->data->prepare(<<'SQL');
		SELECT book.id, book.code, book.translation, book.testament, book.ordinal,
		       book.chapter_count
		  FROM book
		 WHERE book.translation = ?
		 ORDER BY book.ordinal
SQL
	$sth->execute($self->bible->translation);
	my $bookIndex = 0;
	while (my $row = $sth->fetchrow_hashref()) {
		my $shortNameRaw = $row->{code};
		$books[$bookIndex] = Chleb::Bible::Book->new({
			bible      => $self->bible,
			ordinal    => $row->{ordinal} + 0,
			shortNameRaw => $shortNameRaw,
			longName   => $self->__bookLongName($shortNameRaw),
			chapterCount => $row->{chapter_count} + 0,
			verseCount => $self->__bookVerseCount($row->{id}),
			testament => Chleb::Type::Testament->createFromBackendValue($row->{testament}),
		});
		$bookIndex++;
	}

	return \@books;
}

sub getOrdinalByVerseKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m/:/, $key, 4);
	return 0 unless (defined($verseNumber));

	my $sth = $self->data->prepare(<<'SQL');
		WITH ordered_verses AS (
			SELECT
				ROW_NUMBER() OVER (
					ORDER BY book.ordinal, chapter.ordinal, verse.ordinal_relative_to_chapter
				) AS absolute_ordinal,
				book.translation,
				book.code,
				chapter.ordinal AS chapter_ordinal,
				verse.ordinal_relative_to_chapter
			FROM verse
			JOIN book ON book.id = verse.book_id
			JOIN chapter ON chapter.id = verse.chapter_id
		)
		SELECT absolute_ordinal
		  FROM ordered_verses
		 WHERE translation = ?
		   AND code = ?
		   AND chapter_ordinal = ?
		   AND ordinal_relative_to_chapter = ?
SQL
	$sth->execute($translation, $bookShortName, $chapterNumber, $verseNumber);
	my ($ordinal) = $sth->fetchrow_array();
	return $ordinal // 0;
}

sub getVerseKeyByOrdinal {
	my ($self, $ordinal) = @_;
	return if (!defined($ordinal));
	$ordinal = $self->__verseCount() + $ordinal + 1 if ($ordinal < 0);
	return if ($ordinal < 1 || $ordinal > $self->__verseCount());

	my $sth = $self->data->prepare(<<'SQL');
		WITH ordered_verses AS (
			SELECT
				book.translation,
				book.code,
				chapter.ordinal AS chapter_ordinal,
				verse.ordinal_relative_to_chapter
			FROM verse
			JOIN book ON book.id = verse.book_id
			JOIN chapter ON chapter.id = verse.chapter_id
			ORDER BY book.ordinal, chapter.ordinal, verse.ordinal_relative_to_chapter
		)
		SELECT translation, code, chapter_ordinal, ordinal_relative_to_chapter
		  FROM ordered_verses
		LIMIT 1 OFFSET ?
SQL
	$sth->execute($ordinal - 1);
	my $row = $sth->fetchrow_arrayref();
	return unless ($row);
	return join(':', @$row);
}

sub getVerseDataByKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m/:/, $key, 4);
	return unless (defined($verseNumber));

	my $sth = $self->data->prepare(<<'SQL');
		SELECT verse.text
		  FROM verse
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		   AND book.code = ?
		   AND chapter.ordinal = ?
		   AND verse.ordinal_relative_to_chapter = ?
SQL
	$sth->execute($translation, $bookShortName, $chapterNumber, $verseNumber);
	my ($text) = $sth->fetchrow_array();
	return $text;
}

sub getVerseKeyByBookVerseKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $ordinal) = split(m/:/, $key, 3);
	return unless (defined($ordinal));

	my $sth = $self->data->prepare(<<'SQL');
		SELECT book.translation, book.code, chapter.ordinal, verse.ordinal_relative_to_chapter
		  FROM verse
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		   AND book.code = ?
		   AND verse.ordinal_relative_to_book = ?
		 ORDER BY verse.id
		LIMIT 1
SQL
	$sth->execute($translation, $bookShortName, $ordinal);
	my $row = $sth->fetchrow_arrayref();
	return unless ($row);
	return join(':', @$row);
}

sub getBookInfoByShortName {
	my ($self, $shortNameRaw) = @_;
	my $sth = $self->data->prepare(<<'SQL');
		SELECT book.id, book.code, book.testament, book.chapter_count
		  FROM book
		 WHERE book.code = ?
SQL
	$sth->execute($shortNameRaw);
	my $row = $sth->fetchrow_hashref();
	return unless ($row);

	return {
		c => $row->{chapter_count} + 0,
		n => $self->__bookLongName($shortNameRaw),
		t => $row->{testament},
		v => $self->__bookVerseCounts($row->{id}),
	};
}

sub getSentimentByOrdinal {
	my ($self, $ordinal) = @_;

	if (!defined($ordinal)) {
		$self->dic->logger->warn('ordinal undefined! Converted to 0 - fix your code');
		$ordinal = 0;
	}

	$self->dic->logger->warn('sentiment ARRAYs are ordinal-based (starting index 1, not 0)')
	    if ($ordinal == 0);

	my $sentiment = $self->__sentimentByOrdinal($ordinal);
	my $emotion = 'neutral';
	my $tones = [ ];
	if ($sentiment) {
		$emotion = $sentiment->{emotion} if (defined($sentiment->{emotion}));
		$tones = [ sort @{ $sentiment->{tones} } ] if (defined($sentiment->{tones}));
	} else {
		$self->dic->logger->warn("No sentiment entry for verse at ordinal $ordinal");
	}

	return {
		emotion => $emotion,
		tones   => $tones,
	};
}

sub getVerseCount {
	my ($self) = @_;
	my ($count) = $self->data->selectrow_array('SELECT COUNT(*) FROM verse');
	return $count + 0;
}

sub __bookLongName {
	my ($self, $shortNameRaw) = @_;
	if (!%BOOK_NAMES) {
		my $path = join('/', $self->dataDir, 'static', 'kjv.cvs');
		my $fh = IO::File->new($path, 'r') or die(sprintf("Failed to open '%s' -- %s", $path, $ERRNO));
		while (my $line = <$fh>) {
			chomp($line);
			my ($code, undef, $longName) = split(m/;/, $line, 3);
			$longName =~ s/;\z// if (defined($longName));
			$BOOK_NAMES{$code} = $longName if (defined($code) && length($code) > 0);
		}
		$fh->close();
	}

	return $BOOK_NAMES{$shortNameRaw} // $shortNameRaw;
}

sub __bookVerseCount {
	my ($self, $bookId) = @_;
	my ($count) = $self->data->selectrow_array('SELECT COUNT(*) FROM verse WHERE book_id = ?', undef, $bookId);
	return $count + 0;
}

sub __sentimentByOrdinal {
	my ($self, $ordinal) = @_;
	$ordinal = $self->__verseCount() + $ordinal + 1 if ($ordinal < 0);
	my $data = $self->__sentimentData();
	return unless ($ordinal >= 1 && $ordinal <= scalar(@$data));
	return $data->[$ordinal - 1];
}

sub __verseCount {
	my ($self) = @_;
	my ($count) = $self->data->selectrow_array('SELECT COUNT(*) FROM verse');
	return $count + 0;
}

sub __sentimentData {
	my ($self) = @_;
	my $translation = $self->bible->translation;
	return $SENTIMENT_DATA{$translation} if ($SENTIMENT_DATA{$translation});

	my $path = join('/', $self->dataDir, 'static', 'emotion', $translation . '.json');
	my $fh = IO::File->new($path, 'r') or die(sprintf("Failed to open '%s' -- %s", $path, $ERRNO));
	my $text = do { local $/; <$fh> };
	$fh->close();
	$SENTIMENT_DATA{$translation} = decode_json($text);
	return $SENTIMENT_DATA{$translation};
}

sub __bookVerseCounts {
	my ($self, $bookId) = @_;
	my $sth = $self->data->prepare(<<'SQL');
		SELECT chapter.ordinal, COUNT(verse.id) AS verse_count
		  FROM chapter
		  LEFT JOIN verse ON verse.chapter_id = chapter.id
		 WHERE chapter.book_id = ?
		 GROUP BY chapter.id
		 ORDER BY chapter.ordinal
SQL
	$sth->execute($bookId);
	my %verseCounts;
	while (my $chapterRow = $sth->fetchrow_hashref()) {
		$verseCounts{ $chapterRow->{ordinal} + 0 } = $chapterRow->{verse_count} + 0;
	}

	return \%verseCounts;
}

sub __fsck {
	my ($self) = @_;

	if ($self->__validateSig()) {
		$self->dic->logger->error('File signature is bad -- probably not a bible data file');
		return EXIT_FAILURE;
	}

	if ($self->__validateVersion()) {
		$self->dic->logger->error('File version is unexpected or cannot be handled');
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}

sub __validateSig {
	my ($self) = @_;
	my ($sig) = $self->data->selectrow_array('SELECT sig FROM master LIMIT 1');
	return EXIT_SUCCESS if (defined($sig) && $sig eq $FILE_SIG);
	return EXIT_FAILURE;
}

sub __validateVersion {
	my ($self) = @_;
	my ($version) = $self->data->selectrow_array('SELECT version FROM master LIMIT 1');
	# Until we reach version 1.0.0 of the package (stable release), we only accept the exact correct version of the file!
	# this gives us more flexibility to make changes.
	if (defined($version) && length($version) <= 5 && $version =~ m/^\d+$/) {
		if ($version == $FILE_VERSION) {
			return EXIT_SUCCESS;
		} else {
			$self->dic->logger->error(sprintf('File version: %d, code expects version %d', $version, $FILE_VERSION));
		}
	}

	return EXIT_FAILURE;
}

sub __makeDataDir {
	my ($self) = @_;

	Readonly my @PATHS => ('data', '/usr/share/chleb-bible-search');
	foreach my $path (@PATHS) {
		if (-d $path) {
			my $testFile = join('/', $path, $self->__bibleFileName(compressed => 1));
			if (-f $testFile) {
				return $path;
			}
		}
	}

	return $PATHS[0];
}

sub __makeCacheDir {
	my ($self) = @_;

	Readonly my @PATHS => ('cache', '/var/cache/chleb-bible-search');
	foreach my $path (@PATHS) {
		return $path if (-d $path);
	}

	die('No cache dir available');
}

sub __bibleFileName {
	my ($self, %flags) = @_;
	my $fileName = join('.', $self->bible->translation, 'sqlite'); # TODO: need better logic to know which translations match which combined SQLite databases
	$fileName .= '.gz' if ($flags{compressed});
	return $fileName;
}

__PACKAGE__->meta->make_immutable;

1;
