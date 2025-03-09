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

package ExceptionTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Exception;
use Chleb::Util::BooleanParserSystemException;
use Chleb::Util::BooleanParserUserException;
use HTTP::Status qw(:constants);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods);
use Test::More 0.96;

sub testRaiseBaseException {
	my ($self) = @_;
	plan tests => 1;

	my $description = $self->uniqueStr();
	$self->sut(Chleb::Exception->raise(HTTP_UNAVAILABLE_FOR_LEGAL_REASONS, $description));

	cmp_deeply($self->sut, all(
		isa('Chleb::Exception'),
		methods(
			description => $description,
			location    => undef,
			statusCode  => 451,
		),
	), 'exception object fields correct');

	return EXIT_SUCCESS;
}

sub testRaiseBooleanParserSystemException {
	my ($self) = @_;
	plan tests => 2;

	my $description = $self->uniqueStr();
	my $key = $self->uniqueStr();
	$self->sut(Chleb::Util::BooleanParserSystemException->raise(HTTP_UNAVAILABLE_FOR_LEGAL_REASONS, $description, $key));

	cmp_deeply($self->sut, all(
		isa('Chleb::Exception'),
		isa('Chleb::Util::BooleanParserException'),
		isa('Chleb::Util::BooleanParserSystemException'),
		methods(
			description => $description,
			key         => $key,
			location    => undef,
			statusCode  => 451,
		),
	), 'exception object fields correct');

	$self->sut(Chleb::Util::BooleanParserSystemException->raise(undef, $description, $key));
	cmp_deeply($self->sut, all(
		isa('Chleb::Exception'),
		isa('Chleb::Util::BooleanParserException'),
		isa('Chleb::Util::BooleanParserSystemException'),
		methods(
			description => $description,
			key         => $key,
			location    => undef,
			statusCode  => 500,
		),
	), 'default statusCode');

	return EXIT_SUCCESS;
}

sub testRaiseBooleanParserUserException {
	my ($self) = @_;
	plan tests => 2;

	my $description = $self->uniqueStr();
	my $key = $self->uniqueStr();
	$self->sut(Chleb::Util::BooleanParserUserException->raise(HTTP_UNAVAILABLE_FOR_LEGAL_REASONS, $description, $key));

	cmp_deeply($self->sut, all(
		isa('Chleb::Exception'),
		isa('Chleb::Util::BooleanParserException'),
		isa('Chleb::Util::BooleanParserUserException'),
		methods(
			description => $description,
			key         => $key,
			location    => undef,
			statusCode  => 451,
		),
	), 'exception object fields correct');

	$self->sut(Chleb::Util::BooleanParserUserException->raise(undef, $description, $key));
	cmp_deeply($self->sut, all(
		isa('Chleb::Exception'),
		isa('Chleb::Util::BooleanParserException'),
		isa('Chleb::Util::BooleanParserUserException'),
		methods(
			description => $description,
			key         => $key,
			location    => undef,
			statusCode  => 400,
		),
	), 'default statusCode');

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(ExceptionTests->new->run());
