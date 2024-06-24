#!/usr/bin/perl -w -T
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
		push(@{ $hash{result}->{verses} }, $results->verses->[$i]);
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
