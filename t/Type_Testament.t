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

package TypeTestamentTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Type::Testament;
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods);
use Test::Exception;
use Test::More 0.96;

sub testValid {
	my ($self) = @_;
	plan tests => 3;

	foreach my $value (qw(any old new)) {
		$self->sut(Chleb::Type::Testament->new({ value => $value }));

		cmp_deeply($self->sut, all(
			isa('Chleb::Type::Testament'),
			methods(
				toString => $value,
				value => $value,
			),
		), $value);
	}

	return EXIT_SUCCESS;
}

sub testValidViaConstant {
	my ($self) = @_;
	plan tests => 3;

	foreach my $value (
		$Chleb::Type::Testament::ANY,
		$Chleb::Type::Testament::OLD,
		$Chleb::Type::Testament::NEW,
	) {
		$self->sut(Chleb::Type::Testament->new({ value => $value }));

		cmp_deeply($self->sut, all(
			isa('Chleb::Type::Testament'),
			methods(
				toString => $value,
				value => $value,
			),
		), $value);
	}

	return EXIT_SUCCESS;
}

sub testInvalid {
	my ($self) = @_;
	plan tests => 4;

	foreach my $value ('ANY', '', undef, 0) {
		throws_ok {
			Chleb::Type::Testament->new({ value => $value })
		} qr/Validation failed/, (defined($value) ? "'$value'" : '<undef>');
	}

	return EXIT_SUCCESS;
}

sub testReadOnly {
	my ($self) = @_;
	plan tests => 6;

	$self->sut(Chleb::Type::Testament->new({ value => 'old' }));

	throws_ok {
		$self->sut->value('old');
	} qr/read-only/, 'read-only value';
	is($self->sut->value, 'old', 'still old value');

	throws_ok {
		$self->sut->value('new');
	} qr/read-only/, 'read-only value';
	is($self->sut->value, 'old', 'still old value');

	throws_ok {
		$self->sut->value('old');
	} qr/read-only/, 'read-only value';
	is($self->sut->value, 'old', 'still old value');

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(TypeTestamentTests->new->run());
