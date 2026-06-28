#!/usr/bin/perl
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

package Chleb::Server::Moose;
use strict;
use warnings;
use Moose;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";

extends 'Chleb::Bible::Base';

=head1 NAME

Chleb::Server::Moose

=head1 DESCRIPTION

Moose portion of HTTP server facility used by L<Chleb::Server::Dancer2>

=cut

use Chleb;
use Chleb::Bible::Search::Query;
use Chleb::DI::Container;
use Chleb::Exception;
use Chleb::Generated::Info;
use Chleb::Server::MediaType;
use Chleb::Type::Testament;
use Chleb::Utils;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants);
use IO::File;
use JSON;
use Log::Log4perl::MDC;
use Readonly;
use Sys::Hostname;
use Time::Duration;
use URI::Escape;
use UUID::Tiny ':std';

Readonly our $SEARCH_RESULTS_LIMIT => $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT;
Readonly our $CONTENT_TYPE_DEFAULT => $Chleb::Server::MediaType::CONTENT_TYPE_HTML;
Readonly our $SEARCH_RESULTS_MAX_PAGE_SIZE => 2_000;

Readonly my $FUNCTION_RANDOM => 1;
Readonly my $FUNCTION_VOTD => 2;
Readonly my $FUNCTION_LOOKUP => 3;

Readonly my $UPTIME_FILE_PATH => '/var/run/chleb-bible-search/startup.txt';
Readonly my $NS_VERSION => 'c0207fa6-6560-11f0-acec-43cf13408627';

=head1 METHODS

=over

=item C<BUILD()>

Book called after construction, by Moose.

=cut

sub BUILD {
	my ($self) = @_;

	$self->__removeUptime();
	$self->__getUptime(); # set startup time as soon as possible
	$self->title();

	return;
}

=item C<title()>

This should only be called once, and at server startup time.
There is no return value.

=cut

sub title {
	my ($self) = @_;

	$self->dic->logger->info(sprintf(
		'Started Chleb Bible Search %s (%s) on %s, built by %s@%s (%s/%s) with Perl %s at %s',
		$Chleb::VERSION,
		$Chleb::Generated::Info::BUILD_CHANGESET,
		hostname(),
		$Chleb::Generated::Info::BUILD_USER,
		$Chleb::Generated::Info::BUILD_HOST,
		$Chleb::Generated::Info::BUILD_OS,
		$Chleb::Generated::Info::BUILD_ARCH,
		$Chleb::Generated::Info::BUILD_PERL_VERSION,
		$Chleb::Generated::Info::BUILD_TIME,
	));

	$self->dic->logger->info(sprintf(
		"Server %s administrator: %s <%s>",
		$self->dic->config->get('server', 'domain', 'localhost'),
		$self->dic->config->get('server', 'admin_name', 'Unknown'),
		$self->dic->config->get('server', 'admin_email', 'example@example.org'),
	));

	return;
}

=back

=head1 PRIVATE METHODS

=over

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

Given the user-supplied C<$params> (C<HASH>), we attempt to fetch a verse, or series of verses
which include links to the previous and next verses.

returns a an (C<ARRAY>) of C<JSON:API> C<HASH> es or throws a L<Chleb::Exception>.

The following C<$params> are required:

=over

=item C<book>

Numerical ordinal, short name, or long name for the sought book

=cut

=item C<chapter>

C<Mandatory>; Numerical chapter ordinal within C<book>

=cut

=item C<verse>

Numerical verse ordinal within C<chapter>

Optional; if not specified, we return the whole chapter.

=cut

=back

=cut

sub __isJsonContentType {
	my ($contentType) = @_;

	return (
		$contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON
		|| $contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API
	);
}

sub __lookup {
	my ($self, $params) = @_;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	my @verse = $self->__library->fetch($params->{book}, $params->{chapter}, $params->{verse}, $params);

	my @json;
	for (my $verseI = 0; $verseI < scalar(@verse); $verseI++) {
		push(@json, __verseToJsonApi($verse[$verseI], $params));
		$json[$verseI]->{links}->{self} = '/' . join('/', 1, 'lookup', $verse[$verseI]->getPath())
		    . Chleb::Utils::queryParamsHelper($params);
	}

	for (my $jsonI = 1; $jsonI < scalar(@json); $jsonI++) {
		push(@{ $json[0]->{data} }, $json[$jsonI]->{data}->[0]);
	}

	foreach my $type (qw(next prev first last)) {
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
		} elsif ($type eq 'first') {
			$pickVerse = $verse[0]->chapter->getVerseByOrdinal(1);
		} elsif ($type eq 'last') {
			my $chapterVerseCount = $verse[0]->chapter->verseCount;
			$pickVerse = $verse[0]->chapter->getVerseByOrdinal($chapterVerseCount);
		} else {
			$pickVerse = $verse[0]->id;
		}

		$json[0]->{links}->{$type} = '/' . join('/', 1, 'lookup', $pickVerse->getPath())
		    . Chleb::Utils::queryParamsHelper($params);
	}

	if (__isJsonContentType($contentType)) {
		if ($params->{form}) {
			die Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			);
		}

		return \@json;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return $self->__verseToHtml(\@verse, \@json, $FUNCTION_LOOKUP);
	}

	die Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	);
}

=item C<__random($params)>

Retrieve a verse at random, and return the C<JSON:API> structure from it.

Optionally, C<$params> (C<HASH>) may be supplied.

returns a C<JSON:API> (C<HASH>) or throw a L<Chleb::Exception>.

