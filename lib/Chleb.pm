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

package Chleb;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Type::Testament;
use Data::Dumper;
use Digest::CRC qw(crc32);
use HTTP::Status qw(:constants);
use List::Util qw(shuffle);
use Readonly;
use Scalar::Util qw(looks_like_number);
use Time::HiRes ();

use Chleb::Bible;
use Chleb::Bible::Backend;
use Chleb::Exception;
use Chleb::Bible::Search::Query;
use Chleb::Bible::Verse;
use Chleb::DI::Container;
use Chleb::Utils;

Readonly my $TRANSLATION_DEFAULT => 'kjv';

has constructionTime => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeConstructionTime);

has __bibles => (is => 'ro', isa => 'HashRef[Str]', lazy => 1, default => \&__makeBibles); # use 'bibles' to access

BEGIN {
	our $VERSION = '1.0.1';
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
		($defaults{bible}) = $self->__getBible();
		return Chleb::Bible::Search::Query->new({ %defaults, text => $args[0] })
	}

	my %params = @args;
	__fixTranslationsParam(\%params);
	($defaults{bible}) = $self->__getBible(\%params); # TODO: Needs testing, probably won't work with multiple translations
	return Chleb::Bible::Search::Query->new({ %defaults, %params });
}

sub fetch {
	my ($self, $book, $chapterOrdinal, $verseOrdinal, $args) = @_;
	my $startTiming = Time::HiRes::time();
	__fixTranslationsParam($args);

	my (@bible) = $self->__getBible($args);

	my @verse;
	for (my $bibleI = 0; $bibleI < scalar(@bible); $bibleI++) {
		if (my $resolvedBook = $bible[$bibleI]->resolveBook($book)) {
			my $chapter = $resolvedBook->getChapterByOrdinal($chapterOrdinal);
			push(@verse, $chapter->getVerseByOrdinal($verseOrdinal));
		}
	}

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));

	$self->dic->logger->debug(sprintf('%s sought in %dms', $verse[0]->toString(), $msec));

	$_->msec($msec) foreach (@verse);

	return @verse;
}

sub random { # TODO: parental?
	my ($self, $args) = @_;

	my $startTiming = Time::HiRes::time();

	my $testament = Chleb::Utils::parseIntoType(
		'Chleb::Type::Testament',
		'testament',
		$args->{testament},
		$Chleb::Type::Testament::ANY,
	);
	$self->dic->logger->trace('Looking for testament: ' . $testament->toString());

	__fixTranslationsParam($args);
	my (@bible) = $self->__getBible($args);
	@bible = shuffle(@bible);

	my $verse;
	do {
		my $verseOrdinal = 1 + rand($bible[0]->verseCount);
		$verse = $bible[0]->getVerseByOrdinal($verseOrdinal);
	} until ($self->__isTestamentMatch($verse, $testament));

	my $endTiming = Time::HiRes::time();
	my $msecAll = int(1000 * ($endTiming - $startTiming));

	$verse->msec($msecAll);
	$self->dic->logger->debug(sprintf('Random verse %s sought in %dms', $verse->toString(1), $msecAll));

	return $verse;
}

