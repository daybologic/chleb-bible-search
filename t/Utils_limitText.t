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

package UtilsLimitTextTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Utils;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testNoChange {
	my ($self) = @_;
	plan tests => 2;

	my $text = "Two things have I asked of thee; Deny me [them] not before I die:";
	is(Chleb::Utils::limitText($text), $text, $text);

	$text = "Hold the pattern of sound words which thou hast heard from me, in faith and love which is in Christ Jesus.";
	is(Chleb::Utils::limitText($text), $text, $text);

	return EXIT_SUCCESS;
}

sub testChanged {
	my ($self) = @_;
	plan tests => 2;

	my $input = "to the end he may establish your hearts unblameable in holiness before our God and Father, at the coming of our Lord Jesus with all his saints.";
	my $expect = "to the end he may establish your hearts unblameable in holiness before our God and Father, at the coming of our Lord ...";
	is(Chleb::Utils::limitText($input), $expect, $expect);

	$input = "But by the grace of God I am what I am: and his grace which was bestowed upon me was not found vain; but I labored more abundantly than they all: yet not I, but the grace of God which was with me.";
	$expect = "But by the grace of God I am what I am: and his grace which was bestowed upon me was not found vain; but I labored mo...";
	is(Chleb::Utils::limitText($input), $expect, $expect);

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(UtilsLimitTextTests->new->run());
