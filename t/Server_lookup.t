#!/usr/bin/env perl
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

package LookupServerTests;
## no critic (RegularExpressions::ProhibitComplexRegexes)
## no critic (RegularExpressions::RequireExtendedFormatting)
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
## no critic (BuiltinFunctions::ProhibitUniversalIsa)
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use English qw(-no_match_vars);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Storable qw(dclone);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server::Dancer2;
use Chleb::Server::Moose;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server::Moose->new());

	return EXIT_SUCCESS;
}

sub test_translation_all {
	my ($self) = @_;
	plan tests => 2;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__lookup({ accept => $mediaType, book => 'Psalms', chapter => 110, verse => 1, translations => [ 'all' ] });
	my @translations = sort map { $_->{data}->[0]->{attributes}->{translation} } @{$json};
	is_deeply(\@translations, [qw(asv dr kjv)], 'all compatible translations are returned');
	my @legacyExpectedTranslations = map { dclone($_) } grep {
		$_->{data}->[0]->{attributes}->{translation} ne 'dr'
	} @{$json};
	for my $response (@legacyExpectedTranslations) {
		$response->{data} = [ grep {
			$_->{attributes}->{translation} ne 'dr'
		} @{ $response->{data} } ];
		$response->{included} = [ grep {
			!defined($_->{attributes})
				|| !defined($_->{attributes}->{translation})
				|| $_->{attributes}->{translation} ne 'dr'
		} @{ $response->{included} } ];
	}
	cmp_deeply(\@legacyExpectedTranslations, [
		{
			data => [
				{
					attributes => {
						book => 'psa',
						chapter => 110,
						emotion => 'hope',
						ordinal => 1,
						text => 'Jehovah saith unto my Lord, Sit thou at my right hand, Until I make thine enemies thy footstool.',
						tones => ['encouragement','trust'],
						year => 1901,
						translation => 'asv',
					},
					id => 'asv/psa/110/1',
					type => 'verse',
					links => {
						first => '/1/lookup/psa/110/1?translations=all',
						prev  => '/1/lookup/psa/109/31?translations=asv',
						self  => '/1/lookup/psa/110/1?translations=asv',
						next  => '/1/lookup/psa/110/2?translations=asv',
						last  => '/1/lookup/psa/110/7?translations=all',
					},
					relationships => {
						book => {
							data => {
								id => 'asv/psa',
								type => 'book',
							},
							links => {},
						},
						chapter => {
							data => {
								id => 'asv/psa/110',
								type => 'chapter',
							},
							links => {},
						}
					},
				},
				{
					attributes => {
						book => 'psa',
						chapter => 110,
						emotion => 'hope',
						ordinal => 1,
						text => 'A Psalm of David. The LORD said unto my Lord, Sit thou at my right hand, until I make thine enemies thy footstool.',
						tones => ['encouragement','trust'],
						year => 1611,
						translation => 'kjv',
					},
					id => 'kjv/psa/110/1',
					type => 'verse',
					links => {
						first => '/1/lookup/psa/110/1?translations=all',
						prev  => '/1/lookup/psa/109/31?translations=kjv',
						self  => '/1/lookup/psa/110/1?translations=kjv',
						next  => '/1/lookup/psa/110/2?translations=kjv',
						last  => '/1/lookup/psa/110/7?translations=all',
					},
					relationships => {
						book => {
							data => {
								id => 'kjv/psa',
								type => 'book',
							},
							links => {},
						},
						chapter => {
							data => {
								id => 'kjv/psa/110',
								type => 'chapter',
							},
							links => {},
						}
					},
				},
			],
			included => [
				{
					attributes => {
						book => ignore(),
						ordinal => re(qr/^\d{1,3}$/),
						translation => 'asv',
						verse_count => 7,
					},
					id => re(qr@^\w{3}/\w+/\d{1,3}$@),
					type => 'chapter',
					relationships => {
						book => {
							data => {
								id => ignore(),
								type => 'book',
							},
						},
					},
				},
				{
					attributes => {
						canonical_code => 'Psa',
						chapter_count => 150,
						long_name => 'Psalms',
						ordinal => re(qr/^\d{1,2}$/),
						sample_verse_text => ignore(),
						sample_verse_chapter_ordinal => ignore(),
						sample_verse_ordinal_in_chapter => ignore(),
						short_name => 'psa',
						short_name_raw => 'Psa',
						testament => re(qr/^\w{3}$/),
						translation => 'asv',
						verse_count => 2_461,
					},
					id => ignore(),
					relationships => {},
					type => 'book'
				},
				{
					attributes => {
						msec => re(qr/^\d+$/),
					},
					id => ignore(), # uuid
					type => 'stats',
					links => {},
				},
			],
			links => {
				first => '/1/lookup/psa/110/1?translations=all',
				prev  => '/1/lookup/psa/109/31?translations=all',
				self  => '/1/lookup/psa/110/1?translations=all',
				next  => '/1/lookup/psa/110/2?translations=all',
				last  => '/1/lookup/psa/110/7?translations=all',
			},
		},
		{
			data => [
				{
					attributes => {
						book => 'psa',
						chapter => 110,
						emotion => 'hope',
						ordinal => 1,
						text => 'A Psalm of David. The LORD said unto my Lord, Sit thou at my right hand, until I make thine enemies thy footstool.',
						tones => ['encouragement','trust'],
						year => 1611,
						translation => 'kjv',
					},
					id => 'kjv/psa/110/1',
					type => 'verse',
					links => {
						first => '/1/lookup/psa/110/1?translations=all',
						prev  => '/1/lookup/psa/109/31?translations=kjv',
						self  => '/1/lookup/psa/110/1?translations=kjv',
						next  => '/1/lookup/psa/110/2?translations=kjv',
						last  => '/1/lookup/psa/110/7?translations=all',
					},
					relationships => {
						book => {
							data => {
								id => 'kjv/psa',
								type => 'book',
							},
							links => {},
						},
						chapter => {
							data => {
								id => 'kjv/psa/110',
								type => 'chapter',
							},
							links => {},
						}
					},
				},
			],
			included => [
				{
					attributes => {
						book => ignore(),
						ordinal => re(qr/^\d{1,3}$/),
						translation => 'kjv',
						verse_count => 7,
					},
					id => re(qr@^\w{3}/\w+/\d{1,3}$@),
					type => 'chapter',
					relationships => {
						book => {
							data => {
								id => ignore(),
								type => 'book',
							},
						},
					},
				},
				{
					attributes => {
						canonical_code => 'Psa',
						chapter_count => 150,
						long_name => 'Psalms',
						ordinal => re(qr/^\d{1,2}$/),
						sample_verse_text => ignore(),
						sample_verse_chapter_ordinal => ignore(),
						sample_verse_ordinal_in_chapter => ignore(),
						short_name => 'psa',
						short_name_raw => 'Psa',
						testament => re(qr/^\w{3}$/),
						translation => 'kjv',
						verse_count => 2_461,
					},
					id => ignore(),
					relationships => {},
					type => 'book'
				},
				{
					attributes => {
						msec => re(qr/^\d+$/),
					},
					id => ignore(), # uuid
					type => 'stats',
					links => {},
				},
			],
			links => {
				self  => '/1/lookup/psa/110/1?translations=all',
			},
		},
	], 'single random verse JSON');

	return EXIT_SUCCESS;
}

