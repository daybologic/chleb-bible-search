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

package Utils_OSError_Mapper_Tests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Chleb::Utils::OSError::Mapper;
use Errno;
use HTTP::Status qw(:constants);
use POSIX;
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Utils::OSError::Mapper->new());

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	is($self->sut->map(undef), HTTP_OK, '<undef> -> 200 OK');
	is($self->sut->map(0), HTTP_OK, '0 -> 200 OK');

	return EXIT_SUCCESS;
}

sub testKnownMappings {
	my ($self) = @_;
	plan tests => 3;

	# TODO
	# nb. don't list everything here!  Maybe I shall but it might be long-winded,
	# at least we could see what happens on GitHub/SourceHut/BitBucket.

	is($self->sut->map(int(ENOENT)), HTTP_NOT_FOUND, 'ENOENT -> 404 Not Found');
	is($self->sut->map(int(EHOSTDOWN)), HTTP_BAD_GATEWAY, 'EHOSTDOWN -> 502 Bad Gateway');
	is($self->sut->map(int(EPIPE)), HTTP_INTERNAL_SERVER_ERROR, 'EPIPE -> 500 Internal Server Error');

	return EXIT_SUCCESS;
}

sub testUnknownMappings {
	my ($self) = @_;
	plan tests => 2;

	is($self->sut->map(-1), HTTP_INTERNAL_SERVER_ERROR, '-1 -> 500 Internal Server Error');
	is($self->sut->map(0xFFFFFFFF), HTTP_INTERNAL_SERVER_ERROR, '0xFFFFFFFF -> 500 Internal Server Error');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(Utils_OSError_Mapper_Tests->new->run());
