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

package Book_getVerseByOrdinalTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_SUCCESS);
use Chleb;
use Chleb::DI::MockLogger;
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Chleb->new());
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 5;

	my @bible = $self->sut->__getBible();
	my $book = $bible[0]->getBookByShortName('Jonah');
	my $verse = $book->getVerseByOrdinal(48);
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => methods(
				ordinal   => 32, # 32nd book is 'Jonah'
				longName  => 'Jonah',
				shortName => 'Jonah',
				testament => 'old',
			),
			chapter => methods(
				ordinal => 4,
			),
			ordinal => 11,
			text    => 'And should not I spare Nineveh, that great city, wherein are more than sixscore thousand persons that cannot discern between their right hand and their left hand; and [also] much cattle?',
		),
	), 'verse inspection (Jonah)') or diag(explain($verse->toString()));

	$book = $bible[0]->getBookByOrdinal(20);
	$verse = $book->getVerseByOrdinal(458);
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => methods(
				ordinal   => 20,
				longName  => 'Proverbs',
				shortName => 'Prov',
				testament => 'old',
			),
			chapter => methods(
				ordinal => 16,
			),
			ordinal => 18,
			text    => 'Pride [goeth] before destruction, and an haughty spirit before a fall.',
		),
	), 'verse inspection (Proverbs)') or diag(explain($verse->toString()));

	$book = $bible[0]->getBookByOrdinal(1);
	$verse = $book->getVerseByOrdinal(1);
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => methods(
				ordinal   => 1,
				longName  => 'Genesis',
				shortName => 'Gen',
				testament => 'old',
			),
			chapter => methods(
				ordinal => 1,
			),
			ordinal => 1,
			text    => 'In the beginning God created the heaven and the earth.',
		),
	), 'verse inspection (Genesis, creation)') or diag(explain($verse->toString()));

	$verse = $book->getVerseByOrdinal(1533);
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => methods(
				ordinal   => 1,
				longName  => 'Genesis',
				shortName => 'Gen',
				testament => 'old',
			),
			chapter => methods(
				ordinal => 50,
			),
			ordinal => 26,
			text    => 'So Joseph died, [being] an hundred and ten years old: and they embalmed him, and he was put in a coffin in Egypt.',
		),
	), 'verse inspection (Genesis)') or diag(explain($verse->toString()));

	$book = $bible[0]->getBookByShortName('Rev');
	$verse = $book->getVerseByOrdinal(404);
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => methods(
				ordinal   => 66,
				longName  => 'Revelation of John',
				shortName => 'Rev',
				testament => 'new',
			),
			chapter => methods(
				ordinal => 22,
			),
			ordinal => 21,
			text    => 'The grace of our Lord Jesus Christ [be] with you all. Amen.',
		),
	), 'verse inspection (Revelation)') or diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub testOutOfBounds {
	my ($self) = @_;
	plan tests => 2;

	my @bible = $self->sut->__getBible();
	my $book = $bible[0]->getBookByShortName('Rev');
	my $msg = 'Verse 405 not found in Rev';
	throws_ok { $book->getVerseByOrdinal(405) } qr/^$msg /, $msg;

	$book = $bible[0]->getBookByShortName('Gen');
	$msg = 'Verse 1534 not found in Gen';
	throws_ok { $book->getVerseByOrdinal(1534) } qr/^$msg /, $msg;

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(Book_getVerseByOrdinalTests->new->run());