sub testTranslationSpecificBookInfo {
	my ($self) = @_;
	plan tests => 2;

	my $dr = $self->sut->__library->bibles('dr');
	my $esther = $dr->getBookByShortName('Est');
	is($esther->chapterCount, 16, 'DR Esther has sixteen chapters');
	is($esther->getChapterByOrdinal(11)->verseCount, 12, 'DR Esther chapter eleven has its verse count');

	return EXIT_SUCCESS;
}

sub testWarmupPrimesSentimentCache {
	my ($self) = @_;
	plan tests => 11;

	my $dic = Chleb::DI::Container->instance();
	my $previousLogger = $dic->logger;
	my $logger = Chleb::DI::MockLogger->new();
	$dic->logger($logger);

	$self->sut->__warmBackendCaches();

	my $before = scalar(keys(%{ $self->sut->__library->bibles('kjv')->__backend->__sentimentCache }));
	my $bookInfoBefore = scalar(grep { /\QSELECT book.id, book.code, book.short_name, book.short_name_raw, book.long_name, book.testament, book.chapter_count FROM book WHERE book.translation = ? AND book.code = ?\E/ } @{ $logger->__messages });
	my $verseCountBefore = scalar(grep { /\QSELECT chapter.ordinal, COUNT(verse.id) AS verse_count FROM chapter LEFT JOIN verse ON verse.chapter_id = chapter.id WHERE chapter.book_id = ? GROUP BY chapter.id ORDER BY chapter.ordinal\E/ } @{ $logger->__messages });
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	$self->sut->__lookup({
		accept => $mediaType,
		book => 'Acts',
		chapter => 2,
		verse => 1,
	});
	my $after = scalar(keys(%{ $self->sut->__library->bibles('kjv')->__backend->__sentimentCache }));
	my $bookInfoAfter = scalar(grep { /\QSELECT book.id, book.code, book.short_name, book.short_name_raw, book.long_name, book.testament, book.chapter_count FROM book WHERE book.translation = ? AND book.code = ?\E/ } @{ $logger->__messages });
	my $verseCountAfter = scalar(grep { /\QSELECT chapter.ordinal, COUNT(verse.id) AS verse_count FROM chapter LEFT JOIN verse ON verse.chapter_id = chapter.id WHERE chapter.book_id = ? GROUP BY chapter.id ORDER BY chapter.ordinal\E/ } @{ $logger->__messages });
	my $translationWarmupFinished = scalar(grep { /\QBackend cache warmup finished for translation kjv in\E \d+ \Qmsec\E/ } @{ $logger->__messages });
	my $asvWarmupFinished = scalar(grep { /\QBackend cache warmup finished for translation asv in\E \d+ \Qmsec\E/ } @{ $logger->__messages });
	my $allWarmupFinished = scalar(grep { /\QAll backend cache warmup finished in\E \d+ \Qmsec\E/ } @{ $logger->__messages });
	my $translationWarmupProgress = scalar(grep { /\QBackend cache warmup \E\d+\Q% complete (translation \E(?:kjv|asv)\Q)\E\z/ } @{ $logger->__messages });
	my $verseWarmupProgress = scalar(grep { /\QBackend cache warmup \E\d+\Q% complete (translation \E(?:kjv|asv)\Q, book \E/ } @{ $logger->__messages });
	my $sentimentTiming = scalar(grep { /sentiment finished for translation kjv in \d+ msec/ } @{ $logger->__messages });
	my $sharedFlushTiming = scalar(grep { /shared-cache flush finished for translation kjv in \d+ msec/ } @{ $logger->__messages });

	ok($before > 0, 'warmup loads sentiment data');
	is($after, $before, 'lookup does not reload sentiment after warmup');
	is($bookInfoAfter, $bookInfoBefore, 'lookup does not reload book info after warmup');
	is($verseCountAfter, $verseCountBefore, 'lookup does not reload verse counts after warmup');
	ok($translationWarmupFinished > 0, 'warmup logs per-translation msec');
	ok($asvWarmupFinished > 0, 'warmup logs ASV');
	ok($allWarmupFinished > 0, 'warmup logs overall msec');
	is($translationWarmupProgress, 0, 'warmup does not traverse every verse');
	is($verseWarmupProgress, 0, 'warmup progress does not identify the verse');
	ok($sentimentTiming > 0, 'warmup logs sentiment timing');
	is($sharedFlushTiming, 0, 'warmup does not flush the shared cache');

	$dic->logger($previousLogger);

	return EXIT_SUCCESS;
}

sub test_not_found {
	my ($self) = @_;
	plan tests => 1;

	my $evalOk1; $evalOk1 = eval {
		$self->sut->__lookup({ book => 'Acts', chapter => 29, verse => 1, translations => [ 'kjv' ] });
		1;
	} or $evalOk1 = 0;

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => 'Chapter 29 not found in Acts',
				location    => undef,
				statusCode  => 404,
			),
		), 'correctly not found');
	} else {
		fail('No exception raised, as was expected');
	}

	return EXIT_SUCCESS;
}

