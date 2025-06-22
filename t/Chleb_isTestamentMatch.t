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

package ChlebIsTestamentMatchTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Chleb;
use Chleb::Bible::Verse;
use Chleb::Bible::Book;
use Chleb::Type::Testament;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb->new());

	return EXIT_SUCCESS;
}

sub testAny {
	my ($self) = @_;
	plan tests => 1;

	my $testament = Chleb::Type::Testament->new({ value => $Chleb::Type::Testament::ANY });
	ok($self->sut->__isTestamentMatch(undef, $testament), 'any testament matches without even looking at verse');

	return EXIT_SUCCESS;
}

sub testMatchOldFuture {
	my ($self) = @_;
	plan tests => 1;

	my @bible = $self->sut->__getBible();

	my $book = Chleb::Bible::Book->new({
		bible => $bible[0],
		chapterCount => 50,
		longName => 'Genesis',
		shortNameRaw => 'Gen',
		testamentFuture => Chleb::Type::Testament->new({ value => $Chleb::Type::Testament::OLD }),
		verseCount => 1_533,
	});

	my $chapter = $book->getChapterByOrdinal(1);

	my $verse = Chleb::Bible::Verse->new({
		book => $book,
		chapter => $chapter,
		ordinal => 1,
		testamentFuture => Chleb::Type::Testament->new({ value => $Chleb::Type::Testament::OLD }),
		text => $self->uniqueStr(),
	});

	my $testament = Chleb::Type::Testament->new({ value => $Chleb::Type::Testament::OLD });
	ok($self->sut->__isTestamentMatch($verse, $testament), 'old testament future match');

	return EXIT_SUCCESS;
}

sub testMatchNewFuture {
	my ($self) = @_;
	plan tests => 1;

	my @bible = $self->sut->__getBible();

	my $book = Chleb::Bible::Book->new({
		bible => $bible[0],
		chapterCount => 4,
		longName => 'Philippians',
		shortNameRaw => 'Phil',
		testamentFuture => Chleb::Type::Testament->new({ value => $Chleb::Type::Testament::NEW }),
		verseCount => 104,
	});

	my $chapter = $book->getChapterByOrdinal(1);

	my $verse = Chleb::Bible::Verse->new({
		book => $book,
		chapter => $chapter,
		ordinal => 26,
		testamentFuture => Chleb::Type::Testament->new({ value => $Chleb::Type::Testament::NEW }),
		text => $self->uniqueStr(),
	});

	my $testament = Chleb::Type::Testament->new({ value => $Chleb::Type::Testament::NEW });
	ok($self->sut->__isTestamentMatch($verse, $testament), 'new testament future match');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(ChlebIsTestamentMatchTests->new->run());
