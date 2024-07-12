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

use base qw(Net::Server::PreForkSimple);

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

	my %hash = (
		result => {
			count  => $results->count,
			verses => [ ],
		},
	);

	for (my $i = 0; $i < $results->count; $i++) {
		push(@{ $hash{result}->{verses} }, $results->verses->[$i]->TO_JSON());
	}

	return \%hash;
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
		my ($lookup, $search) = @{$json}{qw(lookup search)};

		if ($lookup) {
			$result = $self->__lookup($lookup);
		} elsif ($search) {
			$result = $self->__search($search);
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