=cut

sub __random {
	my ($self, $params) = @_;

	my $version = __versionFilter($params->{version}, 1, 2);
	my $redirect = $params->{redirect} // 0;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($params->{accept}, $CONTENT_TYPE_DEFAULT);

	die Chleb::Exception->raise(HTTP_BAD_REQUEST, 'random redirect is only supported on version 1')
	    if ($redirect && $version > 1);

	my $verse = $self->__library->random($params);
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

		$json[0]->{links}->{self} =  '/' . join('/', $version, 'random') . Chleb::Utils::queryParamsHelper($params);
		return $json[0] if (__isJsonContentType($contentType));

		if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
			return $self->__verseToHtml($verse, \@json, $FUNCTION_RANDOM);
		} else {
			die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported");
		}
	}

	die Chleb::Exception->raise(
		HTTP_TEMPORARY_REDIRECT,
		'/1/lookup/' . join('/', lc($verse->book->shortName), $verse->chapter->ordinal, $verse->ordinal),
	) if ($redirect);

	my $json = __verseToJsonApi($verse, $params);
	$json->{links}->{self} =  '/' . join('/', $version, 'random') . Chleb::Utils::queryParamsHelper($params);

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return $self->__verseToHtml($verse, [$json], $FUNCTION_RANDOM);
	}

	if (__isJsonContentType($contentType)) {
		if ($params->{form}) {
			die Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			);
		}

		return $json;
	}

	die Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML, $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	);

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

		if (__isJsonContentType($contentType)) {
			if ($params->{form}) {
				die Chleb::Exception->raise(
					HTTP_BAD_REQUEST,
					"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
				);
			}

			return $json[0];
		}

		if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
			return $self->__verseToHtml($verse, \@json, $FUNCTION_VOTD);
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

	if ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return $self->__verseToHtml($verse, [$json], $FUNCTION_VOTD);
	}

	if (__isJsonContentType($contentType)) {
		if ($params->{form}) {
			die Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			);
		}

		return $json;
	}

	die Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML, $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	);
}

=item C<__ping()>

Returns a simple C<JSON:API> structure which simply demonstrates that the server
is up and running.  The type of the C<data> element is a C<pong> response.  See
L<https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search>.

=cut

sub __ping {
	my ($self, $params) = @_;
	$params ||= {};
	my %hash = __makeJsonApi();

	my %attributes = (
		message => 'Ahoy-hoy!',
	);

	push(@{ $hash{data} }, {
		type => 'pong',
		id => uuid_to_string(create_uuid()),
		attributes => \%attributes,
	});

	my $contentType = Chleb::Server::MediaType::acceptToContentType(
		$params->{accept},
		$Chleb::Server::MediaType::CONTENT_TYPE_JSON,
	);

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) {
		return __pingToHtml(\%attributes);
	}

	die Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	);
}

sub __pingToHtml {
	my ($attributes) = @_;

	my $html = __linkToHome();
	$html .= "<table class=\"info-table\">\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Message</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{message});
	$html .= "</tr>\r\n";
	$html .= "</table>\r\n";

	return $html;
}

=item C<__version()>

Returns a simple C<JSON:API> structure which contains information about the server version.
The type of the C<data> element is a C<version> response.  See
L<https://app.swaggerhub.com/apis/M6KVM/chleb-bible-search>.

This method may throw a L<Chleb::Exception> if the feature has been
disabled by the server administrator, or potentially, for any other reason.

=cut

sub __version {
	my ($self, $params) = @_;
	$params ||= {};
	my %hash = __makeJsonApi();

	my $version = $Chleb::VERSION;

	return 403 unless ($self->dic->config->get('features', 'version', 'true', 1));

	my %attributes = (
		version => $version,
		admin_email => $self->dic->config->get('server', 'admin_email', 'example@example.org'),
		admin_name => $self->dic->config->get('server', 'admin_name', 'Unknown'),
		build_arch => $Chleb::Generated::Info::BUILD_ARCH,
		build_host => $Chleb::Generated::Info::BUILD_HOST,
		build_os => $Chleb::Generated::Info::BUILD_OS,
		build_time => $Chleb::Generated::Info::BUILD_TIME,
		build_user => $Chleb::Generated::Info::BUILD_USER,
		changeset => $Chleb::Generated::Info::BUILD_CHANGESET,
		perl_version => $Chleb::Generated::Info::BUILD_PERL_VERSION,
		server_host => $self->dic->config->get('server', 'domain', 'localhost'),
	);

	push(@{ $hash{data} }, {
		type => 'version',
		id => uuid_to_string(create_uuid(UUID_SHA1, $NS_VERSION, join('/', sort(values(%attributes))))),
		attributes => \%attributes,
	});

	my $contentType = Chleb::Server::MediaType::acceptToContentType(
		$params->{accept},
		$Chleb::Server::MediaType::CONTENT_TYPE_JSON,
	);

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __versionToHtml(\%attributes);
	}

	die Chleb::Exception->raise(
		HTTP_NOT_ACCEPTABLE,
		"Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML and $Chleb::Server::MediaType::CONTENT_TYPE_JSON are supported",
	);
}

sub __versionToHtml {
	my ($attributes) = @_;

	my $html = __linkToHome();
	$html .= "<table class=\"info-table\">\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Version</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{version});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Git changeset</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{changeset});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build time</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_time});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build host</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_host});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build OS</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_os});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build architecture</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_arch});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Build user</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{build_user});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Perl version</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{perl_version});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Administrator</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{admin_name});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Admin email</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{admin_email});
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Server host</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $attributes->{server_host});
	$html .= "</tr>\r\n";
	$html .= "</table>\r\n";

	return $html;
}

