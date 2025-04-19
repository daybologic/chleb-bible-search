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

package VotdTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb;
use Chleb::DI::MockLogger;
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Chleb->new());
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub test {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->votd();
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => isa('Chleb::Bible::Book'),
			chapter => isa('Chleb::Bible::Chapter'),
			ordinal => re(qr/^\d+$/),
			text    => ignore(),
		),
	), 'verse inspection') or diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub testV2 {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->votd({ version => 2, when => '1971-04-28T12:00:00+0100' });
	cmp_deeply($verse, [
		all(
			isa('Chleb::Bible::Verse'),
			methods(
				book    => isa('Chleb::Bible::Book'),
				chapter => isa('Chleb::Bible::Chapter'),
				ordinal => 51,
				text    => 'Speak unto the children of Israel, and say unto them, When ye are passed over Jordan into the land of Canaan;',
			),
		),
		all(
			isa('Chleb::Bible::Verse'),
			methods(
				book    => isa('Chleb::Bible::Book'),
				chapter => isa('Chleb::Bible::Chapter'),
				ordinal => 52,
				text    => 'Then ye shall drive out all the inhabitants of the land from before you, and destroy all their pictures, and destroy all their molten images, and quite pluck down all their high places:',
			),
		),
		all(
			isa('Chleb::Bible::Verse'),
			methods(
				book    => isa('Chleb::Bible::Book'),
				chapter => isa('Chleb::Bible::Chapter'),
				ordinal => 53,
				text    => 'And ye shall dispossess [the inhabitants] of the land, and dwell therein: for I have given you the land to possess it.',
			),
		)
	], 'specific verses inspection');

	return EXIT_SUCCESS;
}

sub testParentalTerm {
	my ($self) = @_;
	plan tests => 2;

	my $when = '1980-04-12T12:00:00+0100';
	my $verse = $self->sut->votd({ version => 1, when => $when, parental => 0 });
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => all(
				isa('Chleb::Bible::Book'),
				methods(
					longName => 'Jeremiah',
					shortName => 'jer',
					shortNameRaw => 'Jer',
				),
			),
			chapter => all(
				isa('Chleb::Bible::Chapter'),
				methods(ordinal => 5),
			),
			ordinal => 7,
			text    => ignore(),
		),
	), 'verse inspection') or diag(explain($verse->toString()));

	$verse = $self->sut->votd({ version => 1, when => $when, parental => 1 });
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => all(
				isa('Chleb::Bible::Book'),
				methods(
					longName => 'Genesis',
					shortName => 'gen',
					shortNameRaw => 'Gen',
				),
			),
			chapter => all(
				isa('Chleb::Bible::Chapter'),
				methods(ordinal => 42),
			),
			ordinal => 3,
			text    => ignore(),
		),
	), 'verse inspection, parental') or diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub testParentalRef {
	my ($self) = @_;
	plan tests => 2;

	my $when = '1980-09-8T12:00:00+0100';
	my $verse = $self->sut->votd({ version => 1, when => $when, parental => 0 });
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => all(
				isa('Chleb::Bible::Book'),
				methods(
					longName => 'Deuteronomy',
					shortName => 'deu',
					shortNameRaw => 'Deu',
				),
			),
			chapter => all(
				isa('Chleb::Bible::Chapter'),
				methods(ordinal => 22),
			),
			ordinal => 21,
			text    => ignore(),
		),
	), 'verse inspection') or diag(explain($verse->toString()));

	$verse = $self->sut->votd({ version => 1, when => $when, parental => 1 });
	cmp_deeply($verse, all(
		isa('Chleb::Bible::Verse'),
		methods(
			book    => all(
				isa('Chleb::Bible::Book'),
				methods(
					longName => 'Isaiah',
					shortName => 'isa',
					shortNameRaw => 'Isa',
				),
			),
			chapter => all(
				isa('Chleb::Bible::Chapter'),
				methods(ordinal => 37),
			),
			ordinal => 19,
			text    => ignore(),
		),
	), 'verse inspection, parental') or diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;

exit(VotdTests->new->run());
