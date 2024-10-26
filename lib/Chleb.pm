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

package Chleb;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Data::Dumper;
use Digest::CRC qw(crc32);
use Readonly;
use Scalar::Util qw(looks_like_number);
use Time::HiRes ();

use Chleb::Bible;
use Chleb::Bible::Backend;
use Chleb::Bible::DI::Container;
use Chleb::Bible::Search::Query;
use Chleb::Bible::Verse;

Readonly my $TRANSLATION_DEFAULT => 'kjv';

has constructionTime => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeConstructionTime);

has __bibles => (is => 'ro', isa => 'HashRef[Str]', lazy => 1, default => \&__makeBibles); # use 'bibles' to access

BEGIN {
	our $VERSION = '0.10.0';
}

sub BUILD {
	my ($self) = @_;

	$self->constructionTime();

	return;
}

sub newSearchQuery {
	my ($self, @args) = @_;

	my %defaults = ( dic => $self->dic );

	if (scalar(@args) == 1) {
		$defaults{bible} = $self->__getBible();
		return Chleb::Bible::Search::Query->new({ %defaults, text => $args[0] })
	}

	my %params = @args;
	$defaults{bible} = $self->__getBible(\%params);
	return Chleb::Bible::Search::Query->new({ %defaults, %params });
}

sub fetch {
	my ($self, $book, $chapterOrdinal, $verseOrdinal, $args) = @_;
	my $startTiming = Time::HiRes::time();

	my $bible = $self->__getBible($args);

	$book = $bible->resolveBook($book);
	my $chapter = $book->getChapterByOrdinal($chapterOrdinal);
	my $verse = $chapter->getVerseByOrdinal($verseOrdinal);

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));

	$self->dic->logger->debug(sprintf('%s sought in %dms', $verse->toString(), $msec));
	$verse->msec($msec);

	return $verse;
}

sub random { # TODO: parental?
	my ($self, $args) = @_;

	my $startTiming = Time::HiRes::time();
	my $bible = $self->__getBible($args);

	my $verseOrdinal = 1 + rand($bible->verseCount);
	my $verse = $bible->getVerseByOrdinal($verseOrdinal);

	my $endTiming = Time::HiRes::time();
	my $msecAll = int(1000 * ($endTiming - $startTiming));

	$verse->msec($msecAll);
	$self->dic->logger->debug(sprintf('Random verse %s sought in %dms', $verse->toString(), $msecAll));

	return $verse;
}

sub votd {
	my ($self, $args) = @_;
	my $startTiming = Time::HiRes::time();
	my $bible = $self->__getBible($args);
	my ($when, $version, $parental) = @{$args}{qw(when version parental)};

	$when = $self->_resolveISO8601($when);
	$when = $when->set_time_zone('UTC')->truncate(to => 'day');

	my $verse;
	for (my $offset = 0; $offset > -1; $offset++) {
		my $seed = crc32($when->epoch + $offset);
		$self->dic->logger->debug(sprintf('Looking up VoTD for %s', $when->ymd));
		$self->dic->logger->trace(sprintf('Using seed %d', $seed));

		my $verseOrdinal = 1 + ($seed % $bible->verseCount);
		$verse = $bible->getVerseByOrdinal($verseOrdinal, $args);

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

sub bibles {
	my ($self, $translation) = @_;
	$translation = __getTranslation({ translation => $translation });
	unless ($self->__bibles->{$translation}) {
		$self->__bibles->{$translation} = $self->__loadBible($translation);
	}

	return $self->__bibles->{$translation};
}

sub __getBible {
	my ($self, $args) = @_;
	return $self->bibles(__getTranslation($args));
}

sub __getTranslation {
	my ($args) = @_;
	return $args if ($args && ref($args) ne 'HASH');
	return $TRANSLATION_DEFAULT unless ($args->{translation});
	return $args->{translation};
}

sub __loadBible {
	my ($self, $translation) = @_;
	return Chleb::Bible->new({
		library     => $self,
		translation => $translation,
	});
}

sub __makeConstructionTime {
	return time();
}

sub __makeBibles {
	my ($self) = @_;
	return { }; # demand-loaded to keep memory usage down
}

1;
