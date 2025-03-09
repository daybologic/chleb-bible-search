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

package UtilsBooleanTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use POSIX qw(EXIT_SUCCESS);
use Chleb::Utils;
use Readonly;
use Test::Exception;
use Test::More 0.96;

Readonly my $KEY => 'marketing'; # arbitary
Readonly my $VALUE_UNKNOWN => 'unknown'; # not true nor false

Readonly my @TRUE_VALUES => (qw(
	true
	on
	yes
	1
	enable
	enabled
	enables
));

Readonly my @FALSE_VALUES => (qw(
	false
	off
	no
	0
	disable
	disabled
	disables
));

sub testTrueLower {
	my ($self) = @_;

	plan tests => scalar(@TRUE_VALUES);

	foreach my $v (@TRUE_VALUES) {
		ok(Chleb::Utils::boolean($KEY, $v), "value: $v");
	}

	return EXIT_SUCCESS;
}

sub testTrueUpper {
	my ($self) = @_;

	plan tests => scalar(@TRUE_VALUES);

	foreach my $v (@TRUE_VALUES) {
		my $ucv = uc($v);
		ok(Chleb::Utils::boolean($KEY, $ucv), "value: $ucv");
	}

	return EXIT_SUCCESS;
}

sub testFalseLower {
	my ($self) = @_;

	plan tests => scalar(@FALSE_VALUES) + 2;

	foreach my $v (@FALSE_VALUES) {
		ok(!Chleb::Utils::boolean($KEY, $v), "value: '$v'");
	}

	throws_ok {
		Chleb::Utils::boolean($KEY, undef)
	} qr/^Mandatory value for key '$KEY' not supplied /, 'value: <undef>';

	throws_ok {
		Chleb::Utils::boolean($KEY, $VALUE_UNKNOWN)
	} qr/^Illegal user-supplied value: '$VALUE_UNKNOWN' for key '$KEY' /, "value: '$VALUE_UNKNOWN'";

	return EXIT_SUCCESS;
}

sub testFalseUpper {
	my ($self) = @_;

	plan tests => scalar(@FALSE_VALUES);

	foreach my $v (@FALSE_VALUES) {
		my $ucv = uc($v);
		ok(!Chleb::Utils::boolean($KEY, $ucv), "value: $ucv");
	}

	return EXIT_SUCCESS;
}

sub testDefaultLegal {
	my ($self) = @_;
	plan tests => 4;

	throws_ok {
		Chleb::Utils::boolean($KEY, $VALUE_UNKNOWN, '1')
	} qr/^Illegal user-supplied value: '$VALUE_UNKNOWN' for key '$KEY' /, "$VALUE_UNKNOWN with default 1 is 1";

	throws_ok {
		Chleb::Utils::boolean($KEY, $VALUE_UNKNOWN, '0')
	} qr/^Illegal user-supplied value: '$VALUE_UNKNOWN' for key '$KEY' /, "$VALUE_UNKNOWN with default 0 is 0";

	ok(Chleb::Utils::boolean($KEY, '1', '0'), '1 with default 0 is 1');
	ok(!Chleb::Utils::boolean($KEY, '0', '1'), '0 with default 1 is 0');

	return EXIT_SUCCESS;
}

sub testDefaultLegalUnused {
	plan tests => 2;

	ok(Chleb::Utils::boolean($KEY, '1', '0'), '1 with default 0');
	ok(!Chleb::Utils::boolean($KEY, '0', '1'), '0 with default 1');

	return EXIT_SUCCESS;
}

sub testDefaultLegalUsed {
	plan tests => 6;

	ok(Chleb::Utils::boolean($KEY, undef, 'TRUE'), 'null with default TRUE');
	ok(!Chleb::Utils::boolean($KEY, undef, 'FALSE'), 'null with default FALSE');

	ok(Chleb::Utils::boolean($KEY, undef, '1'), 'null with default 1');
	ok(!Chleb::Utils::boolean($KEY, undef, '0'), 'null with default 0');

	ok(Chleb::Utils::boolean($KEY, '', '1'), 'empty with default 1');
	ok(!Chleb::Utils::boolean($KEY, '', '0'), 'empty with default 0');

	return EXIT_SUCCESS;
}

sub defaultIllegal {
	my ($value, $defaultValue) = @_;

	my $expect = "Illegal default value: '$defaultValue' for key '$KEY'";
	throws_ok {
		Chleb::Utils::boolean($KEY, $value, $defaultValue);
	} qr/^$expect /, $expect;

	return;
}

sub testDefaultIllegal {
	Readonly my @BASE_VALUES => ($VALUE_UNKNOWN, 1, 0);
	plan tests => scalar(@BASE_VALUES);

	foreach my $value (@BASE_VALUES) {
		subtest "value: '$value'" => sub {
			plan tests => 4;

			defaultIllegal($value, " 1");
			defaultIllegal($value, "1 ");
			defaultIllegal($value, " 0");
			defaultIllegal($value, "0 ");
		};
	}

	return EXIT_SUCCESS;
}

sub testDefaultNone {
	my ($self) = @_;

	my $code = sub {
		my ($value) = @_;
		my $descr = 'value ' . (defined($value) ? "'$value'" : '<undef>') . ' is mandatory';
		throws_ok {
			Chleb::Utils::boolean($KEY, $value);
		} qr/^Mandatory value for key '$KEY' not supplied /, $descr;
	};

	my @values = (undef, '', ' ');
	plan tests => scalar(@values);

	foreach my $value (@values) {
		$code->($value);
	}

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(UtilsBooleanTests->new->run());
