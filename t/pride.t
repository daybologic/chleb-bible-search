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

package PrideTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb;
use Chleb::Bible::DI::MockLogger;
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods);
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
	$self->sut->dic->logger(Chleb::Bible::DI::MockLogger->new());
	return;
}

sub testPride_default {
	my ($self) = @_;
	plan tests => 1;

	my @verse = $self->sut->fetch('Prov', 16, 18);
	cmp_deeply(\@verse, [
		all(
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
		),
	], 'verse inspection') or diag(explain($verse[0]->toString()));

	return EXIT_SUCCESS;
}

sub testPride_allTranslations {
	my ($self) = @_;
	plan tests => 1;

	my @verse = $self->sut->fetch('Prov', 16, 18, { translations => [ 'all' ] });
	cmp_deeply(\@verse, [
		all(
			isa('Chleb::Bible::Verse'),
			methods(
				book    => methods(
					bible     => methods(translation => 'asv'),
					ordinal   => 20,
					longName  => 'Proverbs',
					shortName => 'Prov',
					testament => 'old',
				),
				chapter => methods(
					ordinal => 16,
				),
				ordinal => 18,
				text    => 'Pride [goeth] before destruction, And a haughty spirit before a fall.',
			),
		),
		all(
			isa('Chleb::Bible::Verse'),
			methods(
				book    => methods(
					bible     => methods(translation => 'kjv'),
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
		),
	], 'verse inspection') or diag(explain($verse[0]->toString()));

	return EXIT_SUCCESS;
}

sub testBadBook {
	my ($self) = @_;
	plan tests => 1;

	throws_ok { $self->sut->fetch('Mormon', 16, 18) } qr/Long book name 'Mormon' is not a book in the bible/,
	    'exception thrown';

	return EXIT_SUCCESS;
}

sub testBadChapter {
	my ($self) = @_;
	plan tests => 1;

	throws_ok { $self->sut->fetch('Prov', 36, 1) } qr/Chapter 36 not found in Prov/,
	    'exception thrown';

	return EXIT_SUCCESS;
}

sub testBadVerse {
	my ($self) = @_;
	plan tests => 1;

	throws_ok { $self->sut->fetch('Luke', 24, 54) } qr/Verse 54 not found in Luke 24/,
	    'exception thrown';

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(PrideTests->new->run());
