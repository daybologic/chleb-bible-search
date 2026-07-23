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

package Utils_queryParamsHelperTests;
## no critic (RegularExpressions::ProhibitComplexRegexes)
## no critic (RegularExpressions::RequireExtendedFormatting)
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Utils;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testEmptyValues {
	my ($self) = @_;
	plan tests => 4;

	is(Chleb::Utils::queryParamsHelper({ translations => [] }), '', 'empty ARRAY values are omitted');
	is(Chleb::Utils::queryParamsHelper({ translations => [''] }), '', 'empty ARRAY content is omitted');
	is(Chleb::Utils::queryParamsHelper({ translations => undef }), '', 'undef values are omitted');
	is(Chleb::Utils::queryParamsHelper({ translations => '' }), '', 'empty scalar values are omitted');

	return EXIT_SUCCESS;
}

sub testEffectiveValues {
	my ($self) = @_;
	plan tests => 3;

	is(Chleb::Utils::queryParamsHelper({ translations => ['asv'] }), '?translations=asv', 'single translation');
	is(Chleb::Utils::queryParamsHelper({ translations => ['asv', 'kjv'] }), '?translations=asv,kjv', 'translation list is preserved');
	like(Chleb::Utils::queryParamsHelper({ testament => 'old', translations => ['kjv'] }), qr/\A\?(?:testament=old&translations=kjv|translations=kjv&testament=old)\z/, 'multiple values are joined correctly');

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;
exit(Utils_queryParamsHelperTests->new->run);
