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

package UtilsParseIntoTypeTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Chleb::Utils;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Readonly;
use Test::Chleb::DummyType;
use Test::Deep qw(all cmp_deeply isa methods);
use Test::Exception;
use Test::More 0.96;

sub testMissingName {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::parseIntoType('DummyType', undef)
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'No name supplied in call to parseIntoType()';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => undef,
			location => undef,
			statusCode => 500,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testEmptyName {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::parseIntoType('DummyType', '')
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'No name supplied in call to parseIntoType()';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => undef,
			location => undef,
			statusCode => 500,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testMissingDefault {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Utils::TypeParserException';
	my $name = $self->uniqueStr();

	throws_ok {
		Chleb::Utils::parseIntoType('DummyType', $name)
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = "No default value supplied for '$name'";
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => $name,
			location => undef,
			statusCode => 500,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testIllegalValue {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Utils::TypeParserException';
	my $name = $self->uniqueStr();
	my $value = $self->uniqueStr();
	my $default = 'acceptable'; # permitted in Test::Chleb::DummyType

	throws_ok {
		Chleb::Utils::parseIntoType('Test::Chleb::DummyType', $name, $value, $default)
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = "Illegal value '$value' for '$name'";
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => $name,
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(UtilsParseIntoTypeTests->new->run());
