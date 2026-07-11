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
use Digest::SHA qw(sha1_hex);
use Chleb::Bible::Book;
use Chleb::Type::Testament;

Readonly my $FILE_SIG     => '178d4220-2531-11f1-8c59-ab2e7e0be878';
Readonly my $FILE_VERSION => 13;

Readonly my $OT_COUNT => 39;

my %BOOK_NAMES;

has bible => (is => 'ro', isa => 'Chleb::Bible', required => 1);

has compressedPath => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeCompressedPath);

has data => (is => 'ro', isa => 'Object', lazy => 1, default => \&__makeData);

has cachePath => (is => 'rw', isa => 'Str', lazy => 1, default => \&__makeCachePath);

has dataDir => (is => 'rw', isa => 'Str', lazy => 1, default => \&__makeDataDir);

has cacheDir => (is => 'rw', isa => 'Str', lazy => 1, default => \&__makeCacheDir);

has __bookInfoCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __bookInfoDataCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __verseOrdinalCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __verseKeyCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __verseKeyOrdinalCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __verseTextCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __chapterVerseTextCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __bookVerseTextCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __verseKeyByBookCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __sentimentCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __sharedCacheClient => (is => 'ro', lazy => 1, builder => '__makeSharedCacheClient');
has __sharedCacheAvailable => (is => 'rw', isa => 'Bool', lazy => 1, builder => '__makeSharedCacheAvailable');
has __sharedCachePrefix => (is => 'ro', isa => 'Str', lazy => 1, builder => '__makeSharedCachePrefix');

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
		if (my $evalError = $EVAL_ERROR) {
			$self->dic->logger->warn("Cache refresh probe failed for " . $self->cachePath . ": $evalError");
			$needsRefresh = 1;
		}
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
	my $translation = $self->bible->translation;
	return $self->__bookInfoCache->{$translation} if ($self->__bookInfoCache->{$translation});

	if (my $cached = $self->__sharedCacheGet('books', $translation)) {
		return $self->__bookInfoCache->{$translation} = $self->__makeBooksFromRows($cached);
	}

	my @bookRows = ( );
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
		$bookRows[$bookIndex] = {
			ordinal      => $row->{ordinal} + 0,
			shortNameRaw => $shortNameRaw,
			longName     => $self->__bookLongName($shortNameRaw),
			chapterCount => $row->{chapter_count} + 0,
			verseCount   => $self->__bookVerseCount($row->{id}),
			testament    => $row->{testament},
		};
		$bookIndex++;
	}

	$self->__bookInfoCache->{$translation} = $self->__makeBooksFromRows(\@bookRows);
	$self->__sharedCacheSet('books', $translation, \@bookRows);
	return $self->__bookInfoCache->{$translation};
}

sub __makeBooksFromRows {
	my ($self, $rows) = @_;
	my @books = map {
		Chleb::Bible::Book->new({
			bible        => $self->bible,
			ordinal      => $_->{ordinal},
			shortNameRaw => $_->{shortNameRaw},
			longName     => $_->{longName},
			chapterCount => $_->{chapterCount},
			verseCount   => $_->{verseCount},
			testament    => Chleb::Type::Testament->createFromBackendValue($_->{testament}),
		});
	} @{ $rows // [ ] };
	return \@books;
}

sub getOrdinalByVerseKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m/:/, $key, 4);
	return 0 unless (defined($verseNumber));
	my $cacheKey = join(':', $translation, $bookShortName, $chapterNumber, $verseNumber);
	return $self->__verseOrdinalCache->{$cacheKey} if (exists($self->__verseOrdinalCache->{$cacheKey}));
	if (my $mapped = $self->__verseKeyOrdinalCache->{$translation}->{$bookShortName}->{$chapterNumber}->{$verseNumber}) {
		$self->__verseOrdinalCache->{$cacheKey} = $mapped + 0;
		return $mapped + 0;
	}
	if (my $cached = $self->__sharedCacheGet('ordinal', $cacheKey)) {
		$self->__verseOrdinalCache->{$cacheKey} = $cached + 0;
		return $cached + 0;
	}

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
	$ordinal //= 0;
	$self->__verseOrdinalCache->{$cacheKey} = $ordinal;
	$self->__verseKeyOrdinalCache->{$translation}->{$bookShortName}->{$chapterNumber}->{$verseNumber} = $ordinal if ($ordinal > 0);
	$self->__sharedCacheSet('ordinal', $cacheKey, $ordinal) if ($ordinal > 0);
	return $ordinal;
}