sub testHtmlListsTranslationsSeparately {
	my ($self) = @_;
	plan tests => 11;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = $self->sut->__lookup({
		accept => $mediaType,
		book => 'Matthew',
		chapter => 22,
		verse => 14,
		translations => [ 'kjv', 'asv' ],
	});

	my @translations = $html =~ m{<div class="translation">([^<]+)</div>}g;
	my @cards = split(m{<div class="card">}, $html);
	shift(@cards);

	is(scalar(@cards), 2, 'each translation has its own card');
	is_deeply(\@translations, [ 'kjv (1611)', 'asv (1901)' ], 'each translation has its requested label order');
	like($cards[0], qr{<div class="translation">kjv \(1611\)</div>}s, 'KJV label is in the first card');
	like($cards[0], qr{<a href="/1/lookup/mat/1\?translations=kjv">Mat</a>}, 'book name links to its first chapter');
	like($cards[0], qr{<a href="/1/lookup/mat/22\?translations=kjv">22</a>}, 'chapter number links to its chapter');
	like($cards[0], qr{<a href="/1/lookup/mat/22/14\?translations=kjv">14</a>}, 'verse number links to its verse');
	like($cards[0], qr{<blockquote>\s*For many are called, but few \[are\] chosen\.\s*</blockquote>}s, 'KJV text is in the first card');
	like($cards[0], qr{<span class="tag tag-color-\d+">neutral</span>\s*</blockquote>}s, 'KJV sentiments are in the first card');
	like($cards[1], qr{<div class="translation">asv \(1901\)</div>}s, 'ASV label is in the second card');
	like($cards[1], qr{<blockquote>\s*For many are called, but few chosen\.\s*</blockquote>}s, 'ASV text is in the second card');
	like($cards[1], qr{<span class="tag tag-color-\d+">neutral</span> <span class="tag tag-color-\d+">instruction</span>}s, 'ASV sentiments are in the second card');

	return EXIT_SUCCESS;
}

