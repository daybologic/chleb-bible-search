#!/usr/bin/perl
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

package Chleb::Server;
use strict;
use warnings;

=head1 NAME

Chleb::Server - Dancer2 server facility

=head1 DESCRIPTION

Dancer2 server for stand-alone HTTP server for Chleb Bible Search

=cut

use Chleb;
use Chleb::Bible::Search::Query;
use Chleb::DI::Container;
use Chleb::Exception;
use Chleb::Server::MediaType;
use Chleb::Type::Testament;
use Chleb::Utils;
use HTTP::Status qw(:constants);
use JSON;
use Readonly;
use Time::Duration;
use UUID::Tiny ':std';

Readonly our $SEARCH_RESULTS_LIMIT => $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT;
Readonly our $CONTENT_TYPE_DEFAULT => $Chleb::Server::MediaType::CONTENT_TYPE_HTML;
Readonly my $MAX_TEXT_LENGTH => 120;

=head1 METHODS

=over

=item C<new()>

Construct and return a new C<Chleb::Server>.

=cut

sub new {
	my ($class) = @_;
	my $object = bless({}, $class);

	$object->__title();

	return $object;
}

=item C<dic()>

Return the singleton L<Chleb::DI::Container>.

=cut

sub dic {
	return Chleb::DI::Container->instance;
}

=back

=head1 PRIVATE METHODS

=over

=item C<__title()>

This should only be called once, and at server startup time.
There is no return value.

=cut

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

=item C<__library()>

Server accessor for L<Chleb> itself; core library.
If the object has not yet been created, a new one is returned.

=cut

sub __library {
	my ($self) = @_;
	$self->{__library} ||= Chleb->new();
	return $self->{__library};
}

=item C<__makeJsonApi()>

Return a new empty skeleton for a C<JSON:API> response, with all mandatory parts, ie.
with empty C<data>, C<included> and C<links> keys.

=cut

sub __makeJsonApi {
	return (
		data => [ ],
		included => [ ],
		links => { },
	);
}

=item C<__lookup($params)>

Given the user-supplied C<$params> (C<HASH>), we attempt to fetch a verse,
which includes links to the previous and next verses.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

The following C<$params> are required:

=over

=item C<book>

Numerical ordinal, short name, or long name for the sought book

=cut

=item C<chapter>

Numerical chapter ordinal within C<book>

=cut

=item C<verse>

Numerical verse ordinal within C<chapter>

=cut

=back

=cut

sub __lookup {
	my ($self, $params) = @_;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	my @verse = $self->__library->fetch($params->{book}, $params->{chapter}, $params->{verse}, $params);

	my @json;
	for (my $verseI = 0; $verseI < scalar(@verse); $verseI++) {
		push(@json, __verseToJsonApi($verse[$verseI], $params));
		$json[$verseI]->{links}->{self} = '/' . join('/', 1, 'lookup', $verse[$verseI]->getPath()) . Chleb::Utils::queryParamsHelper($params);
	}

	for (my $jsonI = 1; $jsonI < scalar(@json); $jsonI++) {
		push(@{ $json[0]->{data} }, $json[$jsonI]->{data}->[0]);
	}

	foreach my $type (qw(next prev)) {
		next unless ($json[0]->{data}->[0]->{links}->{$type});

		my $pickVerse;
		if ($type eq 'prev') {
			if (my $prevVerse = $verse[0]->getPrev()) {
				$pickVerse = $prevVerse;
			} else {
				next;
			}
		} elsif ($type eq 'next') {
			if (my $nextVerse = $verse[0]->getNext()) {
				$pickVerse = $nextVerse;
			} else {
				next;
			}
		} else {
			$pickVerse = $verse[0]->id;
		}

		$json[0]->{links}->{$type} = '/' . join('/', 1, 'lookup', $pickVerse->getPath()) . Chleb::Utils::queryParamsHelper($params);
	}

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON) { # application/json
		return $json[0];
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __verseToHtml(\@json);
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported");
}

=item C<__random($params)>

Retrieve a verse at random, and return the C<JSON:API> structure from it.

Optionally, C<$params> (C<HASH>) may be supplied.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

=cut