sub getVerseKeyByOrdinal {
	my ($self, $ordinal) = @_;
	return if (!defined($ordinal));
	$ordinal = $self->__verseCount() + $ordinal + 1 if ($ordinal < 0);
	return if ($ordinal < 1 || $ordinal > $self->__verseCount());
	my $translation = $self->bible->translation;
	my $cacheKey = join(':', $translation, $ordinal);
	return $self->__verseKeyCache->{$cacheKey} if (exists($self->__verseKeyCache->{$cacheKey}));
	if (my $mapped = $self->__verseKeyOrdinalCache->{$translation}->{__ordinalToKey}->{$ordinal}) {
		$self->__verseKeyCache->{$cacheKey} = $mapped;
		return $mapped;
	}
	if (my $cached = $self->__sharedCacheGet('versekey', $cacheKey)) {
		$self->__verseKeyCache->{$cacheKey} = $cached;
		return $cached;
	}

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
	my $key = join(':', @$row);
	$self->__verseKeyCache->{join(':', $translation, $ordinal)} = $key;
	my ($mappedTranslation, $mappedBookShortName, $mappedChapterNumber, $mappedVerseNumber) = split(m/:/, $key, 4);
	$self->__verseKeyOrdinalCache->{$mappedTranslation}->{__ordinalToKey}->{$ordinal} = $key;
	$self->__verseKeyOrdinalCache->{$mappedTranslation}->{$mappedBookShortName}->{$mappedChapterNumber}->{$mappedVerseNumber} = $ordinal;
	$self->__sharedCacheSet('versekey', $cacheKey, $key);
	return $key;
}

sub getVerseDataByKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m/:/, $key, 4);
	return unless (defined($verseNumber));
	my $cacheKey = join(':', $translation, $bookShortName, $chapterNumber, $verseNumber);
	return $self->__verseTextCache->{$cacheKey} if (exists($self->__verseTextCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('text', $cacheKey)) {
		$self->__verseTextCache->{$cacheKey} = $cached;
		return $cached;
	}
	if (my $chapterRows = $self->__chapterVerseTextCache->{join(':', $translation, $bookShortName, $chapterNumber)}) {
		foreach my $row (@{ $chapterRows }) {
			my $rowKey = join(':', $translation, $bookShortName, $chapterNumber, $row->{verse_ordinal} + 0);
			$self->__verseTextCache->{$rowKey} = $row->{text} if (!exists($self->__verseTextCache->{$rowKey}));
		}
		return $self->__verseTextCache->{$cacheKey} if (exists($self->__verseTextCache->{$cacheKey}));
	}
	if (my $bookRows = $self->__bookVerseTextCache->{join(':', $translation, $bookShortName)}) {
		foreach my $row (@{ $bookRows }) {
			my $rowKey = join(':', $translation, $bookShortName, $row->{chapter_ordinal}, $row->{verse_ordinal});
			$self->__verseTextCache->{$rowKey} = $row->{text} if (!exists($self->__verseTextCache->{$rowKey}));
		}
		return $self->__verseTextCache->{$cacheKey} if (exists($self->__verseTextCache->{$cacheKey}));
	}

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
	$self->__verseTextCache->{$cacheKey} = $text if (defined($text));
	$self->__sharedCacheSet('text', $cacheKey, $text) if (defined($text));
	return $text;
}

