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
use Carp qw(croak);
use Moose;

extends 'Chleb::Bible::Base';

use English qw(-no_match_vars);
use Fcntl qw(:flock);
use IO::File;
use IO::Handle ();
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use File::Temp qw(tempfile);
use Readonly;
use DBI;
use Storable qw(nstore_fd retrieve);
use Digest::SHA qw(sha1_hex);
use Chleb::Bible::Book;
use Chleb::Type::Testament;

Readonly my $FILE_SIG     => '178d4220-2531-11f1-8c59-ab2e7e0be878';
Readonly my $FILE_VERSION => 17;
Readonly my $SHARED_CACHE_FILE => 'shared.bin';
Readonly my $SHARED_CACHE_FORMAT_VERSION => 1;

Readonly my $OT_COUNT => 39;

my %BOOK_NAMES;
Readonly my %BOOK_LONG_NAMES => (
	Gen => 'Genesis',
	Exo => 'Exodus',
	Lev => 'Leviticus',
	Num => 'Numbers',
	Deu => 'Deuteronomy',
	Josh => 'Joshua',
	Judg => 'Judges',
	Ruth => 'Ruth',
	'1Sam' => '1 Samuel',
	'2Sam' => '2 Samuel',
	'1Ki' => 'I Kings',
	'2Ki' => 'II Kings',
	'1Chr' => 'I Chronicles',
	'2Chr' => 'II Chronicles',
	Ezra => 'Ezra',
	Neh => 'Nehemiah',
	Est => 'Esther',
	Job => 'Job',
	Psa => 'Psalms',
	Prov => 'Proverbs',
	Eccl => 'Ecclesiastes',
	Song => 'Song of Solomon',
	Isa => 'Isaiah',
	Jer => 'Jeremiah',
	Lam => 'Lamentations',
	Ezek => 'Ezekiel',
	Dan => 'Daniel',
	Hosea => 'Hosea',
	Joel => 'Joel',
	Amos => 'Amos',
	Oba => 'Obadiah',
	Jonah => 'Jonah',
	Micah => 'Micah',
	Nahum => 'Nahum',
	Hab => 'Habakkuk',
	Zep => 'Zephaniah',
	Hag => 'Haggai',
	Zec => 'Zechariah',
	Mal => 'Malachi',
	Mat => 'Matthew',
	Mark => 'Mark',
	Luke => 'Luke',
	John => 'John',
	Acts => 'Acts',
	Rom => 'Romans',
	'1Cor' => 'I Corinthians',
	'2Cor' => 'II Corinthians',
	Gal => 'Galatians',
	Eph => 'Ephesians',
	Phil => 'Philippians',
	Col => 'Colossians',
	'1Th' => 'I Thessalonians',
	'2Th' => 'II Thessalonians',
	'1Tim' => 'I Timothy',
	'2Tim' => 'II Timothy',
	Titus => 'Titus',
	Phile => 'Philemon',
	Heb => 'Hebrews',
	James => 'James',
	'1Pet' => 'I Peter',
	'2Pet' => 'II Peter',
	'1John' => 'I John',
	'2John' => 'II John',
	'3John' => 'III John',
	Jude => 'Jude',
	Rev => 'Revelation of John',
);

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
has __propertyCache => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });
has __sharedCache => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '__makeSharedCache');
has __sharedCacheDirty => (is => 'rw', isa => 'Bool', default => 0);
has __sharedCachePath => (is => 'ro', isa => 'Str', lazy => 1, builder => '__makeSharedCachePath');
has __sharedCacheWriteDeferred => (is => 'rw', isa => 'Bool', default => 0);
has __sourceMetadata => (is => 'ro', isa => 'HashRef', lazy => 1, default => sub { {} });

=head1 PRIVATE METHODS

=over

=cut

sub __makeCompressedPath {
	my ($self) = @_;
	return $self->__makeSourceCompressedPath();
}

=item C<__makeCompressedPath()>

Resolve the compressed source file path for the current bible translation.
This now delegates to the source-selection helper so startup can inspect all
available SQLite bundles and choose the best match.

=cut

