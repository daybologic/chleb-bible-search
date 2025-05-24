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

package LinkToVerseServerTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server->new());

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 4;

	my $linkText = $self->uniqueStr();
	my $html = Chleb::Server::__linkToVerse($linkText, 'Gen', 22, 4, { includeBookName => 1 });
	is($html, '<a href="/1/lookup/gen/22/4">' . $linkText . '</a>', 'html with linkText');

	$html = Chleb::Server::__linkToVerse(undef, 'Gen', 22, 4, { includeBookName => 1 });
	is($html, '<a href="/1/lookup/gen/22/4">' . 'Gen [22:4]' . '</a>', 'html without linkText');

	$html = Chleb::Server::__linkToVerse(undef, 'Gen', 22, 4, { includeBookName => 0 });
	is($html, '<a href="/1/lookup/gen/22/4">' . '[22:4]' . '</a>', 'html without linkText and with includeBookName not set');

	$html = Chleb::Server::__linkToVerse(undef, 'Gen', 22, 4);
	is($html, '<a href="/1/lookup/gen/22/4">' . '[22:4]' . '</a>', 'html without linkText and without options');

	return EXIT_SUCCESS;
}

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	throws_ok {
		Chleb::Server::__linkToVerse(undef, 'Gen', 22, 4, { illegalOption => 'whatever' });
	} qr/unknown option -- illegalOption/, 'trap unknown option';

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(LinkToVerseServerTests->new->run());
