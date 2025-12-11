#!/usr/bin/perl
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

package Backend_getOrdinalByVerseKeyTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Chleb::Bible;
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Readonly;
use Test::Deep qw(cmp_deeply all isa methods bool re);
use Test::Exception;
use Test::More 0.96;

has dic => (is => 'rw', isa => 'Chleb::DI::Container');

sub setUp {
	my ($self, %params) = @_;

	$self->dic(Chleb::DI::Container->instance);
	$self->dic->configPaths(['etc-local']);

	if ($params{method} =~ m/(kjv|asv)/i) {
		$self->__initTranslation($1);
	}

	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub test_asv {
	my ($self) = @_;
	$self->__check();
	return EXIT_SUCCESS;
}

sub test_kjv {
	my ($self) = @_;
	$self->__check();
	return EXIT_SUCCESS;
}

sub __check {
	my ($self) = @_;

	my $translation = $self->sut->bible->translation;

	Readonly my %EXPECTATIONS => (
		"${translation}:Gen:1:1" => 1,
		"${translation}:Gen:1:31" => 31,
		"${translation}:Gen:1:32" => 0, # spill-over chapter by one verse
		"${translation}:Gen:50:26" => 1_533,
		"${translation}:Gen:50:27" => 0, # spill-over book by one verse
		"${translation}:Gen:51:1" => 0, # spill-over book by one chapter
		"${translation}:Psa:23:1" => 14_237,
		"${translation}:Rev:22:21" => 31_102,
		"${translation}:Rev:22:22" => 0, # spill-over translation by one verse
		'xxx:Gen:1:1' => 0, # no such translation
		"${translation}:Moz:1:1" => 0, # no such book
	);

	plan tests => scalar(keys(%EXPECTATIONS));

	while (my ($input, $output) = each(%EXPECTATIONS)) {
		is($self->sut->getOrdinalByVerseKey($input), $output, "'$input' -> $output");
	}

	return EXIT_SUCCESS;
}

sub __initTranslation {
	my ($self, $translation) = @_;

	$self->sut(Chleb::Bible->new({
		dic => $self->dic,
		translation => $translation,
	}));

	$self->sut($self->sut->__backend);

	return;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;
exit(Backend_getOrdinalByVerseKeyTests->new->run);