sub getChapterVerseDataByKey {
	my ($self, $bookShortName, $chapterNumber) = @_;
	my $cacheKey = join(':', $self->bible->translation, $bookShortName, $chapterNumber);
	return $self->__chapterVerseTextCache->{$cacheKey} if (exists($self->__chapterVerseTextCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('chaptertext', $cacheKey)) {
		$self->__chapterVerseTextCache->{$cacheKey} = $cached;
		return $cached;
	}

	my $sth = $self->data->prepare(<<'SQL');
		SELECT verse.ordinal_relative_to_chapter AS verse_ordinal, verse.text
		  FROM verse
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		   AND book.code = ?
		   AND chapter.ordinal = ?
		 ORDER BY verse.ordinal_relative_to_chapter
SQL
	$sth->execute($self->bible->translation, $bookShortName, $chapterNumber);
	my $rows = $sth->fetchall_arrayref({});
	$self->__chapterVerseTextCache->{$cacheKey} = $rows;
	foreach my $row (@{ $rows }) {
		my $rowKey = join(':', $self->bible->translation, $bookShortName, $chapterNumber, $row->{verse_ordinal} + 0);
		$self->__verseTextCache->{$rowKey} = $row->{text};
	}
	$self->__sharedCacheSet('chaptertext', $cacheKey, $rows);
	return $rows;
}

sub getBookVerseDataByKey {
	my ($self, $bookShortName) = @_;
	my $cacheKey = join(':', $self->bible->translation, $bookShortName);
	if (exists($self->__bookVerseTextCache->{$cacheKey})) {
		return $self->__bookVerseTextCache->{$cacheKey};
	}

	my $sth = $self->data->prepare(<<'SQL');
		SELECT chapter.ordinal AS chapter_ordinal,
		       verse.ordinal_relative_to_book AS book_ordinal,
		       verse.ordinal_relative_to_chapter AS verse_ordinal,
		       verse.text
		  FROM verse
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		   AND book.code = ?
		 ORDER BY chapter.ordinal, verse.ordinal_relative_to_chapter
SQL
	$sth->execute($self->bible->translation, $bookShortName);
	my $rows = $sth->fetchall_arrayref({});
	$self->__bookVerseTextCache->{$cacheKey} = $rows;
	my $translation = $self->bible->translation;
	foreach my $row (@{ $rows }) {
		my $chapterOrdinal = $row->{chapter_ordinal} + 0;
		my $verseOrdinal = $row->{verse_ordinal} + 0;
		my $bookOrdinal = $row->{book_ordinal} + 0;
		my $rowKey = join(':', $translation, $bookShortName, $chapterOrdinal, $verseOrdinal);
		$self->__verseTextCache->{$rowKey} = $row->{text};
		$self->__verseKeyOrdinalCache->{$translation}->{$bookShortName}->{$chapterOrdinal}->{$verseOrdinal} = $bookOrdinal;
		$self->__verseKeyOrdinalCache->{$translation}->{__ordinalToKey}->{$bookOrdinal} = join(':', $translation, $bookShortName, $chapterOrdinal, $verseOrdinal);
		$self->__verseKeyByBookCache->{join(':', $translation, $bookShortName, $bookOrdinal)} = join(':', $translation, $bookShortName, $chapterOrdinal, $verseOrdinal);
	}
	return $rows;
}

sub getVerseKeyByBookVerseKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $ordinal) = split(m/:/, $key, 3);
	return unless (defined($ordinal));
	my $cacheKey = join(':', $translation, $bookShortName, $ordinal);
	return $self->__verseKeyByBookCache->{$cacheKey} if (exists($self->__verseKeyByBookCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('bookversekey', $cacheKey)) {
		$self->__verseKeyByBookCache->{$cacheKey} = $cached;
		return $cached;
	}
	if (my $mapped = $self->__verseKeyOrdinalCache->{$translation}->{__ordinalToKey}->{$ordinal}) {
		$self->__verseKeyByBookCache->{$cacheKey} = $mapped;
		return $mapped;
	}

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
	my $verseKey = join(':', @$row);
	$self->__verseKeyByBookCache->{$cacheKey} = $verseKey;
	$self->__verseKeyOrdinalCache->{$translation}->{__ordinalToKey}->{$ordinal} = $verseKey;
	$self->__sharedCacheSet('bookversekey', $cacheKey, $verseKey);
	return $verseKey;
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
	return $BOOK_NAMES{$shortNameRaw} // $shortNameRaw if (exists($BOOK_NAMES{$shortNameRaw}));
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
	return $self->__bookInfoCache->{"versecount:$bookId"} if (exists($self->__bookInfoCache->{"versecount:$bookId"}));
	my ($count) = $self->data->selectrow_array('SELECT COUNT(*) FROM verse WHERE book_id = ?', undef, $bookId);
	$count += 0;
	$self->__bookInfoCache->{"versecount:$bookId"} = $count;
	return $count;
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
	return $self->__bookInfoCache->{"versecount:total"} if (exists($self->__bookInfoCache->{"versecount:total"}));
	my ($count) = $self->data->selectrow_array('SELECT COUNT(*) FROM verse');
	$count += 0;
	$self->__bookInfoCache->{"versecount:total"} = $count;
	return $count;
}

