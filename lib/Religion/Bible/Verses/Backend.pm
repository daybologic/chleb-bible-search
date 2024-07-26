# Bible Query Verses Framework
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Religion::Bible::Verses::Backend;
use strict;
use warnings;
use Data::Dumper;
use English qw(-no_match_vars);
use File::Temp;
use IO::File;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use List::Util qw(sum);
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use Religion::Bible::Verses::Book;
use Storable;

Readonly my $BIBLE    => 'kjv.bin';
Readonly my $BIBLE_GZ => 'kjv.bin.gz';
Readonly my $DATA_DIR => 'data';

Readonly my $FILE_SIG     => '3aa67e06-237c-11ef-8c58-f73e3250b3f3';
Readonly my $FILE_VERSION => 7;

Readonly my $OT_COUNT => 39;

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

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has tmpPath => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeTmpPath);

has compressedPath => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeCompressedPath);

has data => (is => 'ro', isa => 'ArrayRef', lazy => 1, default => \&__makeData);

has tmpDir => (is => 'rw', isa => 'File::Temp::Dir', lazy => 1, default => \&__makeTmpDir);

sub __makeCompressedPath {
	return join('/', $DATA_DIR, $BIBLE_GZ);
}

sub __makeTmpDir {
	my ($self) = @_;

	my $tmpSubDir = ref($self);
	$tmpSubDir =~ s/::/_/g;

	my $template = join('.', $tmpSubDir, 'XXXXXXXXXX');
	if (my $dir = File::Temp->newdir($template, CLEANUP => 1, TMPDIR => 1)) {
		return $dir;
	}

	die('Cannot create temporary directory');
}

sub __makeTmpPath {
	my ($self) = @_;

	my $path = join('/', $self->tmpDir, $BIBLE);

	gunzip $self->compressedPath => $path
	   or die("gunzip \"" . $self->compressedPath . "\" failed: $GunzipError\n");

	return $path;
}

sub __makeData {
	my ($self) = @_;
	return retrieve($self->tmpPath);
}

sub BUILD {
	my ($self) = @_;
	Dumper $self->data;

	if ($self->__fsck() != EXIT_SUCCESS) {
		die(sprintf("'%s' is corrupt", $self->tmpPath));
	}

	return;
}

sub getBooks { # returns ARRAY of Religion::Bible::Verses::Book
	my ($self) = @_;

	my @books = ( );
	my $bookCount = scalar(@{ $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES] });

	for (my $bookIndex = 0; $bookIndex < $bookCount; $bookIndex++) {
		my $shortName = $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_SHORT_NAMES]->[$bookIndex];
		my $bookInfo = $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$shortName};
		my $bookOrdinal = $bookIndex + 1;
		$books[$bookIndex] = Religion::Bible::Verses::Book->new({
			_library   => $self->_library,
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

sub getVerseDataByKey {
	my ($self, $key) = @_;
	return $self->{data}->[$MAIN_OFFSET_DATA]->{$key};
}

sub getBookInfoByShortName {
	my ($self, $shortName) = @_;
	return $self->data->[$MAIN_OFFSET_BOOKS]->[$BOOK_OFFSET_BOOK_INFO]->{$shortName};
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
