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

package Chleb;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Generated::Info;
use Chleb::Info;
use Chleb::Type::Testament;
use Data::Dumper;
use Digest::CRC qw(crc32);
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
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
use Carp qw(croak);

Readonly my $TRANSLATION_DEFAULT => 'kjv';

has __bibles => (is => 'ro', isa => 'HashRef[Str]', lazy => 1, default => \&__makeBibles); # use 'bibles' to access
has __availableTranslations => (is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => \&__makeAvailableTranslations);

# The release version is generated during the build.
## no critic (ValuesAndExpressions::ProhibitComplexVersion)
BEGIN {
	our $VERSION = $Chleb::Generated::Info::VERSION;
}
## use critic

sub BUILD {
	my ($self) = @_;

	# Nothing to do

	return;
}

sub newSearchQuery {
	my ($self, @args) = @_;

	my %defaults = ( dic => $self->dic );

	if (scalar(@args) == 1) {
		($defaults{bible}) = $self->__getBible();
		return Chleb::Bible::Search::Query->new({ %defaults, text => Chleb::Utils::SecureString->new({ value => $args[0] }) })
	}

	my %params = @args;
	$self->__fixTranslationsParam(\%params);

	$params{text} = __ensureSecureString($params{text});

	($defaults{bible}) = $self->__getBible(\%params); # TODO: Needs testing, probably won't work with multiple translations
	return Chleb::Bible::Search::Query->new({ %defaults, %params });
}

sub fetch {
	my ($self, $book, $chapterOrdinal, $verseOrdinal, $args) = @_;
	my $startTiming = Time::HiRes::time();
	$self->__fixTranslationsParam($args);

	my (@bible) = $self->__getBible($args);

	my @verse;
	for (my $bibleI = 0; $bibleI < scalar(@bible); $bibleI++) {
		my $resolvedBook;
		my $resolvedOk = eval {
			$resolvedBook = $bible[$bibleI]->resolveBook($book);
			1;
		};
		next unless ($resolvedOk && $resolvedBook);
		if ($resolvedBook) {
			my $chapter = $resolvedBook->getChapterByOrdinal($chapterOrdinal);
			if ($verseOrdinal) { # want a specific verse?
				push(@verse, $chapter->getVerseByOrdinal($verseOrdinal));
			} else { # want all of the verses
				push(@verse, @{ $chapter->getVerses() });
			}
		}
	}

	croak(Chleb::Exception->raise(HTTP_NOT_FOUND, "Book '$book' was not found in any requested translation"))
	    if (scalar(@verse) == 0);

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));

	$self->dic->logger->debug(sprintf('%s sought in %dms', $verse[0]->toString(), $msec));

	$_->msec($msec) foreach (@verse);

	return @verse;
}

sub info {
	my ($self) = @_;

	my $startTiming = Time::HiRes::time();

	my (@bible) = $self->__getBible({ translations => ['all'] });

	my $info = Chleb::Info->new({
		bibles => \@bible,
	});

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));

	$info->msec($msec);
	$self->dic->logger->debug(sprintf('Info %s sought in %dms', $info->toString(), $msec));

	return $info;
}

=head1 availableTranslations()

Return the translation codes discovered from the available SQLite source data.

=cut

sub availableTranslations {
	my ($self) = @_;
	return @{ $self->__availableTranslations };
}

