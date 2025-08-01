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

package ChlebGetTranslationTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use POSIX qw(EXIT_SUCCESS);
use Chleb;
use Test::Deep qw(cmp_deeply);
use Test::Exception;
use Test::More 0.96;

sub testSimple {
	my ($self) = @_;
	plan tests => 4;

	cmp_deeply(Chleb::__getTranslation(undef), 'kjv', 'undef is kjv');
	cmp_deeply(Chleb::__getTranslation(), 'kjv', 'nothing is kjv');
	cmp_deeply(Chleb::__getTranslation('kjv'), 'kjv', 'kjv is kjv');
	cmp_deeply(Chleb::__getTranslation('asv'), 'asv', 'asv is asv');

	return EXIT_SUCCESS;
}

sub testArray {
	my ($self) = @_;
	plan tests => 4;

	my @list = Chleb::__getTranslation({ translations => [ undef, 'kjv', undef, 'asv', undef ] });
	cmp_deeply(\@list, ['kjv', 'asv'], 'two-item array produces correct list, even polluted with <undef>');

	@list = Chleb::__getTranslation({ translations => [ 'asv' ] });
	cmp_deeply(\@list, ['asv'], 'asv only');

	@list = Chleb::__getTranslation({ translations => [ undef ] });
	cmp_deeply(\@list, ['kjv'], 'kjv default with undef');

	@list = Chleb::__getTranslation({ translations => [ ] });
	cmp_deeply(\@list, ['kjv'], 'kjv default with []');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(ChlebGetTranslationTests->new->run());