sub __makeCachePath {
	my ($self) = @_;

	my $path = join('/', $self->cacheDir, $self->__bibleFileName());
	my $sourceMTime = (stat($self->compressedPath))[9] // 0;
	my $cacheMTime = (stat($path))[9] // 0;
	my $needsRefresh = (!-f $path || $cacheMTime < $sourceMTime);

	if (!$needsRefresh) {
		my $evalOk1; $evalOk1 = eval {
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
			1;
		} or $evalOk1 = 0;
		if (my $evalError = $EVAL_ERROR) {
			$self->dic->logger->warn("Cache refresh probe failed for " . $self->cachePath . ": $evalError");
			$needsRefresh = 1;
		}
	}

	if ($needsRefresh) {
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

=back

=head1 METHODS

=over

=cut

sub BUILD {
	my ($self) = @_;

	if ($self->__fsck() != EXIT_SUCCESS) {
		croak(sprintf("'%s' is corrupt or otherwise cannot be handled", $self->cachePath));
	}

	return;
}

=item C<resetForkUnsafeHandles()>

Flush the Storable-backed shared cache, then close and forget the SQLite
database handle so that, after the PSGI server forks its workers, each worker
lazily re-opens its own handle.  The populated in-memory caches are left intact
so forked workers inherit a warm cache via copy-on-write.

=cut

sub resetForkUnsafeHandles {
	my ($self) = @_;

	$self->flushSharedCache();

	if (my $dbh = delete $self->{data}) {
		my $disconnectOk;
		$disconnectOk = eval { $dbh->disconnect(); 1; } or $disconnectOk = 0;
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
	my $sth = $self->__prepareSelect($self->data, <<'SQL', $self->bible->translation);
		SELECT book.id, book.code, book.translation, book.testament, book.ordinal,
		       book.chapter_count
		  FROM book
		 WHERE book.translation = ?
		 ORDER BY book.ordinal
SQL
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

=item C<getProperty($name)>

Return a translation property from the SQLite source, or C<undef> when the
property is not present.

=cut

sub getProperty {
	my ($self, $name) = @_;
	my $translation = $self->bible->translation;
	return $self->__propertyCache->{$translation}->{$name}
	    if (exists($self->__propertyCache->{$translation}->{$name}));

	my $sth = $self->__prepareSelect($self->data, <<'SQL', $translation, $name);
		SELECT value
		  FROM properties
		 WHERE translation = ?
		   AND name = ?
SQL
	my ($value) = $sth->fetchrow_array();
	$self->__propertyCache->{$translation}->{$name} = $value;

	return $value;
}

=item C<getAvailableTranslations()>

Return translation codes found in the available compressed SQLite source files.

=cut

sub getAvailableTranslations {
	my ($self) = @_;

	my %translations;
	foreach my $sourceFile ($self->__sourceFilesInPath($self->dataDir)) {
		my $meta = $self->__sourceMetadata->{$sourceFile} //= $self->__inspectSourceFile($sourceFile);
		$translations{$_} = 1 foreach (keys(%{ $meta->{translations} }));
	}

	my @translations = sort(keys(%translations));
	return @translations;
}

=item C<year()>

Return the publication year for this translation from the SQLite source.

=cut

sub year {
	my ($self) = @_;
	my ($year) = $self->__selectrowArray(
		$self->data,
		'SELECT year FROM translation WHERE code = ?',
		$self->bible->translation,
	);
	return defined($year) ? $year + 0 : undef;
}

sub getOrdinalByVerseKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m{ : }x, $key, 4);
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

	my $sth = $self->__prepareSelect($self->data, <<'SQL', $translation, $bookShortName, $chapterNumber, $verseNumber);
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

	my $sth = $self->__prepareSelect($self->data, <<'SQL', $ordinal - 1);
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
	my $row = $sth->fetchrow_arrayref();
	return unless ($row);
	my $key = join(':', @$row);
	$self->__verseKeyCache->{join(':', $translation, $ordinal)} = $key;
	my ($mappedTranslation, $mappedBookShortName, $mappedChapterNumber, $mappedVerseNumber) = split(m{ : }x, $key, 4);
	$self->__verseKeyOrdinalCache->{$mappedTranslation}->{__ordinalToKey}->{$ordinal} = $key;
	$self->__verseKeyOrdinalCache->{$mappedTranslation}->{$mappedBookShortName}->{$mappedChapterNumber}->{$mappedVerseNumber} = $ordinal;
	$self->__sharedCacheSet('versekey', $cacheKey, $key);
	return $key;
}

sub getVerseDataByKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m{ : }x, $key, 4);
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

	my $sth = $self->__prepareSelect($self->data, <<'SQL', $translation, $bookShortName, $chapterNumber, $verseNumber);
		SELECT verse.text
		  FROM verse
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		   AND book.code = ?
		   AND chapter.ordinal = ?
		   AND verse.ordinal_relative_to_chapter = ?
SQL
	my ($text) = $sth->fetchrow_array();
	$self->__verseTextCache->{$cacheKey} = $text if (defined($text));
	$self->__sharedCacheSet('text', $cacheKey, $text) if (defined($text));
	return $text;
}

=item C<getChapterVerseDataByKey($bookShortName, $chapterNumber)>

TODO

=cut

