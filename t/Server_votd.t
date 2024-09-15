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
use Religion::Bible::Verses::DI::Container;
use Religion::Bible::Verses::DI::MockLogger;
use Religion::Bible::Verses::Server;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->__mockLogger();
	$self->sut(Religion::Bible::Verses::Server->new());

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
					book => 'Hab',
					chapter => 2,
					ordinal => 15,
					text => 'Woe unto him that giveth his neighbour drink, that puttest thy bottle to [him], and makest [him] drunken also, that thou mayest look on their nakedness!',
				},
				id => 'hab/2/15',
				type => 'verse',
				links => {
					self => '/1/lookup/hab/2/15',
				},
				relationships => {
					book => {
						data => {
							id => 'hab',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'hab/2',
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
					book => 'Hab',
					ordinal => 2,
				},
				id => 'hab/2',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'hab',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					ordinal => 35,
					testament => 'old',
				},
				id => 'hab',
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

	my $when = '2024-08-19T12:00:00+0100';
	my $json = $self->sut->__votd({ version => 2, when => '2024-08-19T12:00:00+0100' });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'Titus',
					chapter => 2,
					ordinal => 11,
					text => 'For the grace of God that bringeth salvation hath appeared to all men,',
				},
				id => 'titus/2/11',
				type => 'verse',
				links => {
					self => '/1/lookup/titus/2/11',
				},
				relationships => {
					book => {
						data => {
							id => 'titus',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'titus/2',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'Titus',
					chapter => 2,
					ordinal => 12,
					text => 'Teaching us that, denying ungodliness and worldly lusts, we should live soberly, righteously, and godly, in this present world;',
				},
				id => 'titus/2/12',
				type => 'verse',
				links => {
					self => '/1/lookup/titus/2/12',
				},
				relationships => {
					book => {
						data => {
							id => 'titus',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'titus/2',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'Titus',
					chapter => 2,
					ordinal => 13,
					text => 'Looking for that blessed hope, and the glorious appearing of the great God and our Saviour Jesus Christ;',
				},
				id => 'titus/2/13',
				type => 'verse',
				links => {
					self => '/1/lookup/titus/2/13',
				},
				relationships => {
					book => {
						data => {
							id => 'titus',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'titus/2',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'Titus',
					chapter => 2,
					ordinal => 14,
					text => 'Who gave himself for us, that he might redeem us from all iniquity, and purify unto himself a peculiar people, zealous of good works.',
				},
				id => 'titus/2/14',
				type => 'verse',
				links => {
					self => '/1/lookup/titus/2/14',
				},
				relationships => {
					book => {
						data => {
							id => 'titus',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'titus/2',
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
					book => 'Titus',
					ordinal => 2,
				},
				id => 'titus/2',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'titus',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					ordinal => 56,
					testament => 'new',
				},
				id => 'titus',
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

	my $dic = Religion::Bible::Verses::DI::Container->instance;
	$dic->logger(Religion::Bible::Verses::DI::MockLogger->new());

	return;
}

package main;
use strict;
use warnings;

exit(VotdServerTests->new->run());