sub __random {
	my ($self, $params) = @_;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	my $verse = $self->__library->random($params);
	my $json = __verseToJsonApi($verse, $params);

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON) { # application/json
		my $version = 1;
		$json->{links}->{self} = '/' . join('/', $version, 'random');
		return $json;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __verseToHtml([$json]);
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported");
}

=item C<__votd($params)>

Retrieve the verse of the day, and return the C<JSON:API> structure for it.

Optionally, C<$params> (C<HASH>) may be supplied.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

=cut

sub __votd {
	my ($self, $params) = @_;

	my $version = $params->{version} || 1;
	my $redirect = $params->{redirect} // 0;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	die Chleb::Exception->raise(HTTP_BAD_REQUEST, 'votd redirect is only supported on version 1')
	    if ($redirect && $version > 1);

	my $verse = $self->__library->votd($params);
	if (ref($verse) eq 'ARRAY') {
		my @json;

		for (my $verseI = 0; $verseI < scalar(@$verse); $verseI++) {
			push(@json, __verseToJsonApi($verse->[$verseI], $params));
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

		$json[0]->{links}->{self} =  '/' . join('/', $version, 'votd') . Chleb::Utils::queryParamsHelper($params);
		return $json[0] if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON); # application/json

		if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
			return __verseToHtml(\@json);
		} else {
			die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported");
		}
	}

	die Chleb::Exception->raise(
		HTTP_TEMPORARY_REDIRECT,
		'/1/lookup/' . join('/', lc($verse->book->shortName), $verse->chapter->ordinal, $verse->ordinal),
	) if ($redirect);

	my $json = __verseToJsonApi($verse, $params);
	$json->{links}->{self} =  '/' . join('/', $version, 'votd') . Chleb::Utils::queryParamsHelper($params);

	return $json;
}

=item C<__ping()>

Returns a simple C<JSON:API> structure which simply demonstrates that the server
is up and running.  The type of the C<data> element is a C<pong> response.  See
L<https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search>.

=cut

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

=item C<__version()>

Returns a simple C<JSON:API> structure which contains information about the server version.
The type of the C<data> element is a C<version> response.  See
L<https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search>.

This method may throw a L<Chleb::Exception> if the feature has been
disabled by the server administrator, or potentially, for any other reason.

=cut

sub __version {
	my ($self) = @_;
	my %hash = __makeJsonApi();

	my $version = $Chleb::VERSION;

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

=item C<__uptime()>

Returns a C<JSON:API> structure suitable for returning the server uptime.

=cut

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

=item C<__search($search)>

Perform a search with various parameters and return a C<JSON:API> structure,
fully-populated with all results.  TODO: In the future we must support pagination.

The following C<$params> (C<HASH>) are supported:

=over

=item C<limit>

A limit for the number of results, whose default is C<50>.

=item C<wholeword>

Whether the C<term> shall be considered a wholeword, or the default, a sub-string.

=item C<term>

The text the user is searching for (critereon).

=back

=cut

sub __search {
	my ($self, $search) = @_;

	my $limit = int($search->{limit});
	$limit ||= $SEARCH_RESULTS_LIMIT;

	my $wholeword = Chleb::Utils::boolean('wholeword', $search->{wholeword}, 0);

	my $contentType = Chleb::Server::MediaType::acceptToContentType($search->{accept}, $CONTENT_TYPE_DEFAULT);

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

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON) { # application/json
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __searchResultsToHtml(\%hash);
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported");
}

=item C<__info($params)>

Return information about the data we are serving as a C<JSON:API> structure.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

=cut

sub __info {
	my ($self, $params) = @_;

	my $startTiming = Time::HiRes::time();

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);

	my $info = $self->__library->info();
	my %hash = __makeJsonApi();

	my (@bookShortNames, @bookShortNamesRaw, @bookLongNames);
	my %uniqueBookNames = ( );
	foreach my $bible (@{ $info->bibles }) { # translations
		push(@{ $hash{included} }, {
			id => $bible->id,
			type => $bible->type,
			attributes => $bible->TO_JSON(),
		});
		foreach my $book (@{ $bible->books }) {
			next if (++$uniqueBookNames{ $book->shortName } > 1); # ensure book names are listed only once
			push(@bookShortNames, $book->shortName);
			push(@bookShortNamesRaw, $book->shortNameRaw);
			push(@bookLongNames, $book->longName);

			push(@{ $hash{included} }, {
				id => $book->id,
				type => $book->type,
				attributes => $book->TO_JSON(),
			});

			for (my $chapterOrdinal = 1; $chapterOrdinal <= $book->chapterCount; $chapterOrdinal++) {
				my $chapter = $book->getChapterByOrdinal($chapterOrdinal);
				push(@{ $hash{included} }, {
					id => $chapter->id,
					type => $chapter->type,
					attributes => $chapter->TO_JSON(),
				});
			}
		}
	}

	my @translations = map { $_->translation } @{ $info->bibles };

	push(@{ $hash{data} }, {
		type => $info->type,
		id => $info->id,
		attributes => {
			translation_count => scalar(@{ $info->bibles }),
			translations => \@translations,
			book_count => scalar(@bookShortNames),
			book_names_long => \@bookLongNames,
			book_names_short => \@bookShortNames,
			book_names_short_raw => \@bookShortNamesRaw,
		},
	});

	my $version = 1;
	$hash{links}->{self} = '/' . join('/', $version, 'info');

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));
	$info->msec($msec); # override library figure, incorporate everything

	push(@{ $hash{included} }, {
		type => 'stats',
		id => uuid_to_string(create_uuid()),
		attributes => {
			msec => int($info->msec),
		},
		links => { },
	});

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON) { # application/json
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return $self->__infoToHtml(\%hash);
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, 'Not acceptable here');
}

