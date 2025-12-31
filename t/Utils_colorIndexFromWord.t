#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package UtilsColorIndexFromWordTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use POSIX qw(EXIT_SUCCESS);
use Chleb::Utils;
use Test::Exception;
use Test::More 0.96;

sub testFixedMappings {
	my ($self) = @_;
	plan tests => 3;

	is_deeply(Chleb::Utils::colorIndexFromWord('rebuke'), 30, "'rebuke' -> 30");
	is_deeply(Chleb::Utils::colorIndexFromWord('warning'), 22, "'warning' -> 22");
	is_deeply(Chleb::Utils::colorIndexFromWord('joy'), 50, "'joy' -> 50");

	return EXIT_SUCCESS;
}

sub testUnexpected {
	my ($self) = @_;
	plan tests => 5;

	is_deeply(Chleb::Utils::colorIndexFromWord(''), 0, "'' -> 0");
	is_deeply(Chleb::Utils::colorIndexFromWord(' '), 32, "32 -> 32");
	is_deeply(Chleb::Utils::colorIndexFromWord("\t"), 9, "9 -> 9");
	is_deeply(Chleb::Utils::colorIndexFromWord(0), 48, "48 -> 48");
	is_deeply(Chleb::Utils::colorIndexFromWord(undef), 0, "<undef> -> 0");

	return EXIT_SUCCESS;
}

sub testLimits {
	my ($self) = @_;

	my $rounds = 1_000;
	plan tests => $rounds;

	for (my $i = 1; $i <= $rounds; $i++) {
		my $word = $self->uniqueStr();
		subtest "round ${i}/${rounds}: $word" => sub {
			plan tests => 2;

			my $index = Chleb::Utils::colorIndexFromWord($word);
			cmp_ok($index, '>=', 0, 'at least zero');
			cmp_ok($index, '<=', 63, 'no more than 63');
		};
	}

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(UtilsColorIndexFromWordTests->new->run());
