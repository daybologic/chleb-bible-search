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

package VotdServerTests;
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

	my $when = '2024-08-23T11:49:09+0100';
	my $json = $self->sut->__votd({ when => $when });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'Psa',
					chapter => 55,
					ordinal => 22,
					text => 'Cast thy burden upon the LORD, and he shall sustain thee: he shall never suffer the righteous to be moved.',
				},
				id => 'psa/55/22',
				type => 'verse',
				links => {
					prev => '/1/lookup/psa/55/21',
					self => '/1/lookup/psa/55/22',
					next => '/1/lookup/psa/55/23',
				},
				relationships => {
					book => {
						data => {
							id => 'psa',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'psa/55',
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
					book => 'Psa',
					ordinal => 55,
				},
				id => 'psa/55',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'psa',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					ordinal => 19,
					testament => 'old',
				},
				id => 'psa',
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
			self => '/1/votd',
		},
	}, "single verse JSON for $when") or diag(explain($json));

	return EXIT_SUCCESS;
}

sub testV2 {
	my ($self) = @_;
	plan tests => 1;

	my $when = '1971-04-28T12:00:00+0100';
	my $json = $self->sut->__votd({ version => 2, when => $when });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'Num',
					chapter => 33,
					ordinal => 51,
					text => 'Speak unto the children of Israel, and say unto them, When ye are passed over Jordan into the land of Canaan;',
				},
				id => 'num/33/51',
				type => 'verse',
				links => {
					prev => '/1/lookup/num/33/50',
					self => '/1/lookup/num/33/51',
					next => '/1/lookup/num/33/52',
				},
				relationships => {
					book => {
						data => {
							id => 'num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'num/33',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'Num',
					chapter => 33,
					ordinal => 52,
					text    => 'Then ye shall drive out all the inhabitants of the land from before you, and destroy all their pictures, and destroy all their molten images, and quite pluck down all their high places:',
				},
				id => 'num/33/52',
				type => 'verse',
				links => {
					prev => '/1/lookup/num/33/51',
					self => '/1/lookup/num/33/52',
					next => '/1/lookup/num/33/53',
				},
				relationships => {
					book => {
						data => {
							id => 'num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'num/33',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'Num',
					chapter => 33,
					ordinal => 53,
					text    => 'And ye shall dispossess [the inhabitants] of the land, and dwell therein: for I have given you the land to possess it.',
				},
				id => 'num/33/53',
				type => 'verse',
				links => {
					prev => '/1/lookup/num/33/52',
					self => '/1/lookup/num/33/53',
					next => '/1/lookup/num/33/54',
				},
				relationships => {
					book => {
						data => {
							id => 'num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'num/33',
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
					book => 'Num',
					ordinal => 33,
				},
				id => 'num/33',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'num',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					ordinal => 4,
					testament => 'old',
				},
				id => 'num',
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
			self => '/2/votd',
		},
	}, "specific JSON verses inspection for $when") or diag(explain($json));

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

exit(VotdServerTests->new->run());
