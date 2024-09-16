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

package Religion::Bible::Verses;
use strict;
use warnings;
use Moose;

extends 'Religion::Bible::Verses::Base';

use Data::Dumper;
use Digest::CRC qw(crc32);
use Scalar::Util qw(looks_like_number);
use Time::HiRes ();

use Religion::Bible::Verses::Backend;
use Religion::Bible::Verses::DI::Container;
use Religion::Bible::Verses::Search::Query;
use Religion::Bible::Verses::Verse;

has __backend => (is => 'ro', isa => 'Religion::Bible::Verses::Backend', lazy => 1, default => \&__makeBackend);

has bookCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeBookCount);

has books => (is => 'ro', isa => 'ArrayRef[Religion::Bible::Verses::Book]', lazy => 1, default => \&__makeBooks);

BEGIN {
	our $VERSION = '0.7.0';
}

sub BUILD {
	my ($self) = @_;
	$self->dic->bible($self); # self registration
	return;
}

sub getBookByShortName {
	my ($self, $shortName, $unfatal) = @_;

	$shortName ||= '';
	$shortName = "\u$shortName";

	foreach my $book (@{ $self->books }) {
		next if ($book->shortName ne $shortName);
		return $book;
	}

	my $errorMsg = "Short book name '$shortName' is not a book in the bible";
	if ($unfatal) {
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

sub newSearchQuery {
	my ($self, @args) = @_;

	my %defaults = ( _library => $self, dic => $self->dic );

	return Religion::Bible::Verses::Search::Query->new({ %defaults, text => $args[0] })
	    if (scalar(@args) == 1);

	my %params = @args;
	return Religion::Bible::Verses::Search::Query->new({ %defaults, %params });
}

sub resolveBook {
	my ($self, $book) = @_;

	unless (blessed($book)) {
		if (looks_like_number($book)) {
			$book = $self->getBookByOrdinal($book);
		} else {
			if (my $shortBook = $self->getBookByShortName($book, 1)) {
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

sub votd {
	my ($self, $params) = @_;
	my $startTiming = Time::HiRes::time();
	my ($when, $version, $parental) = @{$params}{qw(when version parental)};

	$when = $self->_resolveISO8601($when);
	$when = $when->set_time_zone('UTC')->truncate(to => 'day');

	my $verse;
	for (my $offset = 0; $offset > -1; $offset++) {
		my $seed = crc32($when->epoch + $offset);
		$self->dic->logger->debug(sprintf('Looking up VoTD for %s', $when->ymd));
		$self->dic->logger->trace(sprintf('Using seed %d', $seed));

		my $bookOrdinal = 1 + ($seed % $self->bookCount);
		my $book = $self->getBookByOrdinal($bookOrdinal);

		my $chapterOrdinal = 1 + ($seed % $book->chapterCount);
		my $chapter = $book->getChapterByOrdinal($chapterOrdinal);

		my $verseOrdinal = 1 + ($seed % $chapter->verseCount);
		$verse = $chapter->getVerseByOrdinal($verseOrdinal);

		last if (!$parental || !$verse->parental);
		$self->dic->logger->debug('Skipping ' . $verse->toString() . ' because of parental mode');
	}

	$self->dic->logger->debug($verse->toString());

	my $msecAll = 0;
	# handle ARRAY verses where more than one compound Verse may be returned
	if ($version && looks_like_number($version) && $version == 2) {
		$verse = [ $verse ]; # make it an ARRAY
		my $endTiming = Time::HiRes::time();
		my $msec = int(1000 * ($endTiming - $startTiming));
		$verse->[0]->msec($msec);
		$msecAll += $msec;
		while ($verse->[-1]->continues) {
			push(@$verse, $verse->[-1]->getNext());
			$endTiming = Time::HiRes::time();
			$msec = int(1000 * ($endTiming - $startTiming));
			$verse->[-1]->msec($msec);
			$msecAll += $msec;
			$startTiming = Time::HiRes::time();
		}
	} else {
		my $endTiming = Time::HiRes::time();
		$msecAll = int(1000 * ($endTiming - $startTiming));

		$verse->msec($msecAll);
	}

	$self->dic->logger->debug(sprintf('VoTD sought in %dms', $msecAll));
	return $verse;
}

sub __makeBackend {
	my ($self) = @_;
	return Religion::Bible::Verses::Backend->new({
		_library => $self,
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

1;
