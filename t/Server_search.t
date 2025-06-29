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

package SearchServerTests;
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
use Chleb::Server::MediaType;
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

	my $term = 'peter';
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__search({
		accept => $mediaType,
		limit => 5,
		term => $term,
		wholeword => 'true',
	});

	cmp_deeply($json, {
		data => [{
			attributes => {
				book => 'mat',
				chapter => 4,
				ordinal => 18,
				text => 'And Jesus, walking by the sea of Galilee, saw two brethren, Simon called Peter, and Andrew his brother, casting a net into the sea: for they were fishers.',
				title => "Result 1/5 from Chleb Bible Search 'peter'",
				translation => 'kjv',
			},
			id => 'kjv/mat/4/18',
			type => 'verse',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
					links => {},
				},
				chapter => {
					data => {
						id => 'kjv/mat/4',
						type => 'chapter',
					},
					links => {},
				},
			},
		}, {
			attributes => {
				book => 'mat',
				chapter => 10,
				ordinal => 2,
				text => 'Now the names of the twelve apostles are these; The first, Simon, who is called Peter, and Andrew his brother; James [the son] of Zebedee, and John his brother;',
				title => 'Result 2/5 from Chleb Bible Search \'peter\'',
				translation => 'kjv',
			},
			id => 'kjv/mat/10/2',
			type => 'verse',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
					links => {},
				},
				chapter => {
					data => {
						id => 'kjv/mat/10',
						type => 'chapter',
					},
					'links' => {},
				},
			},
		}, {
			attributes => {
				book => 'mat',
				chapter => 14,
				ordinal => 28,
				text => 'And Peter answered him and said, Lord, if it be thou, bid me come unto thee on the water.',
				title => 'Result 3/5 from Chleb Bible Search \'peter\'',
				translation => 'kjv',
			},
			id => 'kjv/mat/14/28',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
					links => {},
				},
				chapter => {
					data => {
						id => 'kjv/mat/14',
						type => 'chapter',
					},
					'links' => {},
				},
			},
			type => 'verse',
		}, {
			attributes => {
				book => 'mat',
				chapter => 14,
				ordinal => 29,
				text => 'And he said, Come. And when Peter was come down out of the ship, he walked on the water, to go to Jesus.',
				title => 'Result 4/5 from Chleb Bible Search \'peter\'',
				translation => 'kjv',
			},
			id => 'kjv/mat/14/29',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
					links => {},
				},
				chapter => {
					data => {
						id => 'kjv/mat/14',
						type => 'chapter',
					},
					links => {},
				}
			},
			type => 'verse',
		}, {
			attributes => {
				book => 'mat',
				chapter => 15,
				ordinal => 15,
				text => 'Then answered Peter and said unto him, Declare unto us this parable.',
				title => 'Result 5/5 from Chleb Bible Search \'peter\'',
				translation => 'kjv',
			},
			id => 'kjv/mat/15/15',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
					links => {},
				},
				chapter => {
					data => {
						id => 'kjv/mat/15',
						type => 'chapter',
					},
					links => {},
				},
			},
			type => 'verse',
		}],
		included => [{
			attributes => {
				book => 'mat',
				ordinal => 4,
				translation => 'kjv',
				verse_count => 25,
			},
			id => 'kjv/mat/4',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
				},
			},
			type => 'chapter',
		}, {
			attributes => {
				chapter_count => 28,
				long_name => 'Matthew',
				ordinal => 40,
				sample_verse_text => ignore(),
				sample_verse_chapter_ordinal => ignore(),
				sample_verse_ordinal_in_chapter => ignore(),
				short_name => 'mat',
				short_name_raw => 'Mat',
				testament => 'new',
				translation => 'kjv',
				verse_count => 1_071,
			},
			id => 'kjv/mat',
			relationships => {},
			type => 'book',
		}, {
			attributes => {
				book => 'mat',
				ordinal => 10,
				translation => 'kjv',
				verse_count => 42,
			},
			id => 'kjv/mat/10',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					}
				}
			},
			type => 'chapter',
		}, {
			attributes => {
				chapter_count => 28,
				long_name => 'Matthew',
				ordinal => 40,
				sample_verse_text => ignore(),
				sample_verse_chapter_ordinal => ignore(),
				sample_verse_ordinal_in_chapter => ignore(),
				short_name => 'mat',
				short_name_raw => 'Mat',
				testament => 'new',
				translation => 'kjv',
				verse_count => 1_071,
			},
			id => 'kjv/mat',
			relationships => {},
			type => 'book',
		}, {
			attributes => {
				book => 'mat',
				ordinal => 14,
				translation => 'kjv',
				verse_count => 36,
			},
			id => 'kjv/mat/14',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					}
				},
			},
			type => 'chapter',
		}, {
			attributes => {
				chapter_count => 28,
				long_name => 'Matthew',
				ordinal => 40,
				sample_verse_text => ignore(),
				sample_verse_chapter_ordinal => ignore(),
				sample_verse_ordinal_in_chapter => ignore(),
				short_name => 'mat',
				short_name_raw => 'Mat',
				testament => 'new',
				translation => 'kjv',
				verse_count => 1_071,
			},
			id => 'kjv/mat',
			relationships => {},
			type => 'book',
		}, {
			attributes => {
				book => 'mat',
				ordinal => 14,
				translation => 'kjv',
				verse_count => 36,
			},
			id => 'kjv/mat/14',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
				},
			},
			'type' => 'chapter',
		}, {
			attributes => {
				chapter_count => 28,
				long_name => 'Matthew',
				ordinal => 40,
				sample_verse_text => ignore(),
				sample_verse_chapter_ordinal => ignore(),
				sample_verse_ordinal_in_chapter => ignore(),
				short_name => 'mat',
				short_name_raw => 'Mat',
				testament => 'new',
				translation => 'kjv',
				verse_count => 1_071,
			},
			id => 'kjv/mat',
			relationships => {},
			type => 'book',
		}, {
			attributes => {
				book => 'mat',
				ordinal => 15,
				translation => 'kjv',
				verse_count => 39,
			},
			id => 'kjv/mat/15',
			relationships => {
				book => {
					data => {
						id => 'kjv/mat',
						type => 'book',
					},
				},
			},
			type => 'chapter',
		}, {
			attributes => {
				chapter_count => 28,
				long_name => 'Matthew',
				ordinal => 40,
				sample_verse_text => ignore(),
				sample_verse_chapter_ordinal => ignore(),
				sample_verse_ordinal_in_chapter => ignore(),
				short_name => 'mat',
				short_name_raw => 'Mat',
				testament => 'new',
				translation => 'kjv',
				verse_count => 1_071,
			},
			id => 'kjv/mat',
			relationships => {},
			type => 'book',
		}, {
			attributes => {
				count => 5,
			},
			id => ignore(),
			links => {},
			type => 'results_summary',
		}, {
			attributes => {
				msec => re(qr/^\d+$/),
			},
			id => ignore(),
			links => {},
			type => 'stats',
		}],
		links => {
			self => '/1/search?term=peter&wholeword=1&limit=5',
		},
	}, "wholeword search results for '$term'") or diag(explain($json));

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(SearchServerTests->new->run());
