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

package SearchServerTests;
## no critic (RegularExpressions::ProhibitComplexRegexes)
## no critic (RegularExpressions::RequireExtendedFormatting)
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
use strict;
use warnings;
use Carp qw(croak);
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server::Moose;
use Chleb::Server::MediaType;
use English qw(-no_match_vars);
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server::Moose->new());

	return EXIT_SUCCESS;
}

sub test {
	my ($self) = @_;
	plan tests => 1;

	my $term = 'peter';
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__search({
		accept => $mediaType,
		limit => 153,
		per_page => 5,
		term => $term,
		wholeword => 'true',
	});

	cmp_deeply($json, {
		data => [{
			attributes => {
				book => 'mat',
				chapter => 4,
				emotion => 'neutral',
				ordinal => 18,
				text => 'And Jesus, walking by the sea of Galilee, saw two brethren, Simon called Peter, and Andrew his brother, casting a net into the sea: for they were fishers.',
				tones => [],
				title => "Result 1/153 from Chleb Bible Search 'peter'",
				year => 1611,
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
				emotion => 'neutral',
				ordinal => 2,
				text => 'Now the names of the twelve apostles are these; The first, Simon, who is called Peter, and Andrew his brother; James [the son] of Zebedee, and John his brother;',
				tones => [],
				title => 'Result 2/153 from Chleb Bible Search \'peter\'',
				year => 1611,
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
				emotion => 'hope',
				ordinal => 28,
				text => 'And Peter answered him and said, Lord, if it be thou, bid me come unto thee on the water.',
				tones => ['encouragement', 'trust'],
				title => 'Result 3/153 from Chleb Bible Search \'peter\'',
				year => 1611,
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
				emotion => 'hope',
				ordinal => 29,
				text => 'And he said, Come. And when Peter was come down out of the ship, he walked on the water, to go to Jesus.',
				tones => ['encouragement', 'trust'],
				title => 'Result 4/153 from Chleb Bible Search \'peter\'',
				year => 1611,
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
				emotion => 'neutral',
				ordinal => 15,
				text => 'Then answered Peter and said unto him, Declare unto us this parable.',
				tones => [],
				title => 'Result 5/153 from Chleb Bible Search \'peter\'',
				year => 1611,
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
					page => 1,
					per_page => 5,
					total_count => 153,
					total_pages => 31,
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
				first => '/1/search?term=peter&wholeword=1&limit=153&page=1&per_page=5',
				last => '/1/search?term=peter&wholeword=1&limit=153&page=31&per_page=5',
				next => '/1/search?term=peter&wholeword=1&limit=153&page=2&per_page=5',
				self => '/1/search?term=peter&wholeword=1&limit=153&page=1&per_page=5',
			},
		}, "wholeword search results for '$term'") or diag(explain($json));

	return EXIT_SUCCESS;
}

sub testSecondPage {
	my ($self) = @_;
	plan tests => 5;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__search({
		accept => $mediaType,
		limit => 153,
		page => 2,
		per_page => 5,
		term => 'peter',
		wholeword => 'true',
	});
	my $summary = __resultsSummary($json);

	is(scalar(@{ $json->{data} }), 5, 'second page result count');
	is($json->{data}->[0]->{id}, 'kjv/mat/16/16', 'second page first result');
	is($json->{data}->[0]->{attributes}->{title}, 'Result 6/153 from Chleb Bible Search \'peter\'', 'second page title offset');
	is($summary->{page}, 2, 'second page summary');
	is_deeply($json->{links}, {
		first => '/1/search?term=peter&wholeword=1&limit=153&page=1&per_page=5',
		last => '/1/search?term=peter&wholeword=1&limit=153&page=31&per_page=5',
		next => '/1/search?term=peter&wholeword=1&limit=153&page=3&per_page=5',
		prev => '/1/search?term=peter&wholeword=1&limit=153&page=1&per_page=5',
		self => '/1/search?term=peter&wholeword=1&limit=153&page=2&per_page=5',
	}, 'second page pagination links');

	return EXIT_SUCCESS;
}

sub testEmptyResults {
	my ($self) = @_;
	plan tests => 4;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__search({
		accept => $mediaType,
		page => 1,
		per_page => 5,
		term => 'zzzznotfoundzzzz',
	});
	my $summary = __resultsSummary($json);

	is(scalar(@{ $json->{data} }), 0, 'empty search has no data');
	is($summary->{total_count}, 0, 'empty search total count');
	is($summary->{total_pages}, 1, 'empty search has one logical page');
	is_deeply($json->{links}, {
		first => '/1/search?term=zzzznotfoundzzzz&wholeword=0&limit=50&page=1&per_page=5',
		last => '/1/search?term=zzzznotfoundzzzz&wholeword=0&limit=50&page=1&per_page=5',
		self => '/1/search?term=zzzznotfoundzzzz&wholeword=0&limit=50&page=1&per_page=5',
	}, 'empty search pagination links');

	return EXIT_SUCCESS;
}

sub testInvalidPageValues {
	my ($self) = @_;
	plan tests => 3;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__search({
		accept => $mediaType,
		limit => 153,
		page => -4,
		per_page => 5,
		term => 'peter',
		wholeword => 'true',
	});
	my $summary = __resultsSummary($json);

	is($summary->{page}, 1, 'negative page becomes first page');
	is($json->{links}->{self}, '/1/search?term=peter&wholeword=1&limit=153&page=1&per_page=5', 'self link uses normalized page');
	is($json->{data}->[0]->{id}, 'kjv/mat/4/18', 'normalized invalid page returns first page results');

	return EXIT_SUCCESS;
}

sub testHtmlPaginationPreservesQuery {
	my ($self) = @_;
	plan tests => 7;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my ($html) = $self->sut->__search({
		accept => $mediaType,
		form => 1,
		limit => 153,
		page => 2,
		per_page => 5,
		term => 'peter',
		wholeword => 'true',
	});

	like($html, qr{<nav class="pagination"}, 'HTML includes pagination nav');
	like($html, qr{<th>Result</th>\s*<th>Translation</th>\s*<th>Verse</th>}s,
		'HTML places the translation column between result and verse');
	like($html, qr{<td>Result 6/153 from Chleb Bible Search 'peter'</td>\s*<td>kjv</td>}s,
		'HTML renders the translation from the JSON result attributes');
	like($html, qr{/1/search[?]term=peter&wholeword=1&limit=153&page=1&per_page=5&form=true">Previous</a>}, 'HTML previous link preserves query');
	like($html, qr{/1/search[?]term=peter&wholeword=1&limit=153&page=3&per_page=5&form=true">Next</a>}, 'HTML next link preserves query');
	like($html, qr{/1/search[?]term=peter&wholeword=1&limit=153&page=1&per_page=5&form=true">1</a>}, 'HTML page number preserves query');
	like($html, qr{<strong>2</strong>}, 'HTML marks current page');

	return EXIT_SUCCESS;
}

sub testWholeWordPunctuation {
	my ($self) = @_;
	plan tests => 3;

	my $term = 'pricks';
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__search({
		accept => $mediaType,
		limit => 2,
		term => $term,
		wholeword => 'true',
	});

	is(scalar(@{ $json->{data} }), 2, 'two results, as expected');

	# assertions to verify the content of the results
	my $counter = 0;
	foreach my $result (@{ $json->{data} }) {
		like($result->{attributes}->{text}, qr/\b$term\b/, sprintf("Result (%d/2) text contains the term '%s'", ++$counter, $term));
	}

	return EXIT_SUCCESS;
}

sub testSearchSelectedTranslation {
	my ($self) = @_;
	plan skip_all => 'Pickthall test data is not installed' unless $self->hasTranslation('pickthall');
	plan tests => 4;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	my $json = $self->sut->__search({
		accept => $mediaType,
		limit => 2,
		term => 'Allah',
		translations => ['pickthall'],
		wholeword => 'true',
	});

	ok(scalar(@{ $json->{data} }) > 0, 'selected translation returns search results');
	is($json->{data}->[0]->{attributes}->{translation}, 'pickthall', 'result uses selected translation');
	like($json->{links}->{self}, qr{translations=pickthall}, 'pagination links preserve selected translation');

	my $bookJson = $self->sut->__search({
		accept => $mediaType,
		book => 'quran',
		limit => 2,
		term => 'Allah',
		translations => ['pickthall'],
		wholeword => 'true',
	});
	is($bookJson->{data}->[0]->{attributes}->{book}, 'quran', 'selected book filters search results');

	return EXIT_SUCCESS;
}

sub __resultsSummary {
	my ($json) = @_;

	foreach my $included (@{ $json->{included} }) {
		return $included->{attributes} if ($included->{type} eq 'results_summary');
	}

	croak('results summary not found');
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(SearchServerTests->new->run());
