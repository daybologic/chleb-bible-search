# Chleb Bible Search
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

package Chleb::Bible;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Digest::CRC qw(crc32);
use Readonly;
use Scalar::Util qw(looks_like_number);
use Time::HiRes ();

use Chleb::Bible::Backend;
use Chleb::Bible::DI::Container;
use Chleb::Bible::Search::Query;
use Chleb::Bible::Verse;

has __backend => (is => 'ro', isa => 'Chleb::Bible::Backend', lazy => 1, default => \&__makeBackend);

has bookCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeBookCount);

has books => (is => 'ro', isa => 'ArrayRef[Chleb::Bible::Book]', lazy => 1, default => \&__makeBooks);

has verseCount => (is => 'ro', isa => 'Int', default => 31_102); # TODO: Hard-coded 31,102: works for "kjv", "asv" (canonical)

has translation => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
	my ($self) = @_;

	# FIXME doesn't make sense now we have multiple bible translations,
	# superficially it works but will probably be highly unreliable.
	$self->dic->bible($self); # self registration

	return;
}

sub getBookByShortName {
	my ($self, $shortName, $args) = @_;

	$shortName ||= '';
	if ($shortName =~ m/^(\d)(\w+)$/) {
		$shortName = "$1\u$2";
	} else {
		$shortName = "\u$shortName";
	}

	foreach my $book (@{ $self->books }) {
		next if ($book->shortName ne $shortName);
		return $book;
	}

	my $errorMsg = "Short book name '$shortName' is not a book in the bible";
	if ($args->{nonFatal}) {
		$self->dic->logger->warn($errorMsg);
	} else {
		die($errorMsg);
	}

	return undef;
}

sub getBookByLongName {
	my ($self, $longName) = @_;

	$longName ||= '';
	foreach my $book (@{ $self->books }) {
		next if ($book->longName ne $longName);
		return $book;
	}

	die("Long book name '$longName' is not a book in the bible");
}

sub getBookByOrdinal {
	my ($self, $ordinal, $args) = @_;

	$ordinal = $self->bookCount if ($ordinal == -1);

	if ($ordinal > $self->bookCount) {
		if ($args->{nonFatal}) {
			return undef;
		} else {
			die(sprintf('Book ordinal %d out of range, there are %d books in the bible',
			    $ordinal, $self->bookCount));
		}
	}

	return $self->books->[$ordinal - 1];
}

sub getVerseByOrdinal {
	my ($self, $ordinal, $args) = @_;

	if (my $verseKey = $self->__backend->getVerseKeyByOrdinal($ordinal)) {
		my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m/:/, $verseKey, 4);
		if (my $text = $self->__backend->getVerseDataByKey($verseKey)) {
			if (my $book = $self->getBookByShortName($bookShortName, $args)) {
				my $chapter = $book->getChapterByOrdinal($chapterNumber, $args);
				return Chleb::Bible::Verse->new({
					book    => $book,
					chapter => $chapter,
					ordinal => $verseNumber,
					text    => $text,
				});
			}
		} else {
			die "I don't think you can reach this";
		}
	}

	die(sprintf("Verse %d not found in '%s'", $ordinal, $self->translation));
}

sub newSearchQuery {
	my ($self, @args) = @_;

	return Chleb::Bible::Search::Query->new({ bible => $self, text => $args[0] })
	    if (scalar(@args) == 1);

	my %params = @args;
	$params{bible} = $self;
	return $self->_library->newSearchQuery(%params);
}

sub resolveBook {
	my ($self, $book) = @_;

	unless (blessed($book)) {
		if (looks_like_number($book)) {
			$book = $self->getBookByOrdinal($book);
		} else {
			if (my $shortBook = $self->getBookByShortName($book, { nonFatal => 1 })) {
				return $shortBook;
			} else {
				$book = $self->getBookByLongName($book);
			}
		}
	}

	return $book;
}

sub fetch {
	my ($self, $book, $chapterOrdinal, $verseOrdinal) = @_;
	my $startTiming = Time::HiRes::time();

	$book = $self->resolveBook($book);
	my $chapter = $book->getChapterByOrdinal($chapterOrdinal);
	my $verse = $chapter->getVerseByOrdinal($verseOrdinal);

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));

	$self->dic->logger->debug(sprintf('%s sought in %dms', $verse->toString(), $msec));
	$verse->msec($msec);

	return $verse;
}

sub __makeBackend {
	my ($self) = @_;

	return Chleb::Bible::Backend->new({
		bible => $self,
	});
}

sub __makeBookCount {
	my ($self) = @_;
	return scalar(@{ $self->books });
}

sub __makeBooks {
	my ($self) = @_;
	return $self->__backend->getBooks();
}

sub __makeConstructionTime {
	return time();
}

1;