sub __sentimentData {
	my ($self) = @_;
	my $translation = $self->bible->translation;
	return $self->__sentimentCache->{$translation} if ($self->__sentimentCache->{$translation});

	my $path = join('/', $self->dataDir, 'static', 'emotion', $translation . '.json');
	my $fh = IO::File->new($path, 'r') or die(sprintf("Failed to open '%s' -- %s", $path, $ERRNO));
	my $text = do { local $/; <$fh> };
	$fh->close();
	$self->__sentimentCache->{$translation} = decode_json($text);
	return $self->__sentimentCache->{$translation};
}

sub __makeSharedCacheClient {
	my ($self) = @_;

	eval {
		require Cache::Memcached;
		Cache::Memcached->import();
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->warn("Cannot load Cache::Memcached for backend cache: $evalError");
		return;
	}

	my $config = $self->dic->config->get('rate_limit', 'backend_memcached', {});
	my $servers = $config->{servers} // [ '127.0.0.1:11211' ];
	$servers = [ $servers ] unless (ref($servers) eq 'ARRAY');

	my $client;
	eval {
		$client = Cache::Memcached->new({
			servers => $servers,
			compress_threshold => 10_000,
		});
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->warn("Cannot create memcached client for backend cache: $evalError");
		return;
	}

	return $client;
}

sub __makeSharedCachePrefix {
	my ($self) = @_;
	my $config = $self->dic->config->get('backend_cache', 'memcached', {});
	return $config->{prefix} // 'chleb:backend';
}

sub __makeSharedCacheAvailable {
	my ($self) = @_;

	return 0 unless ($self->__sharedCacheClient);

	my $probeKey = $self->__sharedCacheKey('probe', $$);
	my $ok;
	eval {
		$ok = $self->__sharedCacheClient->set($probeKey, 1, 5);
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->warn("Memcached backend cache unavailable during probe: $evalError");
		return 0;
	}

	return $ok ? 1 : 0;
}

sub __sharedCacheGet {
	my ($self, $kind, $key) = @_;
	return unless ($self->__sharedCacheAvailable);

	my $result;
	eval {
		$result = $self->__sharedCacheClient->get($self->__sharedCacheKey($kind, $key));
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->warn("Memcached backend cache get failed for $kind: $evalError");
		$self->__sharedCacheAvailable(0);
		return;
	}

	return $result;
}

sub __sharedCacheSet {
	my ($self, $kind, $key, $value) = @_;
	return unless ($self->__sharedCacheAvailable);

	eval {
		# Memcached treats zero TTL as no expiry; these lookups are effectively static.
		$self->__sharedCacheClient->set($self->__sharedCacheKey($kind, $key), $value, 0);
	};
	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->warn("Memcached backend cache set failed for $kind: $evalError");
		$self->__sharedCacheAvailable(0);
		return;
	}

	return 1;
}

sub __sharedCacheKey {
	my ($self, $kind, $key) = @_;
	return join(':', $self->__sharedCachePrefix, $kind, sha1_hex($key // ''));
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
