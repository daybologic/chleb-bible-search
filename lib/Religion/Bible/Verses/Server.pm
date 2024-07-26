#!/usr/bin/perl
# Bible Query Verses Framework
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

package Religion::Bible::Verses::Server;
use strict;
use warnings;
use Data::Dumper;
use JSON;
use Religion::Bible::Verses;
use UUID::Tiny ':std';

use base qw(Net::Server::PreForkSimple);

sub __makeJsonApi {
	return (
		data => [ ],
		included => [ ],
		links => { },
	);
}

sub __json {
	my ($self) = @_;
	$self->{__json} ||= JSON->new();
	return $self->{__json};
}

sub __bible {
	my ($self) = @_;
	$self->{__bible} ||= Religion::Bible::Verses->new();
	return $self->{__bible};
}

sub __lookup {
	my ($self, $params) = @_;
	my $verse = $self->__bible->fetch($params->{book}, $params->{chapter}, $params->{verse});
	return { result => $verse->toString() };
}

sub __search {
	my ($self, $search) = @_;

	my $query = $self->__bible->newSearchQuery($search->{term})->setLimit(5);
	my $results = $query->run();

	my %hash = __makeJsonApi();

	for (my $i = 0; $i < $results->count; $i++) {
		my $verse = $results->verses->[$i];

		my %attributes = ( %{ $verse->TO_JSON() } );
		$attributes{title} = sprintf("Result %d/%d from bible search '%s'", $i+1, $results->count, $search->{term});

		push(@{ $hash{included} }, {
			type => $verse->chapter->type,
			id => $verse->chapter->id,
			attributes => $verse->chapter->TO_JSON(),
			relationships => {
				book => {
					data => {
						type => $verse->book->type,
						id => $verse->book->id,
					},
				}
			},
		});

		push(@{ $hash{included} }, {
			type => $verse->book->type,
			id => $verse->book->id,
			attributes => $verse->book->TO_JSON(),
			relationships => { },
		});

		push(@{ $hash{data} }, {
			type => $verse->type,
			id => $verse->id,
			attributes => \%attributes,
			relationships => {
				chapter => {
					links => { },
					data => {
						type => $verse->chapter->type,
						id => $verse->chapter->id,
					},
				},
				book => {
					links => { },
					data => {
						type => $verse->book->type,
						id => $verse->book->id,
					},
				},
			},
		});
	}

	push(@{ $hash{included} }, {
		type => 'results_summary',
		id => uuid_to_string(create_uuid()),
		attributes => {
			count => $results->count,
		},
		links => { },
	});

	return \%hash;
}

sub __votd {
	my ($self) = @_;
	return { result => $self->__bible->votd()->TO_JSON() };
}

sub process_request {
	my ($self) = @_;

	while (my $line = <STDIN>) {
		$line =~ s/[\r\n]+$//;

		my $json;
		eval {
			$json = $self->__json()->decode($line);
		};

		next unless (defined($json));

		my $result;
		my ($lookup, $search, $votd) = @{$json}{qw(lookup search votd)};

		if ($lookup) {
			$result = $self->__lookup($lookup);
		} elsif ($search) {
			$result = $self->__search($search);
		} elsif ($votd) {
			$result = $self->__votd();
		} else {
			printf("400\015\012Missing lookup or search stanza\015\012");
			last;
		}

		$result = $self->__json()->encode($result);
		print("200\015\012$result\015\012");
		last;
	}
}

Religion::Bible::Verses::Server->run(port => 22662, ipv => '*');
