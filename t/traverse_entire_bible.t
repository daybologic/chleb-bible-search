#!/usr/bin/env perl
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

package TraverseEntireBibleTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses;
use Religion::Bible::Verses::DI::MockLogger;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Religion::Bible::Verses->new());
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub testTraversal {
	my ($self) = @_;
	plan tests => 4;

	my $book = $self->sut->getBookByOrdinal(1);
	cmp_deeply($book, all(
		isa('Religion::Bible::Verses::Book'),
		methods(shortName => 'Gen'),
	), 'Book lookup for Genesis');

	my $verse = $book->getVerseByOrdinal(1);
	cmp_deeply($verse, all(
		isa('Religion::Bible::Verses::Verse'),
		methods(
			chapter => methods(ordinal => 1),
			ordinal => 1,
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
		isa('Religion::Bible::Verses::Verse'),
		methods(
			book => methods(ordinal => 66),
			chapter => methods(ordinal => 22),
			ordinal => 21,
		),
	), 'Last verse in bible correct: ' . $verse->toString());

	my $expectBibleVerseCount = 31_102;
	is($actualBibleVerseCount, $expectBibleVerseCount, "Bible verse count: $expectBibleVerseCount");

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Religion::Bible::Verses::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;

exit(TraverseEntireBibleTests->new->run());
