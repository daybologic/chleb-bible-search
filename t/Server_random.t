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

package RandomServerTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use POSIX qw(EXIT_SUCCESS);
use Chleb::Bible::DI::Container;
use Chleb::Bible::DI::MockLogger;
use Chleb::Bible::Server;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->__mockLogger();
	$self->sut(Chleb::Bible::Server->new());

	return EXIT_SUCCESS;
}

sub test {
	my ($self) = @_;
	plan tests => 1;

	my $json = $self->sut->__random();
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => ignore(),
					chapter => re(qr/^\d{1,3}$/),
					ordinal => re(qr/^\d{1,2}$/),
					text => ignore(),
				},
				id => re(qr@^\w+/\d{1,3}/\d{1,2}$@),
				type => 'verse',
				links => {
					prev => re(qr@^/1/lookup/\w+/\d{1,3}/\d{1,2}$@),
					self => re(qr@^/1/lookup/\w+/\d{1,3}/\d{1,2}$@),
					next => re(qr@^/1/lookup/\w+/\d{1,3}/\d{1,2}$@),
				},
				relationships => {
					book => {
						data => {
							id => ignore(),
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => ignore(),
							type => 'chapter',
						},
						links => {},
					}
				},
			},
		],
		included => [
			{
				attributes => {
					book => ignore(),
					ordinal => re(qr/^\d{1,2}$/),
				},
				id => re(qr@^\w+/\d{1,3}$@),
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => ignore(),
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					ordinal => re(qr/^\d{1,2}$/),
					testament => re(qr/^\w{3}$/),
				},
				id => ignore(),
				relationships => {},
				type => 'book'
			},
			{
				attributes => {
					msec => re(qr/^\d+$/),
				},
				id => ignore(), # uuid
				type => 'stats',
				links => {},
			},
		],
		links => {
			self => '/1/random',
		},
	}, "single random verse JSON") or diag(explain($json));

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;

	my $dic = Chleb::Bible::DI::Container->instance;
	$dic->logger(Chleb::Bible::DI::MockLogger->new());

	return;
}

package main;
use strict;
use warnings;

exit(RandomServerTests->new->run());
