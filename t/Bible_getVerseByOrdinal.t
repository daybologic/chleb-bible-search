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

package Bible_getVerseByOrdinalTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_SUCCESS);
use Chleb::Bible;
use Chleb::Bible::DI::MockLogger;
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Chleb::Bible->new());
	#$self->__mockLogger(); # TODO?  Uncomment if we need it.

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Chleb::Bible::DI::MockLogger->new());
	return;
}

sub testFirstSuccess {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->getVerseByOrdinal(1);
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
	), 'verse inspection (Genesis 1:1)') or diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub testLastSuccess {
	my ($self) = @_;
	plan tests => 2;

	__checkLastVerse($self->sut->getVerseByOrdinal(31_102));
	__checkLastVerse($self->sut->getVerseByOrdinal(-1));

	return EXIT_SUCCESS;
}

sub __checkLastVerse {
	my ($verse) = @_;

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
	), 'verse inspection (Revelation 22:21)') or diag(explain($verse->toString()));

	return;
}

sub testOutOfBounds {
	my ($self) = @_;
	plan tests => 1;

	throws_ok { $self->sut->getVerseByOrdinal(31_103) } qr/^Verse 31103 not found in 'kjv' /,
	    'verse out of bounds';

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(Bible_getVerseByOrdinalTests->new->run());