=item C<__uptime()>

Returns a C<JSON:API> structure suitable for returning the server uptime.

=cut

sub __uptime {
	my ($self, $params) = @_;
	$params ||= {};
	my %hash = __makeJsonApi();

	my $uptime = $self->__getUptime();
	my $uptimeText = duration_exact($uptime);

	push(@{ $hash{data} }, {
		type => 'uptime',
		id => uuid_to_string(create_uuid()),
		attributes => {
			uptime => $uptime,
			text => $uptimeText,
		},
	});

	my $contentType = Chleb::Server::MediaType::acceptToContentType(
		$params->{accept},
		$Chleb::Server::MediaType::CONTENT_TYPE_JSON,
	);

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __uptimeToHtml($uptime, $uptimeText);
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported");
}

sub __uptimeToHtml {
	my ($uptime, $uptimeText) = @_;

	my $html = __linkToHome();
	$html .= "<table class=\"info-table\">\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Uptime</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $uptimeText);
	$html .= "</tr>\r\n";
	$html .= "<tr>\r\n";
	$html .= "<th>Seconds</th>\r\n";
	$html .= sprintf("<td>%s</td>\r\n", $uptime);
	$html .= "</tr>\r\n";
	$html .= "</table>\r\n";

	return $html;
}

=item C<__search($search)>

Perform a search with various parameters and return a C<JSON:API> structure,
fully-populated with the requested page of results.

The following C<$params> (C<HASH>) are supported:

=over

=item C<limit>

A cap for the total number of search results to consider.

=item C<page>

The requested page number, whose default is C<1>.

=item C<per_page>

A limit for the number of results per page, whose default is C<50>.

=item C<wholeword>

Whether the C<term> shall be considered a wholeword, or the default, a sub-string.

=item C<term>

The text the user is searching for (critereon).

=back

=cut