sub getChapterVerseDataByKey {
	my ($self, $bookShortName, $chapterNumber) = @_;
	my $cacheKey = join(':', $self->bible->translation, $bookShortName, $chapterNumber);
	return $self->__chapterVerseTextCache->{$cacheKey} if (exists($self->__chapterVerseTextCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('chaptertext', $cacheKey)) {
		$self->__chapterVerseTextCache->{$cacheKey} = $cached;
		$self->__primeChapterOrdinals($bookShortName, $chapterNumber, $cached);
		return $cached;
	}

	my $sth = $self->__prepareSelect($self->data, <<'SQL', $self->bible->translation, $bookShortName, $chapterNumber);
		SELECT verse.ordinal_relative_to_chapter AS verse_ordinal, verse.text
		  FROM verse
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		   AND book.code = ?
		   AND chapter.ordinal = ?
		 ORDER BY verse.ordinal_relative_to_chapter
SQL
	my $rows = $sth->fetchall_arrayref({});
	$self->__chapterVerseTextCache->{$cacheKey} = $rows;
	foreach my $row (@{ $rows }) {
		my $rowKey = join(':', $self->bible->translation, $bookShortName, $chapterNumber, $row->{verse_ordinal} + 0);
		$self->__verseTextCache->{$rowKey} = $row->{text};
	}
	$self->__sharedCacheSet('chaptertext', $cacheKey, $rows);
	$self->__primeChapterOrdinals($bookShortName, $chapterNumber, $rows);
	return $rows;
}

=back

=cut

=head1 PRIVATE METHODS

=over

=item C<__primeChapterOrdinals($bookShortName, $chapterNumber, $rows)>

Populate the global absolute-ordinal caches for every verse of a chapter in one
pass.  A chapter's verses are contiguous in the global verse ordering, so we only
resolve the absolute ordinal of the chapter's first verse (one lookup) and derive
the rest by position.  This lets subsequent per-verse getOrdinalByVerseKey() calls
made while rendering a whole chapter hit the local cache instead of issuing one
shared-cache lookup (or SQLite window query) per verse.

<$rows> is the ARRAY ref returned by L</getChapterVerseDataByKey($bookShortName, $chapterNumber)>,
ordered by C<verse_ordinal>.

=back

=cut

sub __primeChapterOrdinals {
	my ($self, $bookShortName, $chapterNumber, $rows) = @_;
	return unless (ref($rows) eq 'ARRAY' && scalar(@$rows));

	my $translation = $self->bible->translation;
	my $firstVerseOrdinal = $rows->[0]->{verse_ordinal} + 0;
	my $base = $self->getOrdinalByVerseKey(join(':', $translation, $bookShortName, $chapterNumber, $firstVerseOrdinal));
	return if (!defined($base) || $base <= 0);

	for (my $i = 0; $i < scalar(@$rows); $i++) {
		my $verseOrdinal = $rows->[$i]->{verse_ordinal} + 0;
		my $absolute = $base + $i;
		my $verseCacheKey = join(':', $translation, $bookShortName, $chapterNumber, $verseOrdinal);
		$self->__verseOrdinalCache->{$verseCacheKey} //= $absolute;
		$self->__verseKeyOrdinalCache->{$translation}->{$bookShortName}->{$chapterNumber}->{$verseOrdinal} //= $absolute;
		$self->__verseKeyOrdinalCache->{$translation}->{__ordinalToKey}->{$absolute} //= $verseCacheKey;
	}

	return;
}

sub getBookVerseDataByKey {
	my ($self, $bookShortName) = @_;
	my $cacheKey = join(':', $self->bible->translation, $bookShortName);
	if (exists($self->__bookVerseTextCache->{$cacheKey})) {
		return $self->__bookVerseTextCache->{$cacheKey};
	}

	my $sth = $self->__prepareSelect($self->data, <<'SQL', $self->bible->translation, $bookShortName);
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
	my $rows = $sth->fetchall_arrayref({});
	$self->__bookVerseTextCache->{$cacheKey} = $rows;
	my $translation = $self->bible->translation;
	foreach my $row (@{ $rows }) {
		my $chapterOrdinal = $row->{chapter_ordinal} + 0;
		my $verseOrdinal = $row->{verse_ordinal} + 0;
		my $bookOrdinal = $row->{book_ordinal} + 0;
		my $rowKey = join(':', $translation, $bookShortName, $chapterOrdinal, $verseOrdinal);
		$self->__verseTextCache->{$rowKey} = $row->{text};
		# NB: $bookOrdinal is the *within-book* ordinal; it must NOT be written to
		# __verseKeyOrdinalCache, which holds the *global* absolute ordinal read
		# back by getOrdinalByVerseKey().  It only feeds the book-relative map below.
		$self->__verseKeyByBookCache->{join(':', $translation, $bookShortName, $bookOrdinal)} = join(':', $translation, $bookShortName, $chapterOrdinal, $verseOrdinal);
	}
	return $rows;
}

sub getVerseKeyByBookVerseKey {
	my ($self, $key) = @_;
	my ($translation, $bookShortName, $ordinal) = split(m{ : }x, $key, 3);
	return unless (defined($ordinal));
	my $cacheKey = join(':', $translation, $bookShortName, $ordinal);
	return $self->__verseKeyByBookCache->{$cacheKey} if (exists($self->__verseKeyByBookCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('bookversekey', $cacheKey)) {
		$self->__verseKeyByBookCache->{$cacheKey} = $cached;
		return $cached;
	}

	my $sth = $self->__prepareSelect($self->data, <<'SQL', $translation, $bookShortName, $ordinal);
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
	my $translation = $self->bible->translation;
	my $cacheKey = join(':', $translation, $shortNameRaw);
	return $self->__bookInfoDataCache->{$cacheKey} if (exists($self->__bookInfoDataCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('bookinfo', $cacheKey)) {
		$self->__bookInfoDataCache->{$cacheKey} = $cached;
		return $cached;
	}
	my $sth = $self->__prepareSelect($self->data, <<'SQL', $shortNameRaw);
		SELECT book.id, book.code, book.testament, book.chapter_count
		  FROM book
		 WHERE book.code = ?
SQL
	my $row = $sth->fetchrow_hashref();
	return unless ($row);

	my $bookInfo = {
		c => $row->{chapter_count} + 0,
		n => $self->__bookLongName($shortNameRaw),
		t => $row->{testament},
		v => $self->__bookVerseCounts($row->{id}),
	};
	$self->__bookInfoDataCache->{$cacheKey} = $bookInfo;
	$self->__sharedCacheSet('bookinfo', $cacheKey, $bookInfo);
	return $bookInfo;
}

sub getSentimentByOrdinal {
	my ($self, $ordinal) = @_;

	my $verseKey = $self->getVerseKeyByOrdinal($ordinal);
	return $self->getSentimentByVerseKey($verseKey) if (defined($verseKey));

	my $ordinalLabel = defined($ordinal) ? $ordinal : '<undef>';
	$self->dic->logger->warn("No verse for sentiment ordinal $ordinalLabel");
	return {
		emotion => 'neutral',
		tones   => [ ],
	};
}

sub getSentimentByVerseKey {
	my ($self, $verseKey) = @_;

	my $cacheKey = $verseKey // '';
	return $self->__sentimentCache->{$cacheKey} if (exists($self->__sentimentCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('sentiment', $cacheKey)) {
		$self->__sentimentCache->{$cacheKey} = $cached;
		return $cached;
	}

	my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m{ : }x, $cacheKey, 4);
	my $sentiment;
	if (defined($verseNumber)) {
		my $sth = $self->__prepareSelect($self->data, <<'SQL', $translation, $bookShortName, $chapterNumber, $verseNumber);
			SELECT sentiment.sentiment, sentiment.kind
			  FROM sentiment
			  JOIN verse ON verse.id = sentiment.verse_id
			  JOIN book ON book.id = verse.book_id
			  JOIN chapter ON chapter.id = verse.chapter_id
			 WHERE book.translation = ?
			   AND book.code = ?
			   AND chapter.ordinal = ?
			   AND verse.ordinal_relative_to_chapter = ?
			 ORDER BY CASE sentiment.kind WHEN 'emotion' THEN 0 ELSE 1 END,
			          sentiment.sentiment
SQL
		my $found = 0;
		$sentiment = {
			emotion => 'neutral',
			tones   => [ ],
		};
		while (my $row = $sth->fetchrow_hashref()) {
			$found = 1;
			if ($row->{kind} eq 'emotion') {
				$sentiment->{emotion} = $row->{sentiment};
			} else {
				push(@{ $sentiment->{tones} }, $row->{sentiment});
			}
		}
		$sentiment = undef unless ($found);
	}

	my $emotion = 'neutral';
	my $tones = [ ];
	if ($sentiment) {
		$emotion = $sentiment->{emotion} if (defined($sentiment->{emotion}));
		$tones = [ sort @{ $sentiment->{tones} } ] if (defined($sentiment->{tones}));
	} else {
		$self->dic->logger->warn("No sentiment entry for verse $cacheKey");
	}

	$sentiment = {
		emotion => $emotion,
		tones   => $tones,
	};
	$self->__sentimentCache->{$cacheKey} = $sentiment;
	$self->__sharedCacheSet('sentiment', $cacheKey, $sentiment);
	return $sentiment;
}

=item C<primeSentimentCache()>

Load all sentiment data for this translation into the local and shared caches.
The caller may defer shared-cache writes when loading several translations.

=cut

sub primeSentimentCache {
	my ($self) = @_;
	my $translation = $self->bible->translation;
	my $sth = $self->__prepareSelect($self->data, <<'SQL', $translation);
		SELECT book.code,
		       chapter.ordinal AS chapter_ordinal,
		       verse.ordinal_relative_to_chapter AS verse_ordinal,
		       sentiment.sentiment,
		       sentiment.kind
		  FROM sentiment
		  JOIN verse ON verse.id = sentiment.verse_id
		  JOIN book ON book.id = verse.book_id
		  JOIN chapter ON chapter.id = verse.chapter_id
		 WHERE book.translation = ?
		 ORDER BY book.ordinal, chapter.ordinal, verse.ordinal_relative_to_chapter,
		          CASE sentiment.kind WHEN 'emotion' THEN 0 ELSE 1 END,
		          sentiment.sentiment
SQL
	my %sentimentByKey;
	while (my $row = $sth->fetchrow_hashref()) {
		my $key = join(':', $translation, $row->{code}, $row->{chapter_ordinal}, $row->{verse_ordinal});
		$sentimentByKey{$key} //= {
			emotion => 'neutral',
			tones   => [ ],
		};
		if ($row->{kind} eq 'emotion') {
			$sentimentByKey{$key}->{emotion} = $row->{sentiment};
		} else {
			push(@{ $sentimentByKey{$key}->{tones} }, $row->{sentiment});
		}
	}

	foreach my $key (keys(%sentimentByKey)) {
		$sentimentByKey{$key}->{tones} = [ sort @{ $sentimentByKey{$key}->{tones} } ];
		$self->__sentimentCache->{$key} = $sentimentByKey{$key};
		$self->__sharedCacheSet('sentiment', $key, $sentimentByKey{$key});
	}

	return scalar(keys(%sentimentByKey));
}

sub getVerseCount {
	my ($self) = @_;
	my ($count) = $self->__selectrowArray($self->data, 'SELECT COUNT(*) FROM verse');
	return $count + 0;
}

sub __bookLongName {
	my ($self, $shortNameRaw) = @_;
	return $BOOK_NAMES{$shortNameRaw} //= ($BOOK_LONG_NAMES{$shortNameRaw} // $shortNameRaw);
}

sub __bookVerseCount {
	my ($self, $bookId) = @_;
	return $self->__bookInfoCache->{"versecount:$bookId"} if (exists($self->__bookInfoCache->{"versecount:$bookId"}));
	my ($count) = $self->__selectrowArray($self->data, 'SELECT COUNT(*) FROM verse WHERE book_id = ?', $bookId);
	$count += 0;
	$self->__bookInfoCache->{"versecount:$bookId"} = $count;
	return $count;
}

sub __verseCount {
	my ($self) = @_;
	my $translation = $self->bible->translation;
	my $cacheKey = join(':', $translation, 'versecount:total');
	return $self->__bookInfoCache->{$cacheKey} if (exists($self->__bookInfoCache->{$cacheKey}));
	if (my $cached = $self->__sharedCacheGet('versecount', $cacheKey)) {
		$self->__bookInfoCache->{$cacheKey} = $cached + 0;
		return $cached + 0;
	}
	my ($count) = $self->__selectrowArray($self->data, 'SELECT COUNT(*) FROM verse');
	$count += 0;
	$self->__bookInfoCache->{$cacheKey} = $count;
	$self->__sharedCacheSet('versecount', $cacheKey, $count);
	return $count;
}

=head1  PRIVATE METHODS

=over

=item C<__sharedCacheGet($kind, $key)>

Return a value from the Storable-backed shared cache for this translation, or
C<undef> if no entry exists.  C<$kind> groups related cache entries, while
C<$key> is hashed before being used as the stored entry key.

=cut

sub __sharedCacheGet {
	my ($self, $kind, $key) = @_;
	my $entries = $self->__sharedCacheTranslation->{entries};
	return unless (ref($entries->{$kind}) eq 'HASH');
	my $sharedKey = $self->__sharedCacheKey($key);
	return $entries->{$kind}->{$sharedKey} if (exists($entries->{$kind}->{$sharedKey}));
	return;
}

=item C<__sharedCacheSet($kind, $key, $value)>

Store a value in the shared cache for this translation.  By default this also
flushes C<shared.bin> immediately; callers doing many writes can defer those
flushes with L</deferSharedCacheWrites($defer)>.

=cut

sub __sharedCacheSet {
	my ($self, $kind, $key, $value) = @_;
	my $entries = $self->__sharedCacheTranslation->{entries};
	$entries->{$kind} //= {};
	$entries->{$kind}->{ $self->__sharedCacheKey($key) } = $value;
	$self->__sharedCacheDirty(1);
	$self->flushSharedCache() unless ($self->__sharedCacheWriteDeferred);

	return 1;
}

=item C<deferSharedCacheWrites($defer)>

Enable or disable deferred writes for the Storable-backed shared cache.  This is
used by warmup and search loops so they can add many entries in memory and then
write C<shared.bin> once at the end.

=cut

sub deferSharedCacheWrites {
	my ($self, $defer) = @_;
	$self->__sharedCacheWriteDeferred($defer ? 1 : 0);
	return;
}

=item C<flushSharedCache()>

Flush pending shared-cache changes to C<shared.bin>.  The write path takes an
exclusive lock, merges this backend's current translation cache with the latest
file contents, and replaces the file atomically.

=cut

sub flushSharedCache {
	my ($self) = @_;
	return 1 unless ($self->__sharedCacheDirty);

	my $ok = $self->__withSharedCacheLock(LOCK_EX, sub {
		my $diskCache = $self->__readSharedCacheFile();
		$self->__mergeSharedCacheTranslation($diskCache);
		return $self->__writeSharedCacheFile($diskCache);
	});

	if ($ok) {
		$self->__sharedCacheDirty(0);
	}

	return $ok;
}

=item C<__makeSharedCache()>

Build the in-memory representation of C<shared.bin>.  The file is read under a
shared lock and falls back to an empty cache structure if the file does not
exist, cannot be read, or is stale for this code's cache format.

=cut

# Invoked by Moose as the lazy builder for the __sharedCache attribute.
sub __makeSharedCache { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return $self->__withSharedCacheLock(LOCK_SH, sub {
		return $self->__readSharedCacheFile();
	}) // $self->__emptySharedCache();
}

=item C<__makeSharedCachePath()>

Return the path to the backend shared cache file in the selected cache
directory.

=cut

# Invoked by Moose as the lazy builder for the __sharedCachePath attribute.
sub __makeSharedCachePath { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return join('/', $self->cacheDir, $SHARED_CACHE_FILE);
}

=item C<__sharedCacheTranslation()>

Return the per-translation shared-cache structure for the current bible.  If the
translation entry is missing or stale relative to the compressed SQLite source,
it is replaced with a fresh empty entry.

=cut

sub __sharedCacheTranslation {
	my ($self) = @_;
	my $translation = $self->bible->translation;
	my $cache = $self->__sharedCache;
	$cache->{translations} //= {};
	my $translationCache = $cache->{translations}->{$translation};

	if (!$self->__sharedCacheTranslationIsFresh($translationCache)) {
		$translationCache = {
			source => $self->__sharedCacheSourceMeta(),
			entries => {},
		};
		$cache->{translations}->{$translation} = $translationCache;
	}

	$translationCache->{entries} //= {};
	return $translationCache;
}

=item C<__mergeSharedCacheTranslation($cache)>

Merge this backend object's current translation cache into a full shared-cache
hash read from disk.  Other translation entries already present in C<$cache> are
preserved.

=cut

sub __mergeSharedCacheTranslation {
	my ($self, $cache) = @_;
	my $translation = $self->bible->translation;
	$cache->{translations} //= {};
	$cache->{translations}->{$translation} = $self->__sharedCacheTranslation;
	return;
}

=item C<__sharedCacheTranslationIsFresh($translationCache)>

Return true when a translation entry has the expected structure and was built
from the same compressed SQLite source file that this backend is using.

=cut

sub __sharedCacheTranslationIsFresh {
	my ($self, $translationCache) = @_;
	return 0 unless (ref($translationCache) eq 'HASH');
	return 0 unless (ref($translationCache->{entries}) eq 'HASH');
	return 0 unless (ref($translationCache->{source}) eq 'HASH');

	my $source = $self->__sharedCacheSourceMeta();
	foreach my $key (qw(source_mtime source_size)) {
		return 0 unless (($translationCache->{source}->{$key} // -1) == ($source->{$key} // -2));
	}

	return 1;
}

=item C<__sharedCacheSourceMeta()>

Return the compressed source file metadata used to decide whether a
translation's shared-cache entry is still valid.

=cut

sub __sharedCacheSourceMeta {
	my ($self) = @_;
	my @stat = stat($self->compressedPath);
	return {
		source_mtime => $stat[9] // 0,
		source_size  => $stat[7] // 0,
	};
}

=item C<__readSharedCacheFile()>

Read and validate C<shared.bin>.  Corrupt, incompatible, or missing cache files
are treated as empty caches so backend operation can continue.

=cut

sub __readSharedCacheFile {
	my ($self) = @_;
	my $path = $self->__sharedCachePath;
	return $self->__emptySharedCache() unless (-f $path);

	my $cache;
	my $evalOk2; $evalOk2 = eval {
		$cache = retrieve($path);
		1;
	} or $evalOk2 = 0;
	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->warn("Cannot load backend shared cache from $path: $evalError");
		return $self->__emptySharedCache();
	}

	return $self->__validSharedCache($cache) ? $cache : $self->__emptySharedCache();
}

=item C<__writeSharedCacheFile($cache)>

Write the supplied shared-cache hash to C<shared.bin> using a temporary file in
the cache directory, flushing it, and atomically renaming it into place.

=cut

sub __writeSharedCacheFile {
	my ($self, $cache) = @_;
	my $path = $self->__sharedCachePath;
	my ($tempHandle, $tempPath) = tempfile(DIR => $self->cacheDir, UNLINK => 0);
	my $ok = 1;

	my $evalOk3; $evalOk3 = eval {
		binmode($tempHandle, ':raw');
		nstore_fd($cache, $tempHandle);
		$tempHandle->flush() if ($tempHandle->can('flush'));
		$tempHandle->sync() or croak("sync failed: $ERRNO");
		close($tempHandle) or croak("close($tempPath) failed: $ERRNO");
		rename($tempPath, $path) or croak("rename($tempPath -> $path) failed: $ERRNO");
		1;
	} or $evalOk3 = 0;
	if (my $evalError = $EVAL_ERROR) {
		$ok = 0;
		$self->dic->logger->warn("Cannot store backend shared cache to $path: $evalError");
		close($tempHandle) if ($tempHandle);
		unlink($tempPath) if (defined($tempPath) && -f $tempPath);
	}

	return $ok;
}

=item C<__withSharedCacheLock($mode, $callback)>

Run C<$callback> while holding the shared-cache lock file with the supplied
C<flock()> mode.  Returns the callback result, or C<undef> if the lock file
cannot be opened or locked.

=cut

sub __withSharedCacheLock {
	my ($self, $mode, $callback) = @_;
	my $lockPath = $self->__sharedCachePath . '.lock';
	open(my $lockHandle, '>>', $lockPath) or do {
		$self->dic->logger->warn("Cannot open backend shared cache lock $lockPath: $ERRNO");
		return;
	};
	flock($lockHandle, $mode) or do {
		$self->dic->logger->warn("Cannot lock backend shared cache $lockPath: $ERRNO");
		close($lockHandle);
		return;
	};

	my $result = $callback->();
	close($lockHandle);
	return $result;
}

=item C<__emptySharedCache()>

Return a new empty top-level shared-cache structure tagged with the current
cache format and backend file version.

=cut

sub __emptySharedCache {
	my ($self) = @_;
	return {
		format_version => $SHARED_CACHE_FORMAT_VERSION,
		file_version => $FILE_VERSION,
		translations => {},
	};
}

=item C<__validSharedCache($cache)>

Return true when C<$cache> is a top-level shared-cache hash for the current
cache format and backend file version.

=cut

sub __validSharedCache {
	my ($self, $cache) = @_;
	return 0 unless (ref($cache) eq 'HASH');
	return 0 unless (($cache->{format_version} // -1) == $SHARED_CACHE_FORMAT_VERSION);
	return 0 unless (($cache->{file_version} // -1) == $FILE_VERSION);
	return 0 unless (ref($cache->{translations}) eq 'HASH');
	return 1;
}

=item C<__sharedCacheKey($key)>

Return the SHA-1 key used for a single shared-cache entry.  Hashing keeps stored
entry names short and avoids leaking raw lookup strings into the cache file's
internal structure.

=cut

sub __sharedCacheKey {
	my ($self, $key) = @_;
	return sha1_hex($key // '');
}

sub __bookVerseCounts {
	my ($self, $bookId) = @_;
	my $sth = $self->__prepareSelect($self->data, <<'SQL', $bookId);
		SELECT chapter.ordinal, COUNT(verse.id) AS verse_count
		  FROM chapter
		  LEFT JOIN verse ON verse.chapter_id = chapter.id
		 WHERE chapter.book_id = ?
		 GROUP BY chapter.id
		 ORDER BY chapter.ordinal
SQL
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
	my ($sig) = $self->__selectrowArray($self->data, 'SELECT sig FROM master LIMIT 1');
	return EXIT_SUCCESS if (defined($sig) && $sig eq $FILE_SIG);
	return EXIT_FAILURE;
}

sub __validateVersion {
	my ($self) = @_;
	my ($version) = $self->__selectrowArray($self->data, 'SELECT version FROM master LIMIT 1');
	# Until we reach version 1.0.0 of the package (stable release), we only accept the exact correct version of the file!
	# this gives us more flexibility to make changes.
	if (defined($version) && length($version) <= 5 && $version =~ m{ ^\d+$ }x) {
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
	# In a source checkout, do not fall through to stale installed data just because generated SQLite is absent.
	return $PATHS[0] if (-d $PATHS[0] && -d join('/', $PATHS[0], 'static'));

	foreach my $path (@PATHS) {
		if (-d $path) {
			my @sourceFiles = $self->__sourceFilesInPath($path);
			if (scalar(@sourceFiles) > 0) {
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

	croak('No cache dir available');
}

sub __bibleFileName {
	my ($self, %flags) = @_;
	my $fileName = $self->bible->translation . '.sqlite';
	$fileName .= '.gz' if ($flags{compressed});
	return $fileName;
}

sub __makeSourceCompressedPath {
	my ($self) = @_;
	my @candidates = $self->__sourceCompressedPathsForTranslation($self->bible->translation);
	return $candidates[0] if (scalar(@candidates) > 0);
	return join('/', $self->dataDir, $self->__bibleFileName(compressed => 1));
}

=item C<__makeSourceCompressedPath()>

Pick the compressed SQLite source file to use for the current translation.
The preferred order is a single-translation SQLite file first, then a
multi-translation bundle such as C<core.sqlite.gz>, and finally the
translation-specific filename as a fallback.

=cut

sub __sourceCompressedPathsForTranslation {
	my ($self) = @_;
	my $translation = $self->bible->translation;
	my @sourceFiles = $self->__sourceFilesInPath($self->dataDir);
	my @singleTranslationFiles;
	my @coreFiles;
	my @matchingFiles;
	foreach my $sourceFile (@sourceFiles) {
		my $meta = $self->__sourceMetadata->{$sourceFile} //= $self->__inspectSourceFile($sourceFile);
		next unless (exists($meta->{translations}->{$translation}));
		push(@matchingFiles, $sourceFile);
		push(@singleTranslationFiles, $sourceFile) if (scalar(keys(%{ $meta->{translations} })) == 1);
		push(@coreFiles, $sourceFile) if ($meta->{translation_count} > 1);
	}

	return @singleTranslationFiles if (scalar(@singleTranslationFiles) > 0);
	return @coreFiles if (scalar(@coreFiles) > 0);
	return @matchingFiles;
}

=item C<__sourceCompressedPathsForTranslation($translation)>

Return candidate compressed SQLite source files for a translation, ordered by
preference. Files containing only one translation are preferred over bundles
that contain multiple translations.

=cut

sub __sourceFilesInPath {
	my ($self, $path) = @_;
	my @files = sort glob(join('/', $path, '*.sqlite.gz'));
	return @files;
}

=item C<__sourceFilesInPath($path)>

Return all compressed SQLite source files in a directory, sorted
lexicographically.

=cut

sub __inspectSourceFile {
	my ($self, $sourceFile) = @_;
	my ($tempHandle, $tempPath) = tempfile(SUFFIX => '.sqlite', UNLINK => 1);
	close($tempHandle);
	gunzip $sourceFile => $tempPath
	   or die("gunzip \"" . $sourceFile . "\" failed: $GunzipError\n");

	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=${tempPath}",
		q{},
		q{},
		{
			RaiseError => 1,
			AutoCommit => 1,
		}
	);

	my $sth = $self->__prepareSelect($dbh, 'SELECT code FROM translation');
	my %translations;
	while (my ($code) = $sth->fetchrow_array()) {
		$translations{$code} = 1 if (defined($code) && length($code) > 0);
	}
	$dbh->disconnect();

	return {
		translations => \%translations,
		translation_count => scalar(keys(%translations)),
	};
}

sub __traceSelectQuery {
	my ($self, $sql, @bind) = @_;
	return;
}

sub __selectrowArray {
	my ($self, $dbh, $sql, @bind) = @_;
	$self->__traceSelectQuery($sql, @bind);
	return $dbh->selectrow_array($sql, undef, @bind);
}

sub __prepareSelect {
	my ($self, $dbh, $sql, @bind) = @_;
	$self->__traceSelectQuery($sql, @bind);
	my $sth = $dbh->prepare($sql);
	$sth->execute(@bind);
	return $sth;
}

=item C<__inspectSourceFile($sourceFile)>

Inspect a compressed SQLite source file and return cached metadata describing
the translations it contains. This is used at startup to map translations to
the best available source file without relying on filenames alone.

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
