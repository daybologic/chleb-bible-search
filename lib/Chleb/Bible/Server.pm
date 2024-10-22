#!/usr/bin/perl
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

package Chleb::Bible::Server;
use strict;
use warnings;
use Chleb;
use Chleb::Bible::DI::Container;
use JSON;
use Time::Duration;
use UUID::Tiny ':std';

sub new {
	my ($class) = @_;
	my $object = bless({}, $class);

	$object->__title();

	return $object;
}

sub dic {
	return Chleb::Bible::DI::Container->instance;
}

sub __title {
	my ($self) = @_;

	$self->dic->logger->info("Started Chleb Bible Server: \"Man shall not live by bread alone, but by every word that proceedeth out of the mouth of God.\" (Matthew 4:4)");

	$self->dic->logger->info(sprintf(
		"Server %s administrator: %s <%s>",
		$self->dic->config->get('server', 'domain', 'localhost'),
		$self->dic->config->get('server', 'admin_name', 'Unknown'),
		$self->dic->config->get('server', 'admin_email', 'example@example.org'),
	));

	return;
}

sub __json {
	my ($self) = @_;
	$self->{__json} ||= JSON->new();
	return $self->{__json};
}

sub __library {
	my ($self) = @_;
	$self->{__library} ||= Chleb->new();
	return $self->{__library};
}

sub __makeJsonApi {
	return (
		data => [ ],
		included => [ ],
		links => { },
	);
}

sub __verseToJsonApi {
	my ($verse) = @_;
	my %hash = __makeJsonApi();

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

	my $dic = Chleb::Bible::DI::Container->instance;
	push(@{ $hash{included} }, {
		type => 'stats',
		id => uuid_to_string(create_uuid()),
		attributes => {
			msec => int($verse->msec),
		},
		links => { },
	});

	my %links = (
		# TODO: But should it be 'votd' unless redirect was requested?  Which isn't supported yet
		self => '/' . join('/', 1, 'lookup', $verse->id),
	);

	if (my $nextVerse = $verse->getNext()) {
		$links{next} = '/' . join('/', 1, 'lookup', $nextVerse->id);
	}

	if (my $prevVerse = $verse->getPrev()) {
		$links{prev} = '/' . join('/', 1, 'lookup', $prevVerse->id);
	}

	push(@{ $hash{data} }, {
		type => $verse->type,
		id => $verse->id,
		attributes => $verse->TO_JSON(),
		links => \%links,
		relationships => {
			chapter => {
				links => {
					# TODO: It should be possible to look up an entire chapter
					#self => '/' . join('/', 1, 'lookup', $verse->chapter->id),
				},
				data => {
					type => $verse->chapter->type,
					id => $verse->chapter->id,
				},
			},
			book => {
				links => {
					# TODO: It should be possible to look up an entire book
					#self => '/' . join('/', 1, 'lookup', $verse->book->id),
				},
				data => {
					type => $verse->book->type,
					id => $verse->book->id,
				},
			},
		},
	});

	return \%hash;
}

sub __lookup {
	my ($self, $params) = @_;
	my $verse = $self->__library->fetch($params->{book}, $params->{chapter}, $params->{verse});

	my $json = __verseToJsonApi($verse);

	$json->{links}->{self} = '/' . join('/', 1, 'lookup', $verse->id);
	foreach my $type (qw(next prev)) {
		next unless ($json->{data}->[0]->{links}->{$type});
		$json->{links}->{$type} = $json->{data}->[0]->{links}->{$type};
	}

	return $json;
}

sub __random {
	my ($self) = @_;
	my $verse = $self->__library->random();

	my $json = __verseToJsonApi($verse);
	my $version = 1;
	$json->{links}->{self} =  '/' . join('/', $version, 'random');

	return $json;
}

sub __votd {
	my ($self, $params) = @_;

	my $version = $params->{version} || 1;
	my $verse = $self->__library->votd($params);
	if (ref($verse) eq 'ARRAY') {
		my @json;

		for (my $verseI = 0; $verseI < scalar(@$verse); $verseI++) {
			push(@json, __verseToJsonApi($verse->[$verseI]));
		}

		my $secondary_total_msec = 0;
		for (my $verseI = 1; $verseI < scalar(@$verse); $verseI++) {
			push(@{ $json[0]->{data} },  $json[$verseI]->{data}->[0]);
			for (my $includedI = 0; $includedI < scalar(@{ $json[$verseI]->{included} }); $includedI++) {
				my $inclusion = $json[$verseI]->{included}->[$includedI];
				next if ($inclusion->{type} ne 'stats');
				$secondary_total_msec += $inclusion->{attributes}->{msec};
			}
		}

		for (my $includedI = 0; $includedI < scalar(@{ $json[0]->{included} }); $includedI++) {
			next if ($json[0]->{included}->[$includedI]->{type} ne 'stats');
			$json[0]->{included}->[$includedI]->{attributes}->{msec} += $secondary_total_msec;
		}

		$json[0]->{links}->{self} =  '/' . join('/', $version, 'votd');
		return $json[0];
	}

	my $json = __verseToJsonApi($verse);
	$json->{links}->{self} =  '/' . join('/', $version, 'votd');

	return $json;
}

