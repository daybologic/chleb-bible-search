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

#!/usr/bin/perl
package Book_equalsTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Bible;
use Chleb::Bible::Book;
use Chleb::DI::MockLogger;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(cmp_deeply all isa methods bool re);
use Test::Exception;
use Test::More;

has __bible => (isa => 'Chleb::Bible', is => 'rw');

sub setUp {
	my ($self) = @_;

	$self->__mockLogger();

	$self->__bible(Chleb::Bible->new({
		translation => 'asv',
	}));

	$self->sut($self->__makeBook());

	return EXIT_SUCCESS;
}

sub __makeBook {
	my ($self, $name) = @_;

	$name = 'Genesis' unless ($name);

	return Chleb::Bible::Book->new({
		bible => $self->__bible,
		longName => $name,
		shortNameRaw => substr($name, 0, 3),
	});
}

sub testWrongObject {
	my ($self) = @_;
	return $self->__checkWrongObject($self);
}

sub testNullObject {
	my ($self) = @_;
	return $self->__checkWrongObject(undef);
}

sub __checkWrongObject {
	my ($self, $object) = @_;
	plan tests => 1;

	eval {
		$self->sut->equals($object);
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => 'Not a book, in Book/equals()',
				location    => undef,
				statusCode  => 500,
			),
		), 'correctly not found');
	} else {
		fail('No exception raised, as was expected');
	}

	return EXIT_SUCCESS;
}

sub testSameBook {
	my ($self) = @_;
	plan tests => 2;

	ok($self->sut->equals($self->sut), 'same object');
	ok($self->sut->equals($self->__makeBook()), 'same book, different object');

	return EXIT_SUCCESS;
}

sub testDifferentBook {
	my ($self) = @_;
	plan tests => 1;

	ok(!$self->sut->equals($self->__makeBook('Matthew')), 'different book');

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;

	my $dic = Chleb::DI::Container->instance;
	$dic->logger(Chleb::DI::MockLogger->new());

	return;
}

package main;
use strict;
use warnings;
exit(Book_equalsTests->new->run);
