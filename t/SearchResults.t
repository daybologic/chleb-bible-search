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

package SearchResultsTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_SUCCESS);
use Chleb;
use Chleb::Bible;
use Chleb::Bible::Book;
use Chleb::Bible::Chapter;
use Chleb::Bible::Verse;
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Test::Deep qw(cmp_deeply);
use Test::Exception;
use Test::More 0.96;

has dic => (is => 'rw');

sub setUp {
	my ($self) = @_;
	$self->dic(Chleb::DI::Container->instance);
	$self->__mockLogger();
	return EXIT_SUCCESS;
}

sub test_TO_JSON {
	my ($self) = @_;
	plan tests => 1;

	$self->sut(Chleb::Bible::Search::Results->new({
		dic => $self->dic,
		verses => $self->__makeVerses(),
	}));

	my $json = $self->sut->TO_JSON();
	cmp_deeply($json, {
		count => 3,
		msec => 0,
		verses => [
			{
				book => 'short book 1',
				chapter => 1,
				ordinal => 1,
				text => 'And the king of Egypt said unto them, Wherefore do ye, Moses and Aaron, loose the people from their works? get you unto your burdens.',
				translation => 'asv',
			},
			{
				book => 'short book 2',
				chapter => 1,
				ordinal => 2,
				text => 'My heart is fixed, O God, my heart is fixed: I will sing and give praise.',
				translation => 'asv',
			},
			{
				book => 'short book 3',
				chapter => 1,
				ordinal => 3,
				text => 'and that ye study to be quiet, and to do your own business, and to work with your hands, even as we charged you;',
				translation => 'asv',
			},
		],
	}, 'TO_JSON') or diag(explain($json));

	return EXIT_SUCCESS;
}

sub __makeVerse {
	my ($self, $verseIndex) = @_;

	my @verseTexts = (
		'And the king of Egypt said unto them, Wherefore do ye, Moses and Aaron, loose the people from their works? get you unto your burdens.',
		'My heart is fixed, O God, my heart is fixed: I will sing and give praise.',
		'and that ye study to be quiet, and to do your own business, and to work with your hands, even as we charged you;',
	);

	my $bible = Chleb::Bible->new({
		dic => $self->dic,
		translation => 'asv',
	});

	my $book = Chleb::Bible::Book->new({
		bible => $bible,
		dic => $self->dic,
		shortName => sprintf('short book %d', $verseIndex+1),
	});

	my $chapter = Chleb::Bible::Chapter->new({
		bible => $bible,
		book => $book,
		dic => $self->dic,
		ordinal => 1,
	});

	return Chleb::Bible::Verse->new({
		book => $book,
		chapter => $chapter,
		dic => $self->dic,
		ordinal => $verseIndex+1,
		text => $verseTexts[$verseIndex],
	});
}

sub __makeVerses {
	my ($self) = @_;

	my @verses;
	for (my $verseIndex = 0; $verseIndex < 3; $verseIndex++) {
		$verses[$verseIndex] = $self->__makeVerse($verseIndex);
	}

	return \@verses;
}

sub __mockLogger {
	my ($self) = @_;
	$self->dic->logger(Chleb::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;

exit(SearchResultsTests->new->run());