sub __ping {
	my ($self) = @_;
	my %hash = __makeJsonApi();

	push(@{ $hash{data} }, {
		type => 'pong',
		id => uuid_to_string(create_uuid()),
		attributes => {
			message => 'Ahoy-hoy!',
		},
	});

	return \%hash;
}

sub __version {
	my ($self) = @_;
	my %hash = __makeJsonApi();

	my $version = $Chleb::Bible::VERSION;

	return 403 unless ($self->dic->config->get('features', 'version', 'true', 1));

	push(@{ $hash{data} }, {
		type => 'version',
		id => uuid_to_string(create_uuid()),
		attributes => {
			version => $version,
			admin_email => $self->dic->config->get('server', 'admin_email', 'example@example.org'),
			admin_name => $self->dic->config->get('server', 'admin_name', 'Unknown'),
			server_host => $self->dic->config->get('server', 'domain', 'localhost'),
		},
	});

	return \%hash;
}

sub __uptime {
	my ($self) = @_;
	my %hash = __makeJsonApi();

	my $uptime = $self->__getUptime();

	push(@{ $hash{data} }, {
		type => 'uptime',
		id => uuid_to_string(create_uuid()),
		attributes => {
			uptime => $uptime,
			text => duration_exact($uptime),
		},
	});

	return \%hash;
}

sub __getUptime {
	my ($self) = @_;
	return time() - $self->__library->constructionTime;
}

sub __search {
	my ($self, $search) = @_;

	my $limit = int($search->{limit});
	$limit ||= 5;

	my $wholeword = int($search->{wholeword});

	my $query = $self->__library->newSearchQuery($search->{term})->setLimit($limit)->setWholeword($wholeword);
	my $results = $query->run();

	my %hash = __makeJsonApi();

	for (my $i = 0; $i < $results->count; $i++) {
		my $verse = $results->verses->[$i];

		my %attributes = ( %{ $verse->TO_JSON() } );
		$attributes{title} = sprintf("Result %d/%d from Chleb Bible Search '%s'", $i+1, $results->count, $search->{term});

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

	push(@{ $hash{included} },
		{
			type => 'results_summary',
			id => uuid_to_string(create_uuid()),
			attributes => {
				count => $results->count,
			},
			links => { },
		},
		{
			type => 'stats',
			id => uuid_to_string(create_uuid()),
			attributes => {
				msec => int($results->msec),
			},
			links => { },
		},
	);

	$hash{links}->{self} = '/1/search?term=' . $search->{term} . '&wholeword=' . $wholeword .'&limit=' . $limit;

	return \%hash;
}

package main;
use strict;
use warnings;

use Dancer2;
use POSIX qw(EXIT_SUCCESS);

my $server;

set serializer => 'JSON'; # or any other serializer

get '/1/random' => sub {
	return $server->__random();
};

get '/1/votd' => sub {
	my $when = param('when');
	my $parental = int(param('parental'));
	return $server->__votd({ when => $when, parental => $parental });
};

get '/2/votd' => sub {
	my $when = param('when');
	my $parental = int(param('parental'));
	return $server->__votd({ version => 2, when => $when, parental => $parental });
};

get '/1/lookup/:book/:chapter/:verse' => sub {
	my $book = param('book');
	my $chapter = param('chapter');
	my $verse = param('verse');

	return $server->__lookup({ book => $book, chapter => $chapter, verse => $verse });
};

get '/1/search' => sub {
	my $limit = param('limit');
	my $term = param('term');
	my $wholeword = param('wholeword');
	return $server->__search({ limit => $limit, term => $term, wholeword => $wholeword });
};

get '/1/ping' => sub {
	return $server->__ping();
};

get '/1/version' => sub {
	my $version = $server->__version();
	if (ref($version) eq 'HASH') {
		return $version;
	} elsif ($version == 403) {
		send_error('Disabled by server administrator', $version);
	} else {
		send_error('Unknown error', 500);
	}
};

get '/1/uptime' => sub {
	return $server->__uptime();
};

unless (caller()) {
	$server = Chleb::Bible::Server->new();
	$0 = 'chleb-bible-search [server]';
	dance;

	exit(EXIT_SUCCESS);
}

1;