=item C<__getUptime()>

Return the number of seconds the server has been running.

=cut

sub __getUptime {
	my ($self) = @_;
	return time() - $self->__library->constructionTime;
}

=back

=head1 C<PRIVATE FUNCTIONS>

=over

=item C<__verseToJsonApi($verse, $params)>

Take the given C<$verse> (L<Chleb::Bible::Verse>) and optional C<$params> (C<HASH>)
and produce the user-facing C<JSON:API> response (C<HASH>).  Shared logic used by
multiple results-orientated server methods.

=cut

sub __verseToJsonApi {
	my ($verse, $params) = @_;
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

	my $dic = Chleb::DI::Container->instance;
	push(@{ $hash{included} }, {
		type => 'stats',
		id => uuid_to_string(create_uuid()),
		attributes => {
			msec => int($verse->msec),
		},
		links => { },
	});

	my %paramsLocal = ( );
	%paramsLocal = %$params if ($params);
	$paramsLocal{translations} = [ $verse->book->bible->translation ] if ($paramsLocal{translations});
	my $queryParams = Chleb::Utils::queryParamsHelper(\%paramsLocal);

	my %links = (
		# TODO: But should it be 'votd' unless redirect was requested?  Which isn't supported yet
		self => '/' . join('/', 1, 'lookup', $verse->getPath()) . $queryParams,
	);

	if (my $nextVerse = $verse->getNext()) {
		$links{next} = '/' . join('/', 1, 'lookup', $nextVerse->getPath()) . $queryParams;
	}

	if (my $prevVerse = $verse->getPrev()) {
		$links{prev} = '/' . join('/', 1, 'lookup', $prevVerse->getPath()) . $queryParams;
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

sub __verseToHtml {
	my ($json) = @_;

	my $output = '';
	my $includedCount = scalar(@{ $json->[0]->{included} });
	my %rawBookNameMap = ( );
	for (my $includedIndex = 0; $includedIndex < $includedCount; $includedIndex++) {
		my $includedItem = $json->[0]->{included}->[$includedIndex];
		my $type = $includedItem->{type};
		next if ($type ne 'book');

		$rawBookNameMap{ $includedItem->{attributes}->{short_name} }
		    = $includedItem->{attributes}->{short_name_raw};
	}

	my $verseCount = scalar(@{ $json->[0]->{data} });
	for (my $verseIndex = 0; $verseIndex < $verseCount; $verseIndex++) {
		my $attributes = $json->[0]->{data}->[$verseIndex]->{attributes};
		$output .= sprintf('<p>%s %d:%d %s</p>',
			$rawBookNameMap{ $attributes->{book} },
			$attributes->{chapter},
			$attributes->{ordinal},
			$attributes->{text},
		);

		if ($verseIndex < $verseCount-1) { # not last verse
			$output .= "\r\n";
		}
	}

	my $translation = $json->[0]->{data}->[0]->{attributes}->{translation};

	if ($verseCount == 1) {
		$output .= sprintf(" [%s]\r\n", $translation);
	} else {
		$output .= sprintf("\r\n\r\n\t(%s)\r\n", $translation);
	}

	return $output;
}

sub __searchResultsToHtml {
	my ($json) = @_;

	my $includedCount = scalar(@{ $json->{included} });
	my %rawBookNameMap = ( );
	for (my $includedIndex = 0; $includedIndex < $includedCount; $includedIndex++) {
		my $includedItem = $json->{included}->[$includedIndex];
		my $type = $includedItem->{type};
		next if ($type ne 'book');

		$rawBookNameMap{ $includedItem->{attributes}->{short_name} }
		    = $includedItem->{attributes}->{short_name_raw};
	}

	my $text = '';
	for (my $resultI = 0; $resultI < scalar(@{ $json->{data} }); $resultI++) {
		my $verse = $json->{data}->[$resultI];
		my $attributes = $verse->{attributes};
		$text .= sprintf("<p>[%s]<br />\r\n%s %d:%d %s\r\n\r\n</p>",
			$attributes->{title},
			$rawBookNameMap{ $attributes->{book} },
			$attributes->{chapter},
			$attributes->{ordinal},
			$attributes->{text},
		);
	}

	return $text;
}

sub __infoToHtml {
	my ($self, $json) = @_;

	my $printCell = sub {
		my ($datum, $int, $header) = @_;
		my $formatter = '%' . ($int ? 'd' : 's');
		my $tag = ($header ? 'h' : 'd');
		return sprintf("<t${tag}>${formatter}</t${tag}>\r\n", $datum);
	};

	my $limitVerseText = sub {
		my ($verse) = @_;

		if (length($verse->text) > $MAX_TEXT_LENGTH) {
			my $elipses = '...';
			return substr($verse->text, 0, $MAX_TEXT_LENGTH - length($elipses)) . $elipses;
		}

		return $verse->text; # simple
	};

	my %bookNameCache = ( );

	my $text = "<table>\r\n";

	$text .= "<tr>\r\n";
	$text .= $printCell->("Book", 0, 1);
	$text .= $printCell->("Ordinal", 0, 1);
	$text .= $printCell->("Chapters", 0, 1);
	$text .= $printCell->("Testament", 0, 1);
	$text .= $printCell->("Verses", 0, 1);
	$text .= $printCell->("Short name", 0, 1);
	$text .= $printCell->("Sample", 0, 1);
	$text .= "</tr>\r\n";

	for (my $includedI = 0; $includedI < scalar(@{ $json->{included} }); $includedI++) {
		my $included = $json->{included}->[$includedI];
		next if ($included->{type} ne 'book');

		my $attributes = $included->{attributes};

		$bookNameCache{ $attributes->{short_name} } = $attributes->{long_name};

		my $verse = $self->__library->random();
		my $verseText = $limitVerseText->($verse);

		$text .= "<tr>\r\n";
		$text .= $printCell->($attributes->{long_name});
		$text .= $printCell->($attributes->{ordinal}, 1);
		$text .= $printCell->($attributes->{chapter_count}, 1);
		$text .= $printCell->($attributes->{testament});
		$text .= $printCell->($attributes->{verse_count}, 1);
		$text .= $printCell->($attributes->{short_name});
		$text .= $printCell->(sprintf('%s [%d:%d]', $verseText, $verse->chapter->ordinal, $verse->ordinal));

		$text .= "</tr>\r\n";
	}

	$text .= "</table><br/>\r\n";

	$text .= "<table>\r\n";

	$text .= "<tr>\r\n";
	$text .= $printCell->("Book", 0, 1);
	$text .= $printCell->("Chapter", 0, 1);
	$text .= $printCell->("Verses", 0, 1);
	$text .= $printCell->("Sample", 0, 1);
	$text .= "</tr>\r\n";

	for (my $includedI = 0; $includedI < scalar(@{ $json->{included} }); $includedI++) {
		my $included = $json->{included}->[$includedI];
		next if ($included->{type} ne 'chapter');

		my $attributes = $included->{attributes};

		my $verse = $self->__library->random();
		my $verseText = $limitVerseText->($verse);

		$text .= "<tr>\r\n";
		$text .= $printCell->($bookNameCache{ $attributes->{book} });
		$text .= $printCell->($attributes->{ordinal}, 1);
		$text .= $printCell->($attributes->{verse_count}, 1);
		$text .= $printCell->(sprintf('%s [%d]', $verseText, $verse->ordinal));
		$text .= "</tr>\r\n";
	}

	$text .= "</table>\r\n";

	return $text;
}

=back

=cut

package main;
use strict;
use warnings;

use Dancer2 0.2;
use English qw(-no_match_vars);
use HTTP::Status qw(:is);
use POSIX qw(EXIT_SUCCESS);
use Scalar::Util qw(blessed);

my $server;

set serializer => 'JSON'; # or any other serializer
set content_type => $Chleb::Server::MediaType::CONTENT_TYPE_JSON;

sub handleException {
	my ($exception) = @_;

	if (blessed($exception) && $exception->isa('Chleb::Exception')) {
		$server->dic->logger->debug(sprintf('Returning HTTP status code %d', $exception->statusCode));
		if (is_redirect($exception->statusCode)) {
			return redirect $exception->location, $exception->statusCode;
		} else {
			send_error($exception->description, $exception->statusCode);
		}
	} else {
		$server->dic->logger->error("Internal Server Error: $exception");
		send_error($exception, 500);
	}

	return;
}

get '/1/random' => sub {
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(param('translations')));

	my $dancerRequest = request();
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));

	my $result;
	eval {
		$result = $server->__random({
			accept => $mediaType,
			translations => $translations,
			testament => param('testament'),
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		$server->dic->logger->trace('1/random returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/random returned as JSON');
	return $result;
};

get '/1/votd' => sub {
	my $parental = int(param('parental'));
	my $redirect = param('redirect');
	my $when = param('when');
	my $testament = param('testament');

	my $result;
	eval {
		$result = $server->__votd({
			parental    => $parental,
			redirect    => $redirect,
			when        => $when,
			testament   => $testament,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	return $result;
};

get '/2/votd' => sub {
	my $parental = int(param('parental'));
	my $redirect = param('redirect');
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(param('translations')));
	my $when = param('when');
	my $testament = param('testament');
	my $dancerRequest = request();

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));

	my $result;
	eval {
		$result = $server->__votd({
			accept       => $mediaType,
			version      => 2,
			when         => $when,
			parental     => $parental,
			translations => $translations,
			redirect     => $redirect,
			testament    => $testament,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		$server->dic->logger->trace('2/votd returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('2/votd returned as JSON');
	return $result;
};

get '/1/lookup/:book/:chapter/:verse' => sub {
	my $book = param('book');
	my $chapter = param('chapter');
	my $verse = param('verse');
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(param('translations')));

	my $dancerRequest = request();
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));

	my $result;
	eval {
		$result = $server->__lookup({
			accept       => $mediaType,
			book         => $book,
			chapter      => $chapter,
			translations => $translations,
			verse        => $verse,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		$server->dic->logger->trace('1/lookup returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/lookup returned as JSON');
	return $result;

};

get '/1/search' => sub {
	my $limit = param('limit');
	my $term = param('term');
	my $wholeword = param('wholeword');

	my $dancerRequest = request();
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));

	my $result;
	eval {
		$result = $server->__search({
			accept    => $mediaType,
			limit     => $limit,
			term      => $term,
			wholeword => $wholeword,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		$server->dic->logger->trace('1/search returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/search returned as JSON');
	return $result;
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

get '/1/info' => sub {
	my $result;

	my $dancerRequest = request();
	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));

	eval {
		$result = $server->__info({
			accept => $mediaType,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		$server->dic->logger->trace('1/info returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/info returned as JSON');
	return $result;
};

unless (caller()) {
	$server = Chleb::Server->new();
	$0 = 'chleb-bible-search [server]';
	dance;

	exit(EXIT_SUCCESS);
}

1;