sub random {
	my ($self, $args) = @_;

	my $startTiming = Time::HiRes::time();

	$self->__fixTranslationsParam($args);
	my ($version, $parental, $testament) = @{$args}{qw(version parental testament)};

	$testament = Chleb::Utils::parseIntoType(
		'Chleb::Type::Testament',
		'testament',
		$testament,
		$Chleb::Type::Testament::ANY,
	);
	$self->dic->logger->trace('Looking for testament: ' . $testament->toString());

	my (@bible) = $self->__getBible($args);

	my ($verse, $verseOrdinal, @verses);
	my $seed = rand($PID + $bible[0]->verseCount);
	for (my $offset = 0; $offset > -1; $offset++) {
		$seed = crc32($seed + $offset);
		$self->dic->logger->trace(sprintf('Using seed %d', $seed));

		# TODO: Will this work with the Apocrypha, especially if more than one translation is specified?
		$verseOrdinal = 1 + ($seed % $bible[0]->verseCount);
		$verse = $bible[0]->getVerseByOrdinal($verseOrdinal, $args);
		my $verseAvailable = 1;
		@verses = ($verse);
		for (my $candidateI = 1; $candidateI < scalar(@bible); $candidateI++) {
			my $candidateBible = $bible[$candidateI];
			my $candidateVerse = $self->__getRelatedRandomVerse($candidateBible, $verse, $verseOrdinal, $args);
			unless ($candidateVerse) {
				$verseAvailable = 0;
				last;
			}
			push(@verses, $candidateVerse);
		}
		next unless ($verseAvailable);

		next unless ($self->__isTestamentMatch($verse, $testament));

		last if (!$parental || !$verse->parental);
		$self->dic->logger->debug('Skipping ' . $verse->toString() . ' because of parental mode');
	}

	$self->dic->logger->debug($verse->toString());

	my $msecAll = 0;
	# handle ARRAY verses where more than one compound Verse may be returned
	if ($version && looks_like_number($version) && $version == 2) {
		my @expandedVerses;
		for (my $bibleTranslationOrdinal = 0; $bibleTranslationOrdinal < scalar(@bible); $bibleTranslationOrdinal++) {
			my $translationVerse = $verses[$bibleTranslationOrdinal];
			push(@expandedVerses, $translationVerse);
			my $endTiming = Time::HiRes::time();
			my $msec = int(1000 * ($endTiming - $startTiming));
			$translationVerse->msec($msec);
			$msecAll += $msec;

			while ($translationVerse->continues) {
				$translationVerse = $translationVerse->getNext();
				push(@expandedVerses, $translationVerse);
				$endTiming = Time::HiRes::time();
				$msec = int(1000 * ($endTiming - $startTiming));
				$translationVerse->msec($msec);
				$msecAll += $msec;
				$startTiming = Time::HiRes::time();
			}

			$startTiming = Time::HiRes::time();
		}
		$verse = \@expandedVerses;
	} else {
		my $endTiming = Time::HiRes::time();
		$msecAll = int(1000 * ($endTiming - $startTiming));

		$verse->msec($msecAll);
	}

	$self->dic->logger->debug(sprintf(
		'Random verse %s sought in %dms',
		(ref($verse) eq 'ARRAY') ? $verse->[0]->toString(1) : $verse->toString(1),
		$msecAll,
	));

	return $verse;
}