sub votd {
	my ($self, $args) = @_;
	my $startTiming = Time::HiRes::time();
	__fixTranslationsParam($args);
	my ($when, $version, $parental, $testament) = @{$args}{qw(when version parental testament)};

	$testament = Chleb::Utils::parseIntoType(
		'Chleb::Type::Testament',
		'testament',
		$testament,
		$Chleb::Type::Testament::ANY,
	);
	$self->dic->logger->trace('Looking for testament: ' . $testament->toString());

	my (@bible) = $self->__getBible($args);
	$when = $self->_resolveISO8601($when);
	$when = $when->set_time_zone('UTC')->truncate(to => 'day');

	my ($verse, $verseOrdinal);
	for (my $offset = 0; $offset > -1; $offset++) {
		my $seed = crc32($when->epoch + $offset);
		$self->dic->logger->debug(sprintf('Looking up VoTD for %s', $when->ymd));
		$self->dic->logger->trace(sprintf('Using seed %d', $seed));

		# TODO: Will this work with the Apocrypha, especially if more than one translation is specified?
		$verseOrdinal = 1 + ($seed % $bible[0]->verseCount);
		$verse = $bible[0]->getVerseByOrdinal($verseOrdinal, $args);

		next unless ($self->__isTestamentMatch($verse, $testament));

		last if (!$parental || !$verse->parental);
		$self->dic->logger->debug('Skipping ' . $verse->toString() . ' because of parental mode');
	}

	$self->dic->logger->debug($verse->toString());

	my $msecAll = 0;
	# handle ARRAY verses where more than one compound Verse may be returned
	if ($version && looks_like_number($version) && $version == 2) {
		$verse = [ $verse ]; # make it an ARRAY
		for (my $bibleTranslationOrdinal = 0; $bibleTranslationOrdinal < scalar(@bible); $bibleTranslationOrdinal++) {
			if ($bibleTranslationOrdinal > 0) {
				push(@$verse, $bible[$bibleTranslationOrdinal]->getVerseByOrdinal($verseOrdinal, $args));
			}

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
	#$translation = __getTranslation({ translation => $translation });
	($translation) = __getTranslation($translation);
	unless ($self->__bibles->{$translation}) {
		$self->__bibles->{$translation} = $self->__loadBible($translation);
	}

	return $self->__bibles->{$translation};
}

sub __getBible {
	my ($self, $args) = @_;

	my @bible = ( );
	my %real = map { $_ => 1 } __allTranslationsList();
	my @translations = __getTranslation($args);

	if (scalar(@translations) == 0) {
		@translations = __allTranslationsList();
	} else {
		foreach my $translation (@translations) {
			next if ($translation ne 'all');
			@translations = __allTranslationsList();
			last;
		}
	}

	foreach my $translation (@translations) {
		next unless ($real{$translation});
		push(@bible, $self->bibles($translation));
	}

	die Chleb::Exception->raise(HTTP_NOT_FOUND, 'No recognized bible translations')
	    if (scalar(@bible) == 0);

	return @bible;
}

sub __getTranslation {
	my ($args) = @_;

	my @translationsReturned = ( );
	return $args if ($args && ref($args) ne 'HASH');

	if (my $translations = $args->{translations}) {
		foreach my $translation (@$translations) {
			next unless (defined($translation));
			push(@translationsReturned, $translation);
		}
	}

	@translationsReturned = ($TRANSLATION_DEFAULT) if (scalar(@translationsReturned) == 0);
	return @translationsReturned;
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

sub __fixTranslationsParam {
	my ($args) = @_;

	if (my $translation = $args->{translation}) { # legacy
		if ($translation eq 'all') {
			die ("Cannot use all in 'translation', switch code to 'translations'");
		}
		$args->{translations} = [ $translation ]; # convert to new style
	}

	if (my $translations = $args->{translations}) { # new style
		TRANSLATION: foreach my $translation (@{ $args->{translations} }) {
			if ($translation eq 'all') {
				$translations = [ __allTranslationsList() ];
				last TRANSLATION;
			}
		}
		my %uniqueTranslations = map { $_ => 1 } @$translations;
		$translations = [ sort(keys(%uniqueTranslations)) ]; # ensure order is predictable
		$args->{translations} = $translations; # update after unique/sort
		$args->{translation} = $translations->[0]; # populate legacy
	}

	return;
}

sub __allTranslationsList {
	# TODO: Can we make this dynamic?  If we can, we can drop in custom translations dynamically
	return ('asv', 'kjv');
}

sub __isTestamentMatch {
	my ($self, $verse, $testament) = @_;

	return 1 if ($testament->value eq $Chleb::Type::Testament::ANY);
	return 1 if ($verse->book->testament eq $testament->value);

	$self->dic->logger->trace(sprintf(
		'Verse %s testament mismatch, wanted %s, but this is %s',
		$verse->toString(),
		$testament->toString(),
		$verse->book->testament, # TODO: use testamentFuture
	));

	return 0;
}

1;
