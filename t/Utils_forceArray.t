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

package UtilsForceArrayTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use POSIX qw(EXIT_SUCCESS);
use Chleb::Utils;
use Test::Exception;
use Test::More 0.96;

sub testSuccess {
	my ($self) = @_;
	plan tests => 9;

	is_deeply(Chleb::Utils::forceArray(), [], 'empty is empty ARRAY');
	is_deeply(Chleb::Utils::forceArray(undef), [undef], 'undef is ARRAY containing undef');
	is_deeply(Chleb::Utils::forceArray([]), [], 'empty ARRAY is empty ARRAY');
	is_deeply(Chleb::Utils::forceArray(['x', 1, undef]), ['x', 1, undef], 'normal ARRAY');
	is_deeply(Chleb::Utils::forceArray('x', 1, undef), ['x', 1, undef], 'list becomes ARRAY');
	is_deeply(Chleb::Utils::forceArray('x'), ['x'], 'SCALAR becomes ARRAY');
	is_deeply(Chleb::Utils::forceArray('x,y,z'), ['x','y','z'], 'comma-separated list become ARRAY');
	is_deeply(Chleb::Utils::forceArray(['x,y,z']), ['x','y','z'], 'comma-separated ARRAY is exploded ARRAY');

	is_deeply(Chleb::Utils::forceArray(['a,b,c'], 'd,e', 'f,g', ['h,i']), ['a','b','c','d','e','f','g','h','i'],
	    'comma-separated multi-ARRAY');

	return EXIT_SUCCESS;
}

sub testFailure {
	my ($self) = @_;
	plan tests => 3;

	subtest 'scalar' => sub {
		plan tests => 2;

		throws_ok { Chleb::Utils::forceArray($self) } qr/no blessed object support/;
		throws_ok { Chleb::Utils::forceArray(sub { }) } qr/no CODE support/;
	};

	subtest 'list' => sub {
		plan tests => 2;

		throws_ok { Chleb::Utils::forceArray(1, $self) } qr/no blessed object support/;
		throws_ok { Chleb::Utils::forceArray(1, sub { }) } qr/no CODE support/;
	};

	subtest 'array' => sub {
		plan tests => 2;

		throws_ok { Chleb::Utils::forceArray([1, $self]) } qr/no blessed object support/;
		throws_ok { Chleb::Utils::forceArray([1, sub { }]) } qr/no CODE support/;
	};

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(UtilsForceArrayTests->new->run());
