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

package LookupServerTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use English qw(-no_match_vars);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server;
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

sub test_translation_all {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__lookup({ accept => $mediaType, book => 'Psalms', chapter => 110, verse => 1, translations => [ 'all' ] });
	cmp_deeply($json, {
		data => [
			{
				attributes => {
					book => 'psa',
					chapter => 110,
					ordinal => 1,
					text => 'Jehovah saith unto my Lord, Sit thou at my right hand, Until I make thine enemies thy footstool.',
					translation => 'asv',
				},
				id => 'asv/psa/110/1',
				type => 'verse',
				links => {
					first => '/1/lookup/psa/110/1?translations=all',
					prev  => '/1/lookup/psa/109/31?translations=asv',
					self  => '/1/lookup/psa/110/1?translations=asv',
					next  => '/1/lookup/psa/110/2?translations=asv',
					last  => '/1/lookup/psa/110/7?translations=all',
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
							id => 'asv/psa/110',
							type => 'chapter',
						},
						links => {},
					}
				},
			},
			{
				attributes => {
					book => 'psa',
					chapter => 110,
					ordinal => 1,
					text => 'A Psalm of David. The LORD said unto my Lord, Sit thou at my right hand, until I make thine enemies thy footstool.',
					translation => 'kjv',
				},
				id => 'kjv/psa/110/1',
				type => 'verse',
				links => {
					first => '/1/lookup/psa/110/1?translations=all',
					prev  => '/1/lookup/psa/109/31?translations=kjv',
					self  => '/1/lookup/psa/110/1?translations=kjv',
					next  => '/1/lookup/psa/110/2?translations=kjv',
					last  => '/1/lookup/psa/110/7?translations=all',
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
							id => 'kjv/psa/110',
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
					ordinal => re(qr/^\d{1,3}$/),
					translation => 'asv',
					verse_count => 7,
				},
				id => re(qr@^\w{3}/\w+/\d{1,3}$@),
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
					chapter_count => 150,
					long_name => 'Psalms',
					ordinal => re(qr/^\d{1,2}$/),
					sample_verse_text => ignore(),
					sample_verse_chapter_ordinal => ignore(),
					sample_verse_ordinal_in_chapter => ignore(),
					short_name => 'psa',
					short_name_raw => 'Psa',
					testament => re(qr/^\w{3}$/),
					translation => 'asv',
					verse_count => 2_461,
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
			first => '/1/lookup/psa/110/1?translations=all',
			prev  => '/1/lookup/psa/109/31?translations=all',
			self  => '/1/lookup/psa/110/1?translations=all',
			next  => '/1/lookup/psa/110/2?translations=all',
			last  => '/1/lookup/psa/110/7?translations=all',
		},
	}, 'single random verse JSON');

	return EXIT_SUCCESS;
}

sub test_not_found {
	my ($self) = @_;
	plan tests => 1;

	eval {
		$self->sut->__lookup({ book => 'Acts', chapter => 29, verse => 1, translations => [ 'kjv' ] });
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => 'Chapter 29 not found in Acts',
				location    => undef,
				statusCode  => 404,
			),
		), 'correctly not found');
	} else {
		fail('No exception raised, as was expected');
	}

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(LookupServerTests->new->run());