sub __search {
	my ($self, $search) = @_;

	my $limit = __searchLimit($search->{limit});
	my $page = __searchPage($search->{page});
	my $perPage = __searchPerPage($search->{per_page});
	my $offset = ($page - 1) * $perPage;

	my $wholeword = Chleb::Utils::boolean('wholeword', $search->{wholeword}, 0);

	my $contentType = Chleb::Server::MediaType::acceptToContentType($search->{accept}, $CONTENT_TYPE_DEFAULT);

	my $query = $self->__library->newSearchQuery($search->{term})->setLimit($limit)->setWholeword($wholeword);
	my $results = $query->run();
	my $totalCount = $results->count;
	my @pageVerses = @{ $results->verses };
	splice(@pageVerses, 0, $offset);
	splice(@pageVerses, $perPage);
	my $pageCount = scalar(@pageVerses);
	my $totalPages = $totalCount > 0 ? int(($totalCount + $perPage - 1) / $perPage) : 1;

	my %hash = __makeJsonApi();

	for (my $i = 0; $i < $pageCount; $i++) {
		my $verse = $pageVerses[$i];

		my %attributes = ( %{ $verse->TO_JSON() } );
		$attributes{title} = sprintf("Result %d/%d from Chleb Bible Search '%s'", $offset + $i + 1, $totalCount, $query->text);

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
				count       => $pageCount,
				page        => $page,
				per_page    => $perPage,
				total_count => $totalCount,
				total_pages => $totalPages,
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

	my %paginationParams = (
		form        => $search->{form},
		limit       => $limit,
		page        => $page,
		per_page    => $perPage,
		term        => $query->text,
		total_pages => $totalPages,
		wholeword   => $wholeword,
	);

	my $paginationLinks = __searchPaginationLinks(\%paginationParams);
	foreach my $name (keys(%$paginationLinks)) {
		$hash{links}->{$name} = $paginationLinks->{$name};
	}

	if (__isJsonContentType($contentType)) {
		if ($search->{form}) {
			die Chleb::Exception->raise(
				HTTP_BAD_REQUEST,
				"form mode is only supported in $Chleb::Server::MediaType::CONTENT_TYPE_HTML mode",
			);
		}

		return (\%hash, \%hash);
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		my $html = __searchResultsToHtml(\%hash, { includeHome => !$search->{form} });
		return ($html, \%hash);
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, "Only $Chleb::Server::MediaType::CONTENT_TYPE_HTML is supported");
}

=item C<__searchLimit($limit)>

Normalises the total search result cap.

C<$limit> is a user supplied value from the C<limit> query parameter.  Positive
integer values are returned as integers.  Missing, non-numeric, and values below
C<1> fall back to the default search result limit.

=cut

sub __searchLimit {
	my ($limit) = @_;

	return $SEARCH_RESULTS_LIMIT unless (defined($limit) && $limit =~ m/\A[0-9]+\z/);
	$limit = int($limit);
	return $SEARCH_RESULTS_LIMIT if ($limit < 1);
	return $limit;
}

=item C<__searchPage($page)>

Normalises a requested search result page number.

C<$page> is a user supplied value from the C<page> query parameter.  Positive
integer values are returned as integers.  Missing, non-numeric, and values below
C<1> resolve to the first page.

=cut

sub __searchPage {
	my ($page) = @_;

	return 1 unless (defined($page) && $page =~ m/\A-?[0-9]+\z/);
	$page = int($page);
	return $page < 1 ? 1 : $page;
}

=item C<__searchPerPage($perPage)>

Normalises the search result page size.

C<$perPage> is a user supplied value from the C<per_page> query parameter.
Positive integer values are returned as integers, capped at
C<$SEARCH_RESULTS_MAX_PAGE_SIZE>.  Missing, non-numeric, and values below C<1>
fall back to the default search result limit.

=cut

sub __searchPerPage {
	my ($perPage) = @_;

	return $SEARCH_RESULTS_LIMIT unless (defined($perPage) && $perPage =~ m/\A[0-9]+\z/);
	$perPage = int($perPage);
	return $SEARCH_RESULTS_LIMIT if ($perPage < 1);
	return $SEARCH_RESULTS_MAX_PAGE_SIZE if ($perPage > $SEARCH_RESULTS_MAX_PAGE_SIZE);
	return $perPage;
}

=item C<__searchPaginationLinks($params)>

Builds stateless pagination links for a search result page.

C<$params> is a C<HASH> reference containing the current search term, wholeword
flag, total limit, page size, current page, total pages, and optional form mode.
The returned C<HASH> reference always contains C<first>, C<last>, and C<self>
links.  C<prev> and C<next> are included only when the current page has a
previous or next page.

=cut

sub __searchPaginationLinks {
	my ($params) = @_;

	my $page = $params->{page};
	my $totalPages = $params->{total_pages};
	my %links = (
		first => __searchPageLink($params, 1),
		last  => __searchPageLink($params, $totalPages),
		self  => __searchPageLink($params, $page),
	);

	$links{prev} = __searchPageLink($params, $page - 1) if ($page > 1);
	$links{next} = __searchPageLink($params, $page + 1) if ($page < $totalPages);

	return \%links;
}

=item C<__searchPageLink($params, $page)>

Builds a single search page URL.

C<$params> is the same C<HASH> reference passed to
L</__searchPaginationLinks($params)>.  C<$page> is the page number to place in
the generated URL.  The URL preserves the search term, wholeword flag, total
limit, page size, and form mode so each page request remains stateless.

=cut

sub __searchPageLink {
	my ($params, $page) = @_;

	my @parts = (
		'term=' . uri_escape($params->{term}),
		'wholeword=' . uri_escape($params->{wholeword}),
		'limit=' . uri_escape($params->{limit}),
		'page=' . uri_escape($page),
		'per_page=' . uri_escape($params->{per_page}),
	);
	push(@parts, 'form=true') if ($params->{form});

	return '/1/search?' . join('&', @parts);
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

	if (__isJsonContentType($contentType)) {
		return \%hash;
	} elsif ($contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_HTML) { # text/html
		return __infoToHtml(\%hash);
	}

	die Chleb::Exception->raise(HTTP_NOT_ACCEPTABLE, 'Not acceptable here');
}

=item C<__getUptime()>

Return the number of seconds the server has been running.

=cut

sub __getUptime {
	my ($self) = @_;
	my $uptimeFilePath = $self->__uptimeFilePath();
	my $startTime = time();
	if (my $fh = IO::File->new($uptimeFilePath, 'r')) {
		$startTime = <$fh>;
		chomp($startTime);
		$startTime = int($startTime); # don't trust the file too much
	} elsif ($fh = IO::File->new($uptimeFilePath, 'w')) {
		print($fh "$startTime\n");
	}

	return time() - $startTime;
}

sub __uptimeFilePath {
	my ($self) = @_;
	return $self->dic->config->get('server', 'uptime_file', $UPTIME_FILE_PATH);
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

	$links{first} = '/' . join('/', 1, 'lookup', $verse->chapter->getVerseByOrdinal(1)->getPath())
	    . Chleb::Utils::queryParamsHelper($params);
	$links{last} = '/' . join('/', 1, 'lookup', $verse->chapter->getVerseByOrdinal($verse->chapter->verseCount)->getPath())
	    . Chleb::Utils::queryParamsHelper($params);

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
	my ($self, $verse, $json, $function) = @_;

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

	my $random;
	{
		my $pattern = "<a class=\"vn-link vn-chapter\" href=\"%s\">%s</a>";
		if ($function == $FUNCTION_RANDOM) {
			#$random = sprintf($pattern, $json->[0]->{links}->{self}, 'another'); # FIXME: because testament is '' which is invalid
			$random = sprintf($pattern, '/2/random', 'another'); # FIXME: use self link, once it works
		} else {
			$random = sprintf($pattern, '/2/random', 'random');
		}
	}

	my $verseCount = scalar(@{ $json->[0]->{data} });
	my $reference;
	for (my $verseIndex = 0; $verseIndex < $verseCount; $verseIndex++) {
		my $attributes = $json->[0]->{data}->[$verseIndex]->{attributes};
		my $bookName = $attributes->{book};
		my $bookNameRaw = $rawBookNameMap{$bookName};
		my $chapter = $attributes->{chapter};
		my $verseOrdinal = $attributes->{ordinal};

		if ($verseIndex == 0) {
			$reference = sprintf('%s %d:%d', $bookNameRaw, $chapter, $verseOrdinal);
		} else {
			$output .= '<sup class="versenum">';
			$output .= sprintf('<a href="/1/lookup/%s/%d/%d">', $bookName, $chapter, $verseOrdinal);
			$output .= "${verseOrdinal} </a></sup>";
		}

		$output .= $attributes->{text};

		if ($verseIndex < $verseCount-1) { # not last verse
			my $thisVerse = (ref($verse) eq 'ARRAY') ? $verse->[$verseIndex] : $verse;
			$output .= '<br /><br />' unless ($thisVerse->continues);
			$output .= "\r\n";
		}
	}

	my $firstVerse = $json->[0]->{data}->[0];
	my ($translation, $emotion) = @{ $firstVerse->{attributes} }{qw(translation emotion)};

	my (@allTones, %toneSeen);
	foreach my $verseData (@{ $json->[0]->{data} }) {
		my $tones = $verseData->{attributes}->{tones};
		foreach my $tone (@$tones) {
			next if ($tone eq $emotion || $toneSeen{$tone});
			push(@allTones, $tone);
			$toneSeen{$tone}++;
		}
	}

	my $sentiments = '';
	foreach my $sentiment ($emotion, @allTones) {
		my $colorIndex = Chleb::Utils::colorIndexFromWord($sentiment);
		$sentiments .= "<span class=\"tag tag-color-${colorIndex}\">$sentiment</span> ";
	}

	my $firstVerseObject = $verse;
	$firstVerseObject = $firstVerseObject->[0] if (ref($firstVerseObject) eq 'ARRAY');

	my $prevBookLink = '';
	if (my $prevBook = $firstVerseObject->book->getPrev()) {
		$prevBookLink = '<a class="vn-link vn-book" href="/1/lookup/' . $prevBook->getPath() . '/1">prev book</a>';
	}

	my $prevChapterLink = '';
	if (my $prevChapter = $firstVerseObject->chapter->getPrev()) {
		$prevChapterLink = '<a class="vn-link vn-chapter" href="/1/lookup/' . $prevChapter->getPath() . '">prev chapter</a>';
	}

	my $nextBookLink = '';
	if (my $nextBook = $firstVerseObject->book->getNext()) {
		$nextBookLink = '<a class="vn-link vn-book" href="/1/lookup/' . $nextBook->getPath() . '/1">next book</a>';
	}

	my $nextChapterLink = '';
	if (my $nextChapter = $firstVerseObject->chapter->getNext()) {
		$nextChapterLink = '<a class="vn-link vn-chapter" href="/1/lookup/' . $nextChapter->getPath() . '">next chapter</a>';
	}

	my $lastChapterLink = '';
	my $chapterCount = $firstVerseObject->book->chapterCount;
	my @chapters = ( );
	for (my $chapterOrdinal = 1; $chapterOrdinal <= $firstVerseObject->book->chapterCount; $chapterOrdinal++) {
		if (my $chapter = $firstVerseObject->book->getChapterByOrdinal($chapterOrdinal, { nonFatal => 1 })) {
			push(@chapters, $chapter);
		} else {
			$self->dic->logger->error("Can't get chapter $chapterCount from book " . $firstVerseObject->book->shortName
			    . 'even though it logically exists, so LAST_CHAPTER_URL will be broken');
		}
	}

	if ($firstVerseObject->chapter->ordinal < $chapterCount) {
		my $lastChapter = $chapters[-1];
		$lastChapterLink = '<a class="vn-link vn-chapter" href="/1/lookup/' . $lastChapter->getPath() . '">last chapter</a>';
	}

	my $bookLinkFormat = '<a class="vn-link vn-book" href="/1/lookup/' . $firstVerseObject->book->getPath() . '/1">%s</a>';

	my $browsingLeft;
	{
		my $chapterLinks = '';
		foreach my $chapter (@chapters) {
			my $classCurrent = '';
			if ($chapter->ordinal == $firstVerseObject->chapter->ordinal) {
				$classCurrent = 'class="current" ';
			}
			$chapterLinks .= sprintf('<a %shref="/1/lookup/%s">%s %d</a><br />', $classCurrent, $chapter->getPath(),
			    $chapter->book->shortNameRaw, $chapter->ordinal);
		}
		$browsingLeft = Chleb::Server::Dancer2::fetchStaticPage('browsing_left', {
			CHAPTER_LINKS => $chapterLinks,
		});
	}

	my $thisChapter = $json->[0]->{data}->[0]->{links}->{first};
	$self->dic->logger->trace("Link kludge in effect (pre): ${thisChapter}");
	my $thisChapter_KLUDGE = $thisChapter;
	$thisChapter_KLUDGE =~ s@/1(?=\?)@@; # TODO: This is a kludge, the JSON should provide it somehow.
	if ($thisChapter_KLUDGE eq $thisChapter) {
		$thisChapter_KLUDGE =~ s@/1$@@; # TODO: This is a kludge, the JSON should provide it somehow.
	}
	$self->dic->logger->trace("Link kludge in effect (post): ${thisChapter_KLUDGE}");
	my $settingsLink = '<a class="vn-link vn-settings" href="/settings" title="Settings" aria-label="Settings">'
	    . '<span class="vn-settings-icon" aria-hidden="true">⚙</span>'
	    . '<span class="vn-settings-text"> Settings</span></a>';

	my $browsingHead = Chleb::Server::Dancer2::fetchStaticPage('browsing_head', {
		PREV_BOOK_URL => $prevBookLink,
		PREV_CHAPTER_URL => $prevChapterLink,
		HOME_URL => __linkToHome(),
		BOOK_URL => sprintf($bookLinkFormat, 'book index'),
		CHAPTER_URL => '<a class="vn-link vn-chapter" href="' . $thisChapter_KLUDGE . '">this chapter</a>',
		NEXT_CHAPTER_URL => $nextChapterLink,
		NEXT_BOOK_URL => $nextBookLink,
		PERMALINK_URL => '<a class="vn-link vn-verse" href="' . $json->[0]->{data}->[0]->{links}->{self} . '">permalink</a>',
		SETTINGS_URL => $settingsLink,
		FIRST_VERSE_URL => '<a class="vn-link vn-verse" href="' . $json->[0]->{data}->[0]->{links}->{first} . '">first verse</a>',
		FIRST_CHAPTER_URL => sprintf($bookLinkFormat, 'first chapter'),
		LAST_CHAPTER_URL => $lastChapterLink,
		PREV_VERSE_URL => '<a class="vn-link vn-verse" href="' . $json->[0]->{data}->[0]->{links}->{prev} . '">prev verse</a>',
		NEXT_VERSE_URL => '<a class="vn-link vn-verse" href="' . $json->[0]->{data}->[0]->{links}->{next} . '">next verse</a>',
		LAST_VERSE_URL => '<a class="vn-link vn-verse" href="' . $json->[0]->{data}->[0]->{links}->{last} . '">last verse</a>',
		RANDOM_URL => $random,
		BOOKS => $self->__makeBooks($firstVerseObject->book),
	});

	my $title = 'FIXME';
	if ($function == $FUNCTION_RANDOM) {
		$title = 'Random Verse';
	} elsif ($function == $FUNCTION_VOTD) {
		$title = 'Verse of The Day';
	} else {
		$title = 'Lookup';
	}

	return Chleb::Server::Dancer2::fetchStaticPage('verse', {
		TITLE => "Chleb Bible Search - ${title}",
		REFERENCE => $reference,
		HOME => __linkToHome(),
		VERSES => $output,
		TRANSLATION => $translation,
		SENTIMENTS => $sentiments,
		BROWSING_LEFT => $browsingLeft,
		BROWSING_HEAD => $browsingHead,
	});
}

sub __makeBooks {
	my ($self, $currentBook) = @_;

	my $thisBookName;
	if ($currentBook) {
		$thisBookName = $currentBook->shortName;
	} else {
		$thisBookName = Chleb::Server::Dancer2::_param('book');
	}

	my $books = $self->__library->info->bibles->[0]->books; # TODO: do we need info, or can we skip it somehow?
	my @options = ( );
	foreach my $book (@$books) {
		my $isSelected = ($thisBookName eq $book->shortName);
		push(@options, sprintf('<option value="%s"%s>%s (%d)</option>',
			$book->shortName,
			($isSelected ? ' selected' : ''),
			$book->longName,
			$book->chapterCount,
		));
	}

	my $html='<form action="/1/lookup" method="GET">
		<select name="book">
	';

	$html .= join("\r\n", @options)
	    . '</select>
		<input type="hidden" name="chapter" value="1">
		<button>→</button>
	</form>';

	return $html;
}

sub __searchResultsToHtml {
	my ($json, $options) = @_;
	$options ||= {};

	if (0 == scalar(@{ $json->{data} })) { # no results?
		return Chleb::Server::Dancer2::fetchStaticPage('no_results');
	}

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
	$text .= __linkToHome() if (!exists($options->{includeHome}) || $options->{includeHome});
	$text .= "<table class=\"info-table\">\r\n";
	$text .= "<tr>\r\n";
	$text .= "<th>Result</th>\r\n";
	$text .= "<th>Verse</th>\r\n";
	$text .= "<th>Text</th>\r\n";
	$text .= "</tr>\r\n";

	for (my $resultI = 0; $resultI < scalar(@{ $json->{data} }); $resultI++) {
		my $verse = $json->{data}->[$resultI];
		my $attributes = $verse->{attributes};
		my $bookShortName = $rawBookNameMap{ $attributes->{book} };

		my $linkToVerse = __linkToVerse(
			undef,
			$bookShortName,
			$attributes->{chapter},
			$attributes->{ordinal},
			{ includeBookName => 1 },
		);

		$text .= "<tr>\r\n";
		$text .= sprintf("<td>%s</td>\r\n", $attributes->{title});
		$text .= sprintf("<td>%s</td>\r\n", $linkToVerse);
		$text .= sprintf("<td>%s</td>\r\n", $attributes->{text});
		$text .= "</tr>\r\n";
	}

	$text .= "</table>\r\n";
	$text .= __searchPaginationToHtml($json);

	return $text;
}

=item C<__searchPaginationToHtml($json)>

Renders search pagination links as an HTML navigation block.

C<$json> is the same C<JSON:API> style response hash used by the search results
HTML renderer.  The function reads pagination
metadata from the C<results_summary> included item and uses the response links
to render C<Previous>, C<Next>, and page-number links.  When there is only one
logical page, an empty string is returned.

=cut

sub __searchPaginationToHtml {
	my ($json) = @_;

	my $summary;
	foreach my $includedItem (@{ $json->{included} }) {
		if ($includedItem->{type} eq 'results_summary') {
			$summary = $includedItem->{attributes};
			last;
		}
	}

	return '' unless ($summary && $summary->{total_pages} > 1);

	my $page = $summary->{page};
	my $totalPages = $summary->{total_pages};
	my $html = "<nav class=\"pagination\" aria-label=\"Search result pages\">\r\n";
	$html .= sprintf("\t<a href=\"%s\">Previous</a>\r\n", $json->{links}->{prev}) if ($json->{links}->{prev});
	for (my $i = 1; $i <= $totalPages; $i++) {
		my $link = __replaceSearchLinkPage($json->{links}->{self}, $i);
		if ($i == $page) {
			$html .= sprintf("\t<strong>%d</strong>\r\n", $i);
		} else {
			$html .= sprintf("\t<a href=\"%s\">%d</a>\r\n", $link, $i);
		}
	}
	$html .= sprintf("\t<a href=\"%s\">Next</a>\r\n", $json->{links}->{next}) if ($json->{links}->{next});
	$html .= "</nav>\r\n";

	return $html;
}

=item C<__replaceSearchLinkPage($link, $page)>

Rewrites the C<page> query parameter in a search pagination URL.

C<$link> is an existing search page link and C<$page> is the replacement page
number.  The function returns the updated URL and leaves all other query
parameters unchanged.

=cut

sub __replaceSearchLinkPage {
	my ($link, $page) = @_;
	$link =~ s/([?&]page=)[^&]*/$1$page/;
	return $link;
}

sub __linkToHome { # add a link to home (root)
	my $output = "<p>\r\n";
	$output .= sprintf("\t<a class=\"vn-link vn-home\" href=\"%s\">%s</a>\r\n", '/', 'home');
	$output .= "</p>\r\n";
	return $output;
}

sub __linkToVerse {
	my ($linkText, $bookShortName, $chapterOrdinal, $verseOrdinal, $options) = @_;

	if ($options) {
		my %knownOptions = map { $_ => 1 } (qw(includeBookName));

		foreach my $option (keys(%$options)) {
			next if ($knownOptions{$option});
			die('unknown option -- ' . $option);
		}
	}

	if (!defined($linkText)) {
		if ($options->{includeBookName}) {
			$linkText = sprintf('%s [%d:%d]', $bookShortName, $chapterOrdinal, $verseOrdinal);
		} else {
			$linkText = sprintf('[%d:%d]', $chapterOrdinal, $verseOrdinal);
		}
	}

	return sprintf(
		'<a href="/1/lookup/%s/%d/%d">%s</a>',
		lc($bookShortName), # this is not ideal, we have a mixture of shortName and shortNameRaw callers
		$chapterOrdinal,
		$verseOrdinal,
		$linkText,
	);
}

sub __infoToHtml {
	my ($json) = @_;

	my $printCell = sub {
		my ($datum, $int, $header) = @_;
		my $formatter = '%' . ($int ? 'd' : 's');
		my $tag = ($header ? 'h' : 'd');
		return sprintf("<t${tag}>${formatter}</t${tag}>\r\n", $datum);
	};

	my %bookCache = ( );

	my $text = "<table class=\"info-table\">\r\n";

	$text .= "<tr>\r\n";
	$text .= $printCell->("Book", 0, 1);
	$text .= $printCell->("Ordinal", 0, 1);
	$text .= $printCell->("Chapters", 0, 1);
	$text .= $printCell->("Testament", 0, 1);
	$text .= $printCell->("Verses", 0, 1);
	$text .= $printCell->("Short name", 0, 1);
	$text .= $printCell->("Sample", 0, 1);
	$text .= "</tr>\r\n";

	my $linkToChapter = sub {
		my ($linkText, $bookShortName, $chapterOrdinal) = @_;
		return sprintf(
			'<a href="/1/lookup/%s/%d/%d">%s</a>',
			$bookShortName,
			$chapterOrdinal,
			1,  # FIXME: At time of writing, it isn't possible to link to a whole chapter, which will be a shorter link
			$linkText,
		);
	};

	my $linkToBook = sub {
		my ($linkText, $bookShortName) = @_;
		return $linkToChapter->($linkText, $bookShortName, 1);
	};

	for (my $includedI = 0; $includedI < scalar(@{ $json->{included} }); $includedI++) {
		my $included = $json->{included}->[$includedI];
		next if ($included->{type} ne 'book');

		my $attributes = $included->{attributes};

		$bookCache{ $attributes->{short_name} } = {
			longName => $attributes->{long_name},
			shortName => $attributes->{short_name},
		};

		$text .= "<tr>\r\n";
		$text .= $printCell->($linkToBook->(
			$attributes->{long_name},
			$attributes->{short_name},
		));
		$text .= $printCell->($attributes->{ordinal}, 1);
		$text .= $printCell->($attributes->{chapter_count}, 1);
		$text .= $printCell->($attributes->{testament});
		$text .= $printCell->($attributes->{verse_count}, 1);
		$text .= $printCell->($attributes->{short_name});
		$text .= $printCell->(sprintf(
			'%s %s',
			Chleb::Utils::limitText($attributes->{sample_verse_text}),
			__linkToVerse(
				undef,
				$attributes->{short_name},
				$attributes->{sample_verse_chapter_ordinal},
				$attributes->{sample_verse_ordinal_in_chapter},
			),
		));
		$text .= "</tr>\r\n";
	}

	$text .= "</table><br/>\r\n";

	$text .= "<table class=\"info-table\">\r\n";

	$text .= "<tr>\r\n";
	$text .= $printCell->("Book", 0, 1);
	$text .= $printCell->("Chapter", 0, 1);
	$text .= $printCell->("Verses", 0, 1);
	$text .= "</tr>\r\n";

	for (my $includedI = 0; $includedI < scalar(@{ $json->{included} }); $includedI++) {
		my $included = $json->{included}->[$includedI];
		next if ($included->{type} ne 'chapter');

		my $attributes = $included->{attributes};

		$text .= "<tr>\r\n";
		$text .= $printCell->($linkToBook->(
			$bookCache{ $attributes->{book} }->{longName},
			$bookCache{ $attributes->{book} }->{shortName},
		));
		$text .= $printCell->($linkToChapter->(
			$attributes->{ordinal},
			$attributes->{book},
			$attributes->{ordinal},
		));
		$text .= $printCell->(__linkToVerse(
			$attributes->{verse_count},
			$attributes->{book},
			$attributes->{ordinal},
			$attributes->{verse_count},
		));
		$text .= "</tr>\r\n";
	}

	$text .= "</table>\r\n";

	return $text;
}

=item C<__versionFilter($version, $minimum, $maximum)>

Throw a 400 error if C<$version> is outwith C<$minimum> and C<$maximum> values,
otherwise, C<$version> is returned.

=back

=cut

sub __versionFilter {
	my ($version, $minimum, $maximum) = @_;

	$version = int($version);
	die Chleb::Exception->raise(HTTP_BAD_REQUEST, "endpoint version must be between $minimum and $maximum, you said $version")
	    if ($version < $minimum || $version > $maximum);

	return $version;
}

sub __removeUptime {
	my ($self) = @_;
	my $uptimeFilePath = $self->__uptimeFilePath();

	my $logMessage = "Removing '$uptimeFilePath' -- ";
	my $result = unlink($uptimeFilePath);
	$logMessage .= sprintf('%d file(s) removed', int($result));

	$self->dic->logger->debug($logMessage);

	return;
}

# FIXME: Will leak memory over time, switch to a disk-based cache, or memcached
# additionally, this is a per-process store right now, which is probably not effective enough.
has __dampenTime => (isa => 'HashRef[Str]', is => 'rw', lazy => 1, default => sub {{}});
has __warnedSessionToken => (is => 'rw', isa => 'Bool', default => 0);

sub dampen {
	my ($self) = @_;
	my $ipAddress = Chleb::Server::Dancer2::_request()->address();
	my $currentTime = time();

	my $previousTime = $self->__dampenTime->{$ipAddress};
	if ($previousTime && $previousTime == $currentTime) {
		$self->dic->logger->warn(sprintf('Saw %s already this second, denying request', $ipAddress));
		return 1;
	}

	$self->__dampenTime->{$ipAddress} = $currentTime;
	return 0;
}

sub logRequest {
	my ($self) = @_;

	my $request = Chleb::Server::Dancer2::_request();
	my $ipAddress = $request->address();
	Log::Log4perl::MDC->put(address => $ipAddress);
	my $path = $request->path();

	$self->dic->logger->debug("Received request $path from $ipAddress");

	return;
}

sub handleSessionToken {
	my ($self) = @_;

	my $supportSessions = $self->dic->config->get('features', 'sessions', 'false', 1);
	return unless ($supportSessions);

	unless ($self->__warnedSessionToken) {
		$self->dic->logger->warn('Using experimental session cookie support, alpha quality, there are known bugs and limitations');
		$self->__warnedSessionToken(1);
	}

	my $request = Chleb::Server::Dancer2::_request();
	my $ipAddress = $request->address() // '';
	my $userAgent = $request->agent() // '';

	my $tokenRepo = $self->dic->tokenRepo;
	my $sessionToken = Chleb::Server::Dancer2::_cookie('sessionToken');

	if (!$sessionToken) {
		if ($self->dampen()) {
			Chleb::Server::Dancer2::handleException(Chleb::Exception->raise(
				HTTP_TOO_MANY_REQUESTS,
				'Slow down, or respect the sessionToken cookie', # TODO: Make a web page explaining this & link to it
			));
		}

		$sessionToken = $tokenRepo->create();
		Log::Log4perl::MDC->put(session => $sessionToken->shortValue);

		$sessionToken->ipAddress($ipAddress);
		$sessionToken->userAgent($userAgent);

		eval {
			$tokenRepo->save($sessionToken); # save via all configured backends
		};
		if (my $exception = $EVAL_ERROR) {
			Chleb::Server::Dancer2::handleException($exception);
		}

		$self->dic->logger->trace("No session token, created a new one: " . $sessionToken->toString());
		Chleb::Server::Dancer2::_cookie(sessionToken => $sessionToken->value, expires => $sessionToken->expires);

		return;
	}

	$self->dic->logger->trace("Got session token '$sessionToken' from client");
	eval {
		$sessionToken = $tokenRepo->load($sessionToken);
	};
	if (my $exception = $EVAL_ERROR) {
		Chleb::Server::Dancer2::handleException($exception);
	}

	Log::Log4perl::MDC->put(session => $sessionToken->shortValue);
	$self->dic->logger->trace('session token found: ' . $sessionToken->toString());

	if ($sessionToken->ipAddress ne $ipAddress) {
		$self->dic->logger->info(sprintf('%s the client changed IP address from %s to %s',
		    $sessionToken->toString(), $sessionToken->ipAddress, $ipAddress));

		$sessionToken->ipAddress($ipAddress);
	}

	if ($sessionToken->userAgent ne $userAgent) {
		$self->dic->logger->info(sprintf('%s the client changed user agent from %s to %s',
		    $sessionToken->toString(), $sessionToken->userAgent, $userAgent));

		$sessionToken->userAgent($userAgent);
	}

	if ($sessionToken->dirty) {
		eval {
			$tokenRepo->save($sessionToken); # save via all configured backends
		};
		if (my $exception = $EVAL_ERROR) {
			Chleb::Server::Dancer2::handleException($exception);
		}
	}

	return;
}

__PACKAGE__->meta->make_immutable;

1;
