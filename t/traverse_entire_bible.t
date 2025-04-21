#!/usr/bin/env perl
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

package TraverseEntireBibleTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Chleb;
use Chleb::DI::MockLogger;
use POSIX qw(EXIT_SUCCESS);
use Readonly;
use Test::Deep qw(all cmp_deeply isa methods);
use Test::More 0.96;

Readonly my $VERSE_FIRST => 0;
Readonly my $VERSE_LAST  => 1;

sub setUp {
	my ($self) = @_;

	$self->sut(Chleb->new());
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub testTraversalDefault {
	my ($self) = @_;

	$self->__checkTraversal();

	return EXIT_SUCCESS;
}

sub testTraversal_kjv {
	my ($self) = @_;

	$self->__checkTraversal('kjv');

	return EXIT_SUCCESS;
}

sub testTraversal_asv {
	my ($self) = @_;

	$self->__checkTraversal('asv');

	return EXIT_SUCCESS;
}

sub testTraversalReverse {
	my ($self, $translation) = @_;
	Readonly my $TEST_COUNT => 4;
	plan tests => $TEST_COUNT;

	my $testComprehensive = !$ENV{TEST_QUICK};
	SKIP: {
		skip 'TEST_QUICK environment variable is set', $TEST_COUNT unless $self->_isTestComprehensive();

		$self->__testTraversalReverseWork();
	};

	return EXIT_SUCCESS;
}

sub __checkTraversal {
	my ($self, $translation) = @_;
	Readonly my $TEST_COUNT => 4;
	plan tests => $TEST_COUNT;

	my $testComprehensive = !$ENV{TEST_QUICK};
	SKIP: {
		skip 'TEST_QUICK environment variable is set', $TEST_COUNT unless $self->_isTestComprehensive();

		$self->__checkTraversalWork($translation);
	};

	return;
}

sub __checkTraversalWork {
	my ($self, $translation) = @_;

	my %args = ( );
	$args{translations} = [ $translation ] if ($translation);
	my @bible = $self->sut->__getBible(\%args);

	my $book = $bible[0]->getBookByOrdinal(1);
	cmp_deeply($book, all(
		isa('Chleb::Bible::Book'),
		methods(
			longName => 'Genesis',
			shortName => 'gen',
			shortNameRaw => 'Gen',
		),
	), 'Book lookup for Genesis');

	my $verse = $book->getVerseByOrdinal(1);
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			chapter => methods(ordinal => 1),
			ordinal => 1,
			text    => __getVerseText($translation, $VERSE_FIRST),
		),
	), 'First verse in bible correct: ' . $verse->toString());

	my $previousVerse;
	my $actualBibleVerseCount = 0;
	do {
		$actualBibleVerseCount++;
		$previousVerse = $verse;
		$verse = $verse->getNext();
	} while ($verse);

	$verse = $previousVerse;
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book => methods(ordinal => 66),
			chapter => methods(ordinal => 22),
			ordinal => 21,
			text    => __getVerseText($translation, $VERSE_LAST),
		),
	), 'Last verse in bible correct: ' . $verse->toString());

	my $expectBibleVerseCount = 31_102;
	is($actualBibleVerseCount, $expectBibleVerseCount, "Bible verse count: $expectBibleVerseCount");

	return;
}

sub __testTraversalReverseWork {
	my ($self) = @_;

	my @bible = $self->sut->__getBible();
	my $book = $bible[0]->getBookByOrdinal(-1);
	cmp_deeply($book, all(
		isa('Chleb::Bible::Book'),
		methods(shortName => 'Rev'),
	), 'Book lookup for Revelation');

	my $verse = $book->getVerseByOrdinal(-1);
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => methods(ordinal => 66),
			chapter => methods(ordinal => 22),
			ordinal => 21,
		),
	), 'Last verse in bible correct: ' . $verse->toString());

	my $previousVerse;
	my $actualBibleVerseCount = 0;
	do {
		$actualBibleVerseCount++;
		$previousVerse = $verse;
		$verse = $verse->getPrev();
	} while ($verse);

	$verse = $previousVerse;
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book => methods(ordinal => 1),
			chapter => methods(ordinal => 1),
			ordinal => 1,
		),
	), 'first verse in bible correct: ' . $verse->toString());

	my $expectBibleVerseCount = 31_102;
	is($actualBibleVerseCount, $expectBibleVerseCount, "Bible verse count: $expectBibleVerseCount");

	return;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return;
}

sub __getVerseText {
	my ($translation, $which) = @_;

	$translation ||= 'kjv';

	Readonly my %TEXT => (
		'kjv' => [
			'In the beginning God created the heaven and the earth.',
			'The grace of our Lord Jesus Christ [be] with you all. Amen.',
		],
		'asv' => [
			'In the beginning God created the heavens and the earth.',
			'The grace of the Lord Jesus be with the saints. Amen.',
		],
	);

	return $TEXT{$translation}->[$which];
}

package main;
use strict;
use warnings;

exit(TraverseEntireBibleTests->new->run());
