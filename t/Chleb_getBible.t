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

package ChlebGetBibleTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Chleb;
use Chleb::DI::MockLogger;
use English qw(-no_match_vars);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods);
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

sub testSuccess {
	my ($self) = @_;
	plan tests => 4;

	cmp_deeply($self->sut->__getBible('kjv'), all(
		isa('Chleb::Bible'),
		methods(translation => 'kjv'),
	), 'kjv');

	my @list = $self->sut->__getBible({ translations => [ 'asv', 'kjv' ] });
	cmp_deeply(\@list, [
		all(
			isa('Chleb::Bible'),
			methods(translation => 'asv'),
		),
		all(
			isa('Chleb::Bible'),
			methods(translation => 'kjv'),
		),
	], 'correct bibles returned (unpolluted)') or diag(explain(\@list));

	@list = $self->sut->__getBible( { translations => [ 'growl', 'asv', 'blah', 'kjv' ] });
	cmp_deeply(\@list, [
		all(
			isa('Chleb::Bible'),
			methods(translation => 'asv'),
		),
		all(
			isa('Chleb::Bible'),
			methods(translation => 'kjv'),
		),
	], 'correct bibles returned (polluted)');

	@list = $self->sut->__getBible('all');
	cmp_deeply(\@list, [
		all(
			isa('Chleb::Bible'),
			methods(translation => 'asv'),
		),
		all(
			isa('Chleb::Bible'),
			methods(translation => 'kjv'),
		),
	], 'all bibles returned');

	return EXIT_SUCCESS;
}

sub testDefault {
	my ($self) = @_;
	plan tests => 3;

	cmp_deeply($self->sut->__getBible(), all(
		isa('Chleb::Bible'),
		methods(translation => 'kjv'),
	), 'empty: kjv');

	cmp_deeply($self->sut->__getBible(undef), all(
		isa('Chleb::Bible'),
		methods(translation => 'kjv'),
	), '<undef>: kjv');

	cmp_deeply($self->sut->__getBible({ translations => [ ] }), all(
		isa('Chleb::Bible'),
		methods(translation => 'kjv'),
	), 'empty ARRAY: kjv');

	return EXIT_SUCCESS;
}

sub testFail {
	my ($self) = @_;
	plan tests => 1;

	eval {
		$self->sut->__getBible('blah');
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => 'No recognized bible translations',
				statusCode  => 404,
			),
		), "correct 'not found' error");
	} else {
		fail('No exception raised, as was expected');
	}

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(ChlebGetBibleTests->new->run());
