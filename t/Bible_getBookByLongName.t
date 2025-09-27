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

package Bible_getBookByLongNameTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use English qw(-no_match_vars);
use Test::Deep qw(all cmp_deeply isa methods);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb;
use Chleb::DI::MockLogger;
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
	plan tests => 1;

	my @bible = $self->sut->__getBible();
	my $book = $bible[0]->getBookByLongName('Proverbs');
	is($book->longName, 'Proverbs', 'longName is Proverbs');

	return EXIT_SUCCESS;
}

sub testNotFound {
	my ($self) = @_;
	plan tests => 1;

	my @bible = $self->sut->__getBible();

	eval {
		$bible[0]->getBookByLongName('Genesia');
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => "Long book name 'Genesia' is not a book in the bible, did you mean Genesis?",
				location    => undef,
				statusCode  => 404,
			),
		), 'correctly not found');
	} else {
		fail('No exception raised, as was expected');
	}

	return EXIT_SUCCESS;
}

sub testNotFoundNonFatal {
	my ($self) = @_;
	plan tests => 1;

	my @bible = $self->sut->__getBible();
	is($bible[0]->getBookByLongName('Genesia', { nonFatal => 1 }), undef, '<undef> returned');

	return EXIT_SUCCESS;
}

sub testNotFoundNonFatalUndef {
	my ($self) = @_;
	plan tests => 1;

	my @bible = $self->sut->__getBible();
	is($bible[0]->getBookByLongName(undef, { nonFatal => 1 }), undef, '<undef> returned');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(Bible_getBookByLongNameTests->new->run());