sub testHtmlVerseRangeRendersAsContinuation {
	my ($self) = @_;
	plan tests => 4;

	my @verses = $self->sut->__library->fetch('Genesis', 38, '9-10', { translations => ['kjv'] });
	is(scalar(@verses), 2, 'verse range fetches both requested verses');
	ok(!$verses[0]->continues && !$verses[1]->continues,
		'verse range does not alter Verse continuation state');

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = $self->sut->__lookup({
		accept => $mediaType,
		book => 'gen',
		chapter => 38,
		verse => '9-10',
		translations => ['kjv'],
	});
	like($html, qr{versenum.*?/1/lookup/gen/38/10\?translations=kjv">10 </a>}s,
		'HTML includes the second verse number in the same card');
	unlike($html, qr{</blockquote>\s*<br /><br />\s*<sup class="versenum"}x,
		'HTML renders the selected range as a continuation');

	return EXIT_SUCCESS;
}

sub testVerseRangeUnitScenarios {
	my ($self) = @_;
	plan tests => 6;

	my $htmlMediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $jsonMediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my %common = (
		book => 'gen',
		chapter => 38,
		translations => ['kjv'],
	);

	my $html = $self->sut->__lookup({ %common, accept => $htmlMediaType, verse => '9-10' });
	like($html, qr{versenum.*?/1/lookup/gen/38/10\?translations=kjv">10 </a>}s,
		'unit HTML range includes the second verse');

	my $json = $self->sut->__lookup({ %common, accept => $jsonMediaType, verse => '9-10' });
	is_deeply(
		[ map { $_->{attributes}->{ordinal} } @{ $json->[0]->{data} } ],
		[9, 10],
		'unit JSON range includes both verse ordinals',
	);

	foreach my $mediaType ($htmlMediaType, $jsonMediaType) {
		my $error;
		eval {
			$self->sut->__lookup({ %common, accept => $mediaType, verse => '10-9' });
			1;
		} or $error = $EVAL_ERROR;
		isa_ok($error, 'Chleb::Exception', 'reversed range raises a Chleb exception');
		is($error->statusCode, 400, 'reversed range raises HTTP 400 Bad Request');
	}

	return EXIT_SUCCESS;
}

sub testHtmlPreservesReversedTranslationInput {
	my ($self) = @_;
	plan tests => 1;

	my @verse = (
		$self->sut->__library->fetch('Matthew', 22, 14, { translations => ['kjv'] }),
		$self->sut->__library->fetch('Matthew', 22, 14, { translations => ['asv'] }),
	);
	my $cache = { };
	my @json = map {
		Chleb::Server::Moose::__verseToJsonApi($_, { translations => ['all'] }, $cache)
	} @verse;
	push(@{ $json[0]->{data} }, $json[1]->{data}->[0]);
	$json[0]->{links}->{self} = '/1/lookup/mat/22/14?translations=all';

	my $html = $self->sut->__verseToHtml(\@verse, \@json, 3);
	my @translations = $html =~ m{<div class="translation">([^<]+)</div>}g;

	is_deeply(\@translations, [ 'kjv (1611)', 'asv (1901)' ], 'HTML preserves reversed renderer input');

	return EXIT_SUCCESS;
}

sub testHtmlOffersAllTranslationsNavigation {
	my ($self) = @_;
	plan tests => 3;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = $self->sut->__lookup({
		accept => $mediaType,
		book => 'neh',
		chapter => 2,
		verse => 1,
		translations => ['asv'],
	});

	like($html, qr{<a[ ]class="vn-link[ ]vn-verse"[ ]href="/1/lookup/neh/2/1\?translations=all">all[ ]translations</a>}x,
		'lookup navigation links to all translations');
	like($html, qr{random</a>.*?all[ ]translations</a>.*?permalink</a>}xs,
		'all translations appears between random and permalink in primary navigation');
	like($html, qr{<a class="vn-link vn-verse" href="/2/votd\?translations=asv">votd</a>},
		'lookup navigation links to standalone VoTD with selected translations');

	return EXIT_SUCCESS;
}

sub testHtmlDisablesCurrentChapterAtFirstVerse {
	my ($self) = @_;
	plan tests => 4;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = $self->sut->__lookup({
		accept => $mediaType,
		book => 'gen',
		chapter => 2,
		verse => 1,
		translations => ['kjv'],
	});

	like($html, qr{<span class="vn-link vn-chapter vn-disabled" aria-disabled="true">this chapter</span>},
		'any chapter first verse HTML visibly disables the current chapter link');
	unlike($html, qr{<a class="vn-link vn-chapter" href="/1/lookup/gen/2">this chapter</a>},
		'any chapter first verse HTML does not link to the current chapter');
	like($html, qr{<span class="vn-link vn-verse vn-disabled" aria-disabled="true">first verse</span>},
		'any chapter first verse HTML visibly disables the first verse control');
	unlike($html, qr{<a class="vn-link vn-verse" href="/1/lookup/gen/2/1">first verse</a>},
		'any chapter first verse HTML does not link to the current first verse');

	return EXIT_SUCCESS;
}

sub testHtmlDisablesFirstChapterOnChapterOne {
	my ($self) = @_;
	plan tests => 2;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = $self->sut->__lookup({
		accept => $mediaType,
		book => 'gen',
		chapter => 1,
		verse => 2,
		translations => ['kjv'],
	});

	like($html, qr{<span class="vn-link vn-book vn-disabled" aria-disabled="true">first chapter</span>},
		'chapter one HTML visibly disables the first chapter control');
	unlike($html, qr{<a class="vn-link vn-book" href="/1/lookup/gen/1">first chapter</a>},
		'chapter one HTML does not link to the first chapter');

	return EXIT_SUCCESS;
}

sub testHtmlDisablesLastVerseAtChapterEnd {
	my ($self) = @_;
	plan tests => 2;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = $self->sut->__lookup({
		accept => $mediaType,
		book => 'gen',
		chapter => 1,
		verse => 31,
		translations => ['kjv'],
	});

	like($html, qr{<span class="vn-link vn-verse vn-disabled" aria-disabled="true">last verse</span>},
		'last verse HTML visibly disables the last verse control');
	unlike($html, qr{<a class="vn-link vn-verse" href="/1/lookup/gen/1/31">last verse</a>},
		'last verse HTML does not link to the current last verse');

	return EXIT_SUCCESS;
}

sub testHtmlBookSelectorUsesCurrentTranslation {
	my ($self) = @_;
	plan skip_all => 'Pickthall test data is not installed' unless $self->hasTranslation('pickthall');
	plan tests => 9;

	my ($verse) = $self->sut->__library->fetch('Quran', 1, 1, { translations => ['pickthall'] });
	my $cache = { };
	my $json = Chleb::Server::Moose::__verseToJsonApi($verse, { translations => ['pickthall'] }, $cache);
	my $html = $self->sut->__verseToHtml($verse, [$json], 3);

	like($html, qr{<select id="verse-nav-translation" name="translations"}, 'HTML includes translation selector');
	like($html, qr{<option value="pickthall" selected>pickthall \(1930\)</option>},
		'HTML displays the selected translation in lowercase with its year');
	like($html, qr{<select id="verse-nav-book" name="book"[^>]*>.*?<option value="quran" selected>Quran \(114\)</option>}s,
		'HTML selects books from the current translation');
	like($html, qr{<h4 class="chapter-nav-title">Surahs</h4>.*?Surah 1}s,
		'HTML labels Pickthall navigation as Surahs');
	like($html, qr{<div class="translation">pickthall \(1930\)</div>}s,
		'HTML displays Pickthall year in lowercase');
	unlike($html, qr{<button>→</button>}, 'HTML does not include the old arrow button');
	like($html, qr{<button type="submit">select</button>}, 'HTML includes a manual selector submit button');
	like($html, qr{book\.addEventListener\('change'.*?if \(!isKindleBrowser\).*?book\.form\.submit\(\);}s,
		'HTML submits immediately when a book is selected');
	like($html, qr{var isKindleBrowser = /Kindle\|Silk/i.*?translation\.addEventListener\('change'.*?if \(booksLoaded && !isKindleBrowser\) \{ submitFirstBook\(\); \}.*?if \(translationChangePending && !isKindleBrowser\) \{ submitFirstBook\(\); \}}s,
		'HTML navigates to the first book when a translation is selected');

	return EXIT_SUCCESS;
}

sub testHtmlUsesEachTranslationReference {
	my ($self) = @_;
	plan skip_all => 'Pickthall test data is not installed' unless $self->hasTranslation('pickthall');
	plan tests => 2;

	my @verse = (
		$self->sut->__library->fetch('Genesis', 1, 1, { translations => ['kjv'] }),
		$self->sut->__library->fetch('Quran', 1, 1, { translations => ['pickthall'] }),
	);
	my $cache = { };
	my @json = map {
		Chleb::Server::Moose::__verseToJsonApi($_, { translations => ['all'] }, $cache)
	} @verse;
	push(@{ $json[0]->{data} }, $json[1]->{data}->[0]);

	my $html = $self->sut->__verseToHtml(\@verse, \@json, 3);
	my @references = $html =~ m{<h1>(.*?)</h1>}g;

	like(
		$references[0],
		qr{<a href="/1/lookup/gen/1\?translations=kjv">Gen</a>},
		'HTML uses the first translation reference',
	);
	like(
		$references[1],
		qr{<a href="/1/lookup/quran/1\?translations=pickthall">Quran</a>},
		'HTML uses the second translation reference',
	);

	return EXIT_SUCCESS;
}

sub testHtmlLookupLinksPreserveTranslation {
	my ($self) = @_;
	plan skip_all => 'Pickthall test data is not installed' unless $self->hasTranslation('pickthall');
	plan tests => 3;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = $self->sut->__lookup({
		accept => $mediaType,
		book => 'Quran',
		chapter => 1,
		translations => ['pickthall'],
	});

	like($html, qr{<a href="/1/lookup/quran/1/7\?translations=pickthall">7 </a>},
		'verse links preserve their JSON translation context');
	like($html, qr{href="/1/lookup/quran/2\?translations=pickthall">next chapter</a>},
		'headline navigation preserves the JSON translation context');
	like($html, qr{href="/1/lookup/quran/1\?translations=pickthall">Surah 1</a>},
		'chapter navigation preserves the JSON translation context');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(LookupServerTests->new->run());
