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

package VotdServerTests;
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
use English qw(-no_match_vars);
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server->new());

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
					book => 'psa',
					chapter => 55,
					ordinal => 22,
					text => 'Cast thy burden upon the LORD, and he shall sustain thee: he shall never suffer the righteous to be moved.',
					translation => 'kjv',
				},
				id => 'kjv/psa/55/22',
				type => 'verse',
				links => {
					first => '/1/lookup/psa/55/1',
					prev  => '/1/lookup/psa/55/21',
					self  => '/1/lookup/psa/55/22',
					next  => '/1/lookup/psa/55/23',
					last  => '/1/lookup/psa/55/23',
				},
				relationships => {
					book => {
						data => {
							id => 'kjv/psa',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'kjv/psa/55',
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
					book => 'psa',
					ordinal => 55,
					translation => 'kjv',
					verse_count => 23,
				},
				id => 'kjv/psa/55',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'kjv/psa',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					chapter_count => 150,
					long_name => 'Psalms',
					ordinal => 19,
					sample_verse_text => ignore(),
					sample_verse_chapter_ordinal => ignore(),
					sample_verse_ordinal_in_chapter => ignore(),
					short_name => 'psa',
					short_name_raw => 'Psa',
					testament => 'old',
					translation => 'kjv',
					verse_count => 2_461,
				},
				id => 'kjv/psa',
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
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__votd({ version => 2, when => $when, accept => $mediaType });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'num',
					chapter => 33,
					ordinal => 51,
					text => 'Speak unto the children of Israel, and say unto them, When ye are passed over Jordan into the land of Canaan;',
					translation => 'kjv',
				},
				id => 'kjv/num/33/51',
				type => 'verse',
				links => {
					first => '/1/lookup/num/33/1',
					prev  => '/1/lookup/num/33/50',
					self  => '/1/lookup/num/33/51',
					next  => '/1/lookup/num/33/52',
					last  => '/1/lookup/num/33/56',
				},
				relationships => {
					book => {
						data => {
							id => 'kjv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'kjv/num/33',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'num',
					chapter => 33,
					ordinal => 52,
					text    => 'Then ye shall drive out all the inhabitants of the land from before you, and destroy all their pictures, and destroy all their molten images, and quite pluck down all their high places:',
					translation => 'kjv',
				},
				id => 'kjv/num/33/52',
				type => 'verse',
				links => {
					first => '/1/lookup/num/33/1',
					prev  => '/1/lookup/num/33/51',
					self  => '/1/lookup/num/33/52',
					next  => '/1/lookup/num/33/53',
					last  => '/1/lookup/num/33/56',
				},
				relationships => {
					book => {
						data => {
							id => 'kjv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'kjv/num/33',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'num',
					chapter => 33,
					ordinal => 53,
					text    => 'And ye shall dispossess [the inhabitants] of the land, and dwell therein: for I have given you the land to possess it.',
					translation => 'kjv',
				},
				id => 'kjv/num/33/53',
				type => 'verse',
				links => {
					first => '/1/lookup/num/33/1',
					prev  => '/1/lookup/num/33/52',
					self  => '/1/lookup/num/33/53',
					next  => '/1/lookup/num/33/54',
					last  => '/1/lookup/num/33/56',
				},
				relationships => {
					book => {
						data => {
							id => 'kjv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'kjv/num/33',
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
					book => 'num',
					ordinal => 33,
					translation => 'kjv',
					verse_count => 56,
				},
				id => 'kjv/num/33',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'kjv/num',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					chapter_count => 36,
					long_name => 'Numbers',
					ordinal => 4,
					sample_verse_text => ignore(),
					sample_verse_chapter_ordinal => ignore(),
					sample_verse_ordinal_in_chapter => ignore(),
					short_name => 'num',
					short_name_raw => 'Num',
					testament => 'old',
					translation => 'kjv',
					verse_count => 1_288,
				},
				id => 'kjv/num',
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

sub testV2_translations_asv_asv {
	my ($self) = @_;
	plan tests => 1;

	my $when = '2024-10-30T21:36:26+0000';
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__votd({ accept => $mediaType, version => 2, when => $when, translations => ['asv', 'asv'] });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'psa',
					chapter => 122,
					ordinal => 8,
					text => "For my brethren and companions' sakes, I will now say, Peace be within thee.",
					translation => 'asv',
				},
				id => 'asv/psa/122/8',
				type => 'verse',
				links => {
					first => '/1/lookup/psa/122/1?translations=asv',
					prev  => '/1/lookup/psa/122/7?translations=asv',
					self  => '/1/lookup/psa/122/8?translations=asv',
					next  => '/1/lookup/psa/122/9?translations=asv',
					last  => '/1/lookup/psa/122/9?translations=asv',
				},
				relationships => {
					book => {
						data => {
							id => 'asv/psa',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'asv/psa/122',
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
					book => 'psa',
					ordinal => 122,
					translation => 'asv',
					verse_count => 9,
				},
				id => 'asv/psa/122',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'asv/psa',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					chapter_count => 150,
					long_name => 'Psalms',
					ordinal => 19,
					sample_verse_text => ignore(),
					sample_verse_chapter_ordinal => ignore(),
					sample_verse_ordinal_in_chapter => ignore(),
					short_name => 'psa',
					short_name_raw => 'Psa',
					testament => 'old',
					translation => 'asv',
					verse_count => 2_461,
				},
				id => 'asv/psa',
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
			self => '/2/votd?translations=asv',
		},
	}, "specific JSON verses inspection for $when (asv)") or diag(explain($json));

	return EXIT_SUCCESS;
}

sub testV2_translations_kjv_asv {
	my ($self) = @_;
	plan tests => 1;

	my $when = '2024-10-30T21:36:26+0000';
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__votd({ accept => $mediaType, version => 2, when => $when, translations => ['kjv', 'asv'] });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'psa',
					chapter => 122,
					ordinal => 8,
					text => "For my brethren and companions' sakes, I will now say, Peace be within thee.",
					translation => 'asv',
				},
				id => 'asv/psa/122/8',
				type => 'verse',
				links => {
					first => '/1/lookup/psa/122/1?translations=all',
					prev  => '/1/lookup/psa/122/7?translations=asv',
					self  => '/1/lookup/psa/122/8?translations=asv',
					next  => '/1/lookup/psa/122/9?translations=asv',
					last  => '/1/lookup/psa/122/9?translations=all',
				},
				relationships => {
					book => {
						data => {
							id => 'asv/psa',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'asv/psa/122',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'psa',
					chapter => 122,
					ordinal => 8,
					text => "For my brethren and companions' sakes, I will now say, Peace [be] within thee.",
					translation => 'kjv',
				},
				id => 'kjv/psa/122/8',
				type => 'verse',
				links => {
					first => '/1/lookup/psa/122/1?translations=all',
					prev  => '/1/lookup/psa/122/7?translations=kjv',
					self  => '/1/lookup/psa/122/8?translations=kjv',
					next  => '/1/lookup/psa/122/9?translations=kjv',
					last  => '/1/lookup/psa/122/9?translations=all',
				},
				relationships => {
					book => {
						data => {
							id => 'kjv/psa',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'kjv/psa/122',
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
					book => 'psa',
					ordinal => 122,
					translation => 'asv',
					verse_count => 9,
				},
				id => 'asv/psa/122',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'asv/psa',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					chapter_count => 150,
					long_name => 'Psalms',
					ordinal => 19,
					sample_verse_text => ignore(),
					sample_verse_chapter_ordinal => ignore(),
					sample_verse_ordinal_in_chapter => ignore(),
					short_name => 'psa',
					short_name_raw => 'Psa',
					testament => 'old',
					translation => 'asv',
					verse_count => 2_461,
				},
				id => 'asv/psa',
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
			self => '/2/votd?translations=all',
		},
	}, "specific JSON verses inspection for $when (asv)") or diag(explain($json));

	return EXIT_SUCCESS;
}

sub testV2_translations_all {
	my ($self) = @_;
	plan tests => 1;

	my $when = '2021-10-30T21:36:26+0000';
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__votd({ accept => $mediaType, version => 2, when => $when, translations => ['all'] });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'num',
					chapter => 16,
					ordinal => 8,
					text => 'And Moses said unto Korah, Hear now, ye sons of Levi:',
					translation => 'asv',
				},
				id => 'asv/num/16/8',
				type => 'verse',
				links => {
					first => '/1/lookup/num/16/1?translations=all',
					prev  => '/1/lookup/num/16/7?translations=asv',
					self  => '/1/lookup/num/16/8?translations=asv',
					next  => '/1/lookup/num/16/9?translations=asv',
					last  => '/1/lookup/num/16/50?translations=all',
				},
				relationships => {
					book => {
						data => {
							id => 'asv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'asv/num/16',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'num',
					chapter => 16,
					ordinal => 9,
					text => '[seemeth it but] a small thing unto you, that the God of Israel hath separated you from the congregation of Israel, to bring you near to himself, to do the service of the tabernacle of Jehovah, and to stand before the congregation to minister unto them;',
					translation => 'asv',
				},
				id => 'asv/num/16/9',
				type => 'verse',
				links => {
					first => '/1/lookup/num/16/1?translations=all',
					prev  => '/1/lookup/num/16/8?translations=asv',
					self  => '/1/lookup/num/16/9?translations=asv',
					next  => '/1/lookup/num/16/10?translations=asv',
					last  => '/1/lookup/num/16/50?translations=all',
				},
				relationships => {
					book => {
						data => {
							id => 'asv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'asv/num/16',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'num',
					chapter => 16,
					ordinal => 10,
					text => 'and that he hath brought thee near, and all thy brethren the sons of Levi with thee? and seek ye the priesthood also?',
					translation => 'asv',
				},
				id => 'asv/num/16/10',
				type => 'verse',
				links => {
					first => '/1/lookup/num/16/1?translations=all',
					prev  => '/1/lookup/num/16/9?translations=asv',
					self  => '/1/lookup/num/16/10?translations=asv',
					next  => '/1/lookup/num/16/11?translations=asv',
					last  => '/1/lookup/num/16/50?translations=all',
				},
				relationships => {
					book => {
						data => {
							id => 'asv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'asv/num/16',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'num',
					chapter => 16,
					ordinal => 8,
					text => 'And Moses said unto Korah, Hear, I pray you, ye sons of Levi:',
					translation => 'kjv',
				},
				id => 'kjv/num/16/8',
				type => 'verse',
				links => {
					first => '/1/lookup/num/16/1?translations=all',
					prev  => '/1/lookup/num/16/7?translations=kjv',
					self  => '/1/lookup/num/16/8?translations=kjv',
					next  => '/1/lookup/num/16/9?translations=kjv',
					last  => '/1/lookup/num/16/50?translations=all',
				},
				relationships => {
					book => {
						data => {
							id => 'kjv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'kjv/num/16',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'num',
					chapter => 16,
					ordinal => 9,
					text => '[Seemeth it but] a small thing unto you, that the God of Israel hath separated you from the congregation of Israel, to bring you near to himself to do the service of the tabernacle of the LORD, and to stand before the congregation to minister unto them?',
					translation => 'kjv',
				},
				id => 'kjv/num/16/9',
				type => 'verse',
				links => {
					first => '/1/lookup/num/16/1?translations=all',
					prev  => '/1/lookup/num/16/8?translations=kjv',
					self  => '/1/lookup/num/16/9?translations=kjv',
					next  => '/1/lookup/num/16/10?translations=kjv',
					last  => '/1/lookup/num/16/50?translations=all',
				},
				relationships => {
					book => {
						data => {
							id => 'kjv/num',
							type => 'book',
						},
						links => {},
					},
					chapter => {
						data => {
							id => 'kjv/num/16',
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
					book => 'num',
					ordinal => 16,
					translation => 'asv',
					verse_count => 50,
				},
				id => 'asv/num/16',
				type => 'chapter',
				relationships => {
					book => {
						data => {
							id => 'asv/num',
							type => 'book',
						},
					},
				},
			},
			{
				attributes => {
					chapter_count => 36,
					long_name => 'Numbers',
					ordinal => 4,
					sample_verse_text => ignore(),
					sample_verse_chapter_ordinal => ignore(),
					sample_verse_ordinal_in_chapter => ignore(),
					short_name => 'num',
					short_name_raw => 'Num',
					testament => 'old',
					translation => 'asv',
					verse_count => 1_288,
				},
				id => 'asv/num',
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
			self => '/2/votd?translations=all',
		},
	}, "specific JSON verses inspection for $when (asv)") or diag(explain($json));

	return EXIT_SUCCESS;
}

sub testRedirectV2 {
	my ($self) = @_;

	eval {
		$self->sut->__votd({ redirect => 1, version => 2 });
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => 'votd redirect is only supported on version 1',
				statusCode  => 400,
			),
		), 'correct error');
	} else {
		fail('No exception raised, as was expected');
	}

	return EXIT_SUCCESS;
}

sub testRedirectV1 {
	my ($self) = @_;

	eval {
		my $when = '2021-10-30T21:36:26+0000';
		$self->sut->__votd({ redirect => 1, version => 1, when => $when });
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => undef,
				location    => '/1/lookup/num/16/8',
				statusCode  => 307,
			),
		), 'correct redirect');
	} else {
		fail('No exception raised, as was expected');
	}

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(VotdServerTests->new->run());
