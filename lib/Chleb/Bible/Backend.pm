# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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
use List::Util qw(sum);
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use Chleb::Bible::Book;
use Chleb::Type::Testament;
use Storable;

Readonly my $FILE_SIG     => '3aa67e06-237c-11ef-8c58-f73e3250b3f3';
Readonly my $FILE_VERSION => 12;

Readonly my $OT_COUNT => 39;

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

has bible => (is => 'ro', isa => 'Chleb::Bible', required => 1);

has compressedPath => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeCompressedPath);

has data => (is => 'ro', isa => 'ArrayRef', lazy => 1, default => \&__makeData);

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

	unless (-f $path) {
		gunzip $self->compressedPath => $path
		   or die("gunzip \"" . $self->compressedPath . "\" failed: $GunzipError\n");
	}

	return $path;
}

sub __makeData {
	my ($self) = @_;

	my $data;
	eval {
		$data = retrieve($self->cachePath);
	};

	if (my $evalError = $EVAL_ERROR) {
		$self->dic->logger->error("Storable backend failure -- probably not a bible data file in '" . $self->cachePath . "'");
		die($evalError);
	}

	return $data;
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
	my $bookCount = scalar(@{ $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES] });

	for (my $bookIndex = 0; $bookIndex < $bookCount; $bookIndex++) {
		my $shortNameRaw = $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES]->[$bookIndex];
		my $bookInfo = $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$shortNameRaw};
		my $bookOrdinal = $bookIndex + 1;
		$books[$bookIndex] = Chleb::Bible::Book->new({
			bible      => $self->bible,
			ordinal    => $bookOrdinal,
			shortNameRaw => $shortNameRaw,
			longName   => $bookInfo->{n},
			chapterCount => $bookInfo->{c},
			verseCount => sum(values(%{ $bookInfo->{v} })),
			testament => Chleb::Type::Testament->createFromBackendValue($bookInfo->{t}),
		});
	}

	return \@books;
}

sub getOrdinalByVerseKey {
	my ($self, $key) = @_;
	return $self->data->[$MAIN_OFFSET_VERSE_KEYS_TO_ABSOLUTE_ORDINALS]->{$key} // 0;
}

sub getVerseKeyByOrdinal {
	my ($self, $ordinal) = @_;
	return $self->data->[$MAIN_OFFSET_VERSES]->[$ordinal];
}

sub getVerseDataByKey {
	my ($self, $key) = @_;
	return $self->{data}->[$MAIN_OFFSET_DATA]->{$key};
}

sub getVerseKeyByBookVerseKey {
	my ($self, $key) = @_;
	return $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_VERSES_TO_KEYS]->{$key};
}

sub getBookInfoByShortName {
	my ($self, $shortNameRaw) = @_;
	return $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$shortNameRaw};
}

sub getSentimentByOrdinal {
	my ($self, $ordinal) = @_;

	if ($ordinal == 0) { # TODO: trap boundaries?
		return {
			emotion => 'neutral',
			tones => [ ],
		};
	}

	return {
		emotion => $self->data->[$MAIN_OFFSET_EMOTION]->[$ordinal],
		tones   => [ sort @{ $self->data->[$MAIN_OFFSET_TONES]->[$ordinal] } ],
	};
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
	my $sig = $self->data->[$MAIN_OFFSET_SIG];
	return EXIT_SUCCESS if (defined($sig) && $sig eq $FILE_SIG);
	return EXIT_FAILURE;
}

sub __validateVersion {
	my ($self) = @_;
	my $version = $self->data->[$MAIN_OFFSET_VERSION];
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
	my $fileName = join('.', $self->bible->translation, 'bin');
	$fileName .= '.gz' if ($flags{compressed});
	return $fileName;
}

__PACKAGE__->meta->make_immutable;

1;
