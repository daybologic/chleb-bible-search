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

package VerseTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb;
use Chleb::Bible::Book;
use Chleb::Bible::Verse;
use Chleb::DI::MockLogger;
use Chleb::Type::Testament;
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

sub test {
	my ($self) = @_;
	plan tests => 5;

	my @bible = $self->sut->__getBible();
	my $book = Chleb::Bible::Book->new({
		bible        => $bible[0],
		chapterCount => 1,
		longName     => 'Book of Morman',
		ordinal      => 21,
		shortName    => 'susana',
		shortNameRaw => 'Susana',
		testament    => Chleb::Type::Testament->new({ value => 'old' }),
		verseCount   => 1,
	});

	my $translation = 'kjv';
	my $text = 'Blessed are the peacemakers, because they will be called sons of God';

	my $verse = Chleb::Bible::Verse->new({
		book    => $book,
		chapter => Chleb::Bible::Chapter->new({
			bible    => $bible[0],
			book     => $book,
			ordinal  => 1121,
		}),
		ordinal => 5,
		text    => $text,
	});

	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => methods(
				longName     => 'Book of Morman',
				ordinal      => 21,
				shortName    => 'susana',
				shortNameRaw => 'Susana',
				testament    => Chleb::Type::Testament->new({ value => 'old' }),
			),
			chapter => methods(
				ordinal => 1_121,
			),
			ordinal => 5,
			text    => $text,
		),
	), 'verse inspection') or diag(explain($verse));

	is($verse->toString(), 'Susana 1121:5', 'toString default verbosity');
	is($verse->toString(0), 'Susana 1121:5', 'toString non-verbose');
	is($verse->toString(1), "Susana 1121:5 - $text [$translation]", 'toString verbose');

	my $json = $verse->TO_JSON();
	cmp_deeply($json, {
		book        => 'susana',
		chapter     => 1_121,
		emotion     => 'neutral',
		ordinal     => 5,
		text        => $text,
		tones       => [ ],
		translation => $translation,
	}, 'TO_JSON') or diag(explain($json));

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(VerseTests->new->run());