sub votd {
	my ($self, $args) = @_;

	my $startTiming = Time::HiRes::time();

	$self->__fixTranslationsParam($args);
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

	my ($verse, $verseOrdinal, @verses);
	for (my $offset = 0; $offset > -1; $offset++) {
		my $seed = crc32($when->epoch + $offset);
		$self->dic->logger->debug(sprintf('Looking up VoTD for %s', $when->ymd));
		$self->dic->logger->trace(sprintf('Using seed %d', $seed));

		# TODO: Will this work with the Apocrypha, especially if more than one translation is specified?
		$verseOrdinal = 1 + ($seed % $bible[0]->verseCount);
		$verse = $bible[0]->getVerseByOrdinal($verseOrdinal, $args);
		next unless ($self->__isTestamentMatch($verse, $testament));

		if ($parental && $verse->parental) {
			$self->dic->logger->debug('Skipping ' . $verse->toString() . ' because of parental mode');
			next;
		}

		while ($verse->previous && $verse->previous->continues) {
			# look upwards until we are not on a continuation, to give increased context
			$verse = $verse->previous;
		}

		my $verseAvailable = 1;
		@verses = ($verse);
		for (my $candidateI = 1; $candidateI < scalar(@bible); $candidateI++) {
			my $candidateBible = $bible[$candidateI];
			my $candidateVerse = $self->__getRelatedRandomVerse($candidateBible, $verse, $verseOrdinal, $args);
			unless ($candidateVerse) {
				$verseAvailable = 0;
				last;
			}
			push(@verses, $candidateVerse);
		}
		last if ($verseAvailable);
	}

	$self->dic->logger->debug($verse->toString());

	my $msecAll = 0;
	# handle ARRAY verses where more than one compound Verse may be returned
	if ($version && looks_like_number($version) && $version == 2) {
		my @expandedVerses;
		for (my $bibleTranslationOrdinal = 0; $bibleTranslationOrdinal < scalar(@bible); $bibleTranslationOrdinal++) {
			my $translationVerse = $verses[$bibleTranslationOrdinal];
			push(@expandedVerses, $translationVerse);
			my $endTiming = Time::HiRes::time();
			my $msec = int(1000 * ($endTiming - $startTiming));
			$translationVerse->msec($msec);
			$msecAll += $msec;

			while ($translationVerse->continues) {
				$translationVerse = $translationVerse->getNext();
				push(@expandedVerses, $translationVerse);
				$endTiming = Time::HiRes::time();
				$msec = int(1000 * ($endTiming - $startTiming));
				$translationVerse->msec($msec);
				$msecAll += $msec;
				$startTiming = Time::HiRes::time() unless (defined($startTiming));
			}

			$startTiming = Time::HiRes::time() unless (defined($startTiming));
		}
		$verse = \@expandedVerses;
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

sub getBibles {
	my ($self, $args) = @_;
	return $self->__getBible($args);
}

=head1 PRIVATE METHODS

=over

=cut

sub __getBible {
	my ($self, $args) = @_;

	my @bible = ( );
	my %real = map { $_ => 1 } $self->__allTranslationsList();
	my @translations = __getTranslation($args);

	if (scalar(@translations) == 0) {
		@translations = $self->__allTranslationsList();
	} else {
		foreach my $translation (@translations) {
			next if ($translation ne 'all');
			@translations = $self->__allTranslationsList();
			last;
		}
	}

	foreach my $translation (@translations) {
		next unless ($real{$translation});
		push(@bible, $self->bibles($translation));
	}

	croak(Chleb::Exception->raise(HTTP_NOT_FOUND, 'No recognized bible translations'))
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

sub __makeBibles {
	my ($self) = @_;
	return { }; # demand-loaded to keep memory usage down
}

sub __fixTranslationsParam {
	my ($self, $args) = @_;

	if (my $translation = $args->{translation}) { # legacy
		if ($translation eq 'all') {
		croak("Cannot use all in 'translation', switch code to 'translations'");
		}
		$args->{translations} = [ $translation ]; # convert to new style
	}

	if (my $translations = $args->{translations}) { # new style
		TRANSLATION: foreach my $translation (@{ $args->{translations} }) {
			if ($translation eq 'all') {
				$args->{__translationsAll} = 1;
				$translations = [ $self->__allTranslationsList() ];
				last TRANSLATION;
			}
		}
		my %seenTranslation;
		my @uniqueTranslations = grep { !$seenTranslation{$_}++ } @$translations;
		$translations = \@uniqueTranslations; # remove duplicates while preserving order
		$args->{translations} = $translations;
		$args->{translation} = $translations->[0]; # populate legacy
	}

	return;
}

sub __allTranslationsList {
	my ($self) = @_;
	return @{ $self->__availableTranslations };
}

sub __makeAvailableTranslations {
	my ($self) = @_;
	my $bible = $self->bibles($TRANSLATION_DEFAULT);
	return [ $bible->__backend->getAvailableTranslations() ];
}

=item C<__getRelatedRandomVerse($bible, $anchorVerse, $verseOrdinal, $args)>

Return the corresponding random verse from another translation.  Translations
which contain the anchor book use its chapter and verse reference; translations
with a different canon fall back to their own verse ordinal.

=cut

sub __getRelatedRandomVerse {
	my ($self, $bible, $anchorVerse, $verseOrdinal, $args) = @_;

	my $book = $bible->getBookByShortName($anchorVerse->book->shortName, { nonFatal => 1 });
	if ($book) {
		my $chapter = $book->getChapterByOrdinal($anchorVerse->chapter->ordinal, { nonFatal => 1 });
		return if (!$chapter);
		return $chapter->getVerseByOrdinal($anchorVerse->ordinal, { nonFatal => 1 });
	}

	return if ($bible->verseCount < $verseOrdinal);
	return $bible->getVerseByOrdinal($verseOrdinal, $args);
}

sub __isTestamentMatch {
	my ($self, $verse, $testament) = @_;

	return 1 if ($testament->value eq $Chleb::Type::Testament::ANY);
	return 1 if ($verse->book->testament->equals($testament));

	$self->dic->logger->trace(sprintf(
		'Verse %s testament mismatch, wanted %s, but this is %s',
		$verse->toString(),
		$testament->toString(),
		$verse->book->testament->toString(),
	));

	return 0;
}

sub __ensureSecureString {
	my ($input) = @_;

	if (!defined($input) || ref($input) ne 'Chleb::Utils::SecureString') {
		return Chleb::Utils::SecureString->new({ value => $input });
	}

	return $input;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
