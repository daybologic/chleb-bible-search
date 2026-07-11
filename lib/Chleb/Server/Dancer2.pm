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

package Chleb::Server::Dancer2;
use strict;
use warnings;
use utf8;
binmode STDOUT, ":encoding(UTF-8)";
use Dancer2 0.2;

=head1 NAME

Chleb::Server::Dancer2

=head1 DESCRIPTION

Pass this object to Plack to launch the server!

=cut

use Chleb::Bible::Search::Query;
use Chleb::Server::Moose;
use Chleb::TemplateProcessor;
use Chleb::Utils::OSError::Mapper;
use Chleb::Utils::SecureString;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants :is);
use POSIX qw(EXIT_SUCCESS);
use Readonly;
use Scalar::Util qw(blessed);
use Sys::Hostname;

Readonly my $PROJECT => 'Chleb Bible Search';

my $server;

set serializer => 'JSON'; # or any other serializer
set content_type => $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API;
set static_handler => 1;

sub _cookie {
	my (@args) = @_;
	return cookie(@args);
}

sub _request {
	my (@args) = @_;
	return request(@args);
}

=head1 __setJsonResponseContentType($accept, $default)

Sets the response content type when the client accepts one of the supported
JSON media types.

C<$accept> is the request C<Accept> header value.  C<$default> is the fallback
media type used when the header does not select a supported type.  The Dancer2
response content type is updated only when negotiation resolves to either
C<application/json> or the JSON:API media type, leaving HTML responses to the
route handlers that serve them.

=cut

sub __setJsonResponseContentType {
	my ($accept, $default) = @_;

	my $contentType = Chleb::Server::MediaType::acceptToContentType($accept, $default);
	if (
		$contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON
		|| $contentType eq $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API
	) {
		content_type $contentType;
	}

	return;
}

=head1 __preferredTranslations($paramPresent, $paramValue, $preferredTranslation)

Resolves the translation filters for a request which supports preferred
translations.

When C<$paramPresent> is true, C<$paramValue> is parsed as the explicit
C<translations> request parameter and always takes precedence over the
preferred translation cookie.  This includes an explicitly supplied empty
parameter, which resolves to no translation filter rather than falling back to
the cookie.

When the request parameter is absent, C<$preferredTranslation> may be either a
cookie object with a C<value()> method or its scalar value.  The supported
C<asv> and C<kjv> preferences may be stored singly or as a comma-separated
list, and are returned as an array reference.  The C<all> preference is also
supported.  The C<default> preference, missing values, and unsupported values
return an empty array reference so that normal lookup translation selection
applies.

=cut

sub __preferredTranslations {
	my ($paramPresent, $paramValue, $preferredTranslation) = @_;

	if ($paramPresent) {
		return Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray($paramValue));
	}

	if (blessed($preferredTranslation) && $preferredTranslation->can('value')) {
		$preferredTranslation = $preferredTranslation->value;
	}

	return [] unless (defined($preferredTranslation) && length($preferredTranslation) > 0);

	my @translations = @{ Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray($preferredTranslation)) };
	return [] if (grep { $_ eq 'default' } @translations);
	return [ 'all' ] if (grep { $_ eq 'all' } @translations);

	my @supportedTranslations;
	my %seenTranslation;
	foreach my $translation (@translations) {
		next unless ($translation =~ m/\A(?:asv|kjv)\z/);
		next if ($seenTranslation{$translation});

		push(@supportedTranslations, $translation);
		$seenTranslation{$translation}++;
	}

	return \@supportedTranslations;
}

=head1 __preferredWholeword($paramPresent, $paramValue, $wholeword)

Resolves the whole-word search preference.

When C<$paramPresent> is true, C<$paramValue> is parsed as the explicit
C<wholeword> request parameter and always takes precedence over the cookie.
This includes an explicitly empty value, which resolves to false rather than
falling back to the cookie.

When the request parameter is absent, C<$wholeword> may be either a cookie
object with a C<value()> method or its scalar value.  Valid boolean cookie
values are honoured, and unsupported cookie values are ignored.

=cut

sub __preferredWholeword {
	my ($paramPresent, $paramValue, $wholeword) = @_;

	if ($paramPresent) {
		return Chleb::Utils::boolean('wholeword', $paramValue, 0);
	}

	if (blessed($wholeword) && $wholeword->can('value')) {
		$wholeword = $wholeword->value;
	}

	return 0 unless (defined($wholeword) && length($wholeword) > 0);

	my $preferredWholeword = 0;
	eval {
		$preferredWholeword = Chleb::Utils::boolean('wholeword', $wholeword, 0);
	};

	return $EVAL_ERROR ? 0 : $preferredWholeword;
}

=head1 __previousSearchLimit($paramPresent, $paramValue, $previousSearchLimit)

Resolves the search limit for the search form and endpoint.

When C<$paramPresent> is true, C<$paramValue> is parsed as the explicit
C<limit> request parameter and always takes precedence over the cookie.  When
the request parameter is absent, C<$previousSearchLimit> may be either a cookie
object with a C<value()> method or its scalar value.  Positive integer cookie
values are honoured; missing or unsupported values fall back to the default
search result limit.

=cut

sub __previousSearchLimit {
	my ($paramPresent, $paramValue, $previousSearchLimit) = @_;

	if ($paramPresent) {
		return defined($paramValue) && $paramValue =~ m/\A[0-9]+\z/ && int($paramValue) > 0
			? int($paramValue)
			: $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT;
	}

	if (blessed($previousSearchLimit) && $previousSearchLimit->can('value')) {
		$previousSearchLimit = $previousSearchLimit->value;
	}

	return $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT
		unless (defined($previousSearchLimit) && $previousSearchLimit =~ m/\A[0-9]+\z/ && int($previousSearchLimit) > 0);

	return int($previousSearchLimit);
}

=head1 __previousSearchPerPage($paramPresent, $paramValue, $previousSearchPerPage)

Resolves the preferred search page size for the search form and endpoint.

When C<$paramPresent> is true, C<$paramValue> is parsed as the explicit
C<per_page> request parameter and always takes precedence over the cookie.
When the request parameter is absent, C<$previousSearchPerPage> may be either a
cookie object with a C<value()> method or its scalar value.  Positive integer
cookie values are honoured; missing or unsupported values fall back to the
default search page size.  Values above the maximum page size are reduced to
that maximum.

=cut

sub __previousSearchPerPage {
	my ($paramPresent, $paramValue, $previousSearchPerPage) = @_;

	if ($paramPresent) {
		if (defined($paramValue) && $paramValue =~ m/\A[0-9]+\z/ && int($paramValue) > 0) {
			return $Chleb::Server::Moose::SEARCH_RESULTS_MAX_PAGE_SIZE
				if (int($paramValue) > $Chleb::Server::Moose::SEARCH_RESULTS_MAX_PAGE_SIZE);

			return int($paramValue);
		}

		return $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT;
	}

	if (blessed($previousSearchPerPage) && $previousSearchPerPage->can('value')) {
		$previousSearchPerPage = $previousSearchPerPage->value;
	}

	return $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT
		unless (defined($previousSearchPerPage) && $previousSearchPerPage =~ m/\A[0-9]+\z/ && int($previousSearchPerPage) > 0);

	return $Chleb::Server::Moose::SEARCH_RESULTS_MAX_PAGE_SIZE
		if (int($previousSearchPerPage) > $Chleb::Server::Moose::SEARCH_RESULTS_MAX_PAGE_SIZE);

	return int($previousSearchPerPage);
}

sub handleException {
	my ($exception) = @_;

	my $str;
	if (blessed($exception)) {
		if ($exception->isa('Chleb::Exception')) {
			$server->dic->logger->debug('Returning ' . $exception->toString());
			if (is_redirect($exception->statusCode)) {
				return redirect $exception->location, $exception->statusCode;
			} elsif (defined($exception->retryAfterSeconds)) {
				status $exception->statusCode;
				content_type $Chleb::Server::MediaType::CONTENT_TYPE_JSON_API;
				response_header 'Retry-After' => $exception->retryAfterSeconds;
				return halt($exception->toJsonApiErrorDocument());
			} else {
				send_error($exception->description, $exception->statusCode);
			}
		} elsif ($exception->can('toString')) {
			$str = $exception->toString();
		}
	} else {
		$str = $exception;
	}

	$server->dic->logger->error("Internal Server Error: $exception");
	return send_error($exception, 500);
}

sub fetchStaticPage {
	my ($name, $templateParams) = @_;
	my $html = '';

	my $templateProcessor;
	my $filePathFailed;
	foreach my $filePath (@{ Chleb::Utils::explodeHtmlFilePath($name) }) {
		if (my $file = IO::File->new($filePath, '<:encoding(UTF-8)')) {
			my $templateMode = 0; # off
			my $lineCounter = 0;
			while (my $line = $file->getline()) {
				$lineCounter++;

				if ($templateMode) {
					$templateProcessor = Chleb::TemplateProcessor->new({ params => $templateParams })
					    unless ($templateProcessor);

					$html .= $templateProcessor->byLine($line);
				} else {
					$html .= $line;

					if ($lineCounter <= 10) {
						chomp($line);
						$line =~ s/\s*//g;
						if (lc($line) eq '<!--chlebtemplate-->') {
							$templateMode = 1; # on
						}
					}
				}
			}

			$file->close();
			return $html;
		}

		$filePathFailed = $filePath;
	}

	my $error = $ERRNO;
	return send_error("Can't open file '$filePathFailed': $error", $server->dic->errorMapper->map(int($error)));
}

sub serveStaticPage {
	my ($name, $templateParams) = @_;
	send_as html => fetchStaticPage($name, $templateParams);
	return;
}

sub __configSetPublicDir {
	die('Moose server must be initialized') unless ($server);
	set public_dir => $server->dic->config->get('Dancer2', 'public_dir', 'data/static/public');
	return;
}

sub __detaint {
	my ($value, $name) = @_;

	my $detainted;
	eval {
		my $mode = $Chleb::Utils::SecureString::MODE_TRAP;
		$detainted = Chleb::Utils::SecureString::detaint($value, $mode, $name)->value;
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	return $detainted;
}

sub _param {
	my ($name) = @_;

	my $value = param($name);
	if (defined($value)) {
		$value = __detaint($value, $name);
	}

	# $value be undef, we never return nothing,
	# because the Chleb::Utils::forceArray wouldn't work properly.
	return $value;
}

get '/' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $facebookHtml = '';
	if ($server->dic->config->get('features', 'facebook', 'true', 1)) {
		$facebookHtml = fetchStaticPage('facebook', {
			FACEBOOK_GROUPNAME => $server->dic->config->get('facebook', 'groupname', 'Chleb Bible Search (1268737414574145)'),
			FACEBOOK_URL => $server->dic->config->get('facebook', 'url', 'https://www.facebook.com/share/g/17D2hgSmGK/?mibextid=wwXIfr'),
		});
	}

	my $twitterHtml = '';
	if ($server->dic->config->get('features', 'twitter', 'false', 1)) {
		$twitterHtml = fetchStaticPage('twitter', {
			TWITTER_USERNAME => $server->dic->config->get('twitter', 'username', 'ChlebSearch'),
			TWITTER_URL => $server->dic->config->get('twitter', 'url', 'https://x.com/ChlebSearch'),
		});
	}

	my $mailingListVoTDHtml = '';
	if ($server->dic->config->get('features', 'mailing_list_votd', 'true', 1)) {
		$mailingListVoTDHtml = fetchStaticPage('mailing_list_votd', {
			MAILING_LIST_VOTD_GROUPNAME => $server->dic->config->get('mailing_list_votd', 'groupname', 'chleb-votd'),
			MAILING_LIST_VOTD_URL => $server->dic->config->get('mailing_list_votd', 'url', 'https://lists.sr.ht/~m6kvm/chleb-votd'),
		});
	}

	my $result = fetchStaticPage('generic_head', { TITLE => 'Chleb Bible Search Service' });
	$result .= fetchStaticPage('index', {
		FACEBOOK_HTML => $facebookHtml,
		HOSTNAME => hostname(),
		MAILING_LIST_VOTD_HTML => $mailingListVoTDHtml,
		TWITTER_HTML => $twitterHtml,
	});
	$result .= fetchStaticPage('generic_tail');

	send_as html => $result;

	return;
};

get '/settings' => sub {
	$server->logRequest();
	$server->handleSessionToken();
	my $result = fetchStaticPage('generic_head', { TITLE => 'Settings - Chleb Bible Search' });
	$result .= fetchStaticPage('public/settings');
	$result .= fetchStaticPage('generic_tail');
	send_as html => $result;
	return;
};

get '/:version/random' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $version = int(_param('version') || 1);
	my $parental = Chleb::Utils::boolean('parental', _param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', _param('redirect'), 0);

	my $dancerRequest = request();
	my $accept;
	my $queryParams = $dancerRequest->params('query');
	my $translations = __preferredTranslations(
		exists($queryParams->{translations}),
		_param('translations'),
		_cookie('preferredTranslation'),
	);

	my $result;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$result = $server->__random({
			accept => $accept,
			translations => $translations,
			testament => _param('testament'),
			version => $version,
			parental => $parental,
 			redirect => $redirect,
			form => 0,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		$server->dic->logger->trace("${version}/random returned as HTML");
		send_as html => $result;
	}

	$server->dic->logger->trace("${version}/random returned as JSON");
	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);
	return $result;
};

get '/1/votd' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $parental = Chleb::Utils::boolean('parental', _param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', _param('redirect'), 0);
	my $when = _param('when');
	my $testament = _param('testament');
	my $dancerRequest = request();
	my $accept;
	my $queryParams = $dancerRequest->params('query');
	my $translations = __preferredTranslations(
		exists($queryParams->{translations}),
		_param('translations'),
		_cookie('preferredTranslation'),
	);

	my $result;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$result = $server->__votd({
			accept       => $accept,
			parental    => $parental,
			redirect    => $redirect,
			translations => $translations,
			when        => $when,
			testament   => $testament,
			form        => 0,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);
	return $result;
};

get '/2/votd' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $parental = Chleb::Utils::boolean('parental', _param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', _param('redirect'), 0);
	my $when = _param('when');
	my $testament = _param('testament');
	my $dancerRequest = request();
	my $accept;
	my $queryParams = $dancerRequest->params('query');
	my $translations = __preferredTranslations(
		exists($queryParams->{translations}),
		_param('translations'),
		_cookie('preferredTranslation'),
	);

	my $result;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$result = $server->__votd({
			accept       => $accept,
			version      => 2,
			when         => $when,
			parental     => $parental,
			translations => $translations,
			redirect     => $redirect,
			testament    => $testament,
			form         => 0,
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
	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);
	return $result;
};

get '/1/lookup' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $book = _param('book') // '';
	my $chapter = _param('chapter') // 1;
	my $verse = _param('verse');
	my $queryParams = request()->params('query');
	my $translations = __preferredTranslations(
		exists($queryParams->{translations}),
		_param('translations'),
		_cookie('preferredTranslation'),
	);
	my $translationQuery = Chleb::Utils::queryParamsHelper({ translations => $translations });

	if (defined($verse) && length($verse) > 0) {
		redirect "/1/lookup/${book}/${chapter}/${verse}${translationQuery}", 307;
	}

	redirect "/1/lookup/${book}/${chapter}${translationQuery}", 307;
};

get '/1/lookup/:book/:chapter' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $book = param('book') // '';
	my $chapter = param('chapter') // '';
	my $dancerRequest = request();
	my $accept;
	my $queryParams = $dancerRequest->params('query');
	my $translations = __preferredTranslations(
		exists($queryParams->{translations}),
		_param('translations'),
		_cookie('preferredTranslation'),
	);

	my $result;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$result = $server->__lookup({
			accept       => $accept,
			book         => $book,
			chapter      => $chapter,
			translations => $translations,
			form         => 0,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH' && ref($result) ne 'ARRAY') {
		$server->dic->logger->trace('1/lookup chapter returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/lookup chapter returned as JSON');
	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);
	return $result;
};

get '/1/lookup/:book/:chapter/:verse' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $book = _param('book') // '';
	my $chapter = _param('chapter') // '';
	my $verse = _param('verse') // '';
	my $dancerRequest = request();
	my $accept;
	my $queryParams = $dancerRequest->params('query');
	my $translations = __preferredTranslations(
		exists($queryParams->{translations}),
		_param('translations'),
		_cookie('preferredTranslation'),
	);

	my $result;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$result = $server->__lookup({
			accept       => $accept,
			book         => $book,
			chapter      => $chapter,
			translations => $translations,
			verse        => $verse,
			form         => 0,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) eq '') {
		$server->dic->logger->trace('1/lookup verse returned as HTML');
		send_as html => $result;
	} elsif (ref($result) eq 'ARRAY') {
		$result = $result->[0];
	}

	$server->dic->logger->trace('1/lookup verse returned as JSON');
	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);
	return $result;
};

get '/1/search' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $dancerRequest = request();
	my $accept;
	my $queryParams = $dancerRequest->params('query');
	$queryParams = {} unless ($queryParams);
	my $limit = __previousSearchLimit(
		exists($queryParams->{limit}),
		_param('limit'),
		_cookie('previousSearchLimit'),
	);
	my $term = _param('term') // '';
	my $wholeword = __preferredWholeword(
		exists($queryParams->{wholeword}) || exists($queryParams->{wholeword_present}),
		_param('wholeword'),
		_cookie('wholeword'),
	);
	my $form = Chleb::Utils::boolean('form', _param('form'), 0);
	my $page = _param('page');
	my $perPage = __previousSearchPerPage(
		exists($queryParams->{per_page}),
		_param('per_page'),
		_cookie('previousSearchPerPage'),
	);

	my $result = '';
	my $resultHash;
	if ($term) {
		eval {
			$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
			($result, $resultHash) = $server->__search({
				accept    => $accept,
				form      => $form,
				limit     => $limit,
				page      => $page,
				per_page  => $perPage,
				term      => $term,
				wholeword => $wholeword,
			});
		};

		if (my $exception = $EVAL_ERROR) {
			handleException($exception);
		}
	}

	my $resultCount = $resultHash ? scalar(@{ $resultHash->{data} }) : 0;

	if (!$term || $form) {
		my $title;
		if (!$term) {
			$title = "$PROJECT: Perform user search";
		} elsif ($resultCount > 0) {
			$title = "$PROJECT: $resultCount results for '$term'";
		} else {
			$title = "$PROJECT: No results for '$term'";
		}

		my %templateParams = (
			SEARCH_LIMIT_DEFAULT => $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT,
			SEARCH_LIMIT_MAX => 2_000, # What's reasonable?  It isn't enforced by the backend anyway
			SEARCH_LIMIT_VALUE => $limit,
			SEARCH_PER_PAGE_DEFAULT => $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT,
			SEARCH_PER_PAGE_MAX => $Chleb::Server::Moose::SEARCH_RESULTS_MAX_PAGE_SIZE,
			SEARCH_PER_PAGE_VALUE => $perPage,
			SEARCH_RESULTS => $result,
			SEARCH_TERM => $term,
			SEARCH_WHOLEWORD => $wholeword ? 'checked' : '',
			TITLE => $title,
		);

		my $searchPage = fetchStaticPage('generic_head', { TITLE => $title });
		$searchPage .= fetchStaticPage('search', \%templateParams);
		$searchPage .= fetchStaticPage('generic_tail');
		send_as html => $searchPage;

		return;
	}

	if (ref($result) ne 'HASH') {
		if ($resultCount > 0) {
			my $resultHtml = $result;
			$result = fetchStaticPage('generic_head', { TITLE => "$PROJECT: $resultCount results for '$term'" });
			$result .= $resultHtml;
		} else {
			$result = fetchStaticPage('generic_head', { TITLE => "$PROJECT: No results for '$term'" });
			$result .= fetchStaticPage('no_results');
		}

		$result .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('1/search returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/search returned as JSON');
	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);
	return $result;
};

get '/1/ping' => sub {
	$server->logRequest();
	$server->handleSessionToken();
	my $dancerRequest = request();
	my $accept;

	my $ping;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$ping = $server->__ping({
			accept => $accept,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($ping) eq 'HASH') {
		__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_JSON);
		return $ping;
	} elsif (ref($ping) eq '') {
		my $resultHtml = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Ping" });
		$resultHtml .= $ping;
		$resultHtml .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('1/ping returned as HTML');
		send_as html => $resultHtml;
	} else {
		send_error('Unknown error', 500);
	}
};

get '/1/version' => sub {
	$server->logRequest();
	$server->handleSessionToken();
	my $dancerRequest = request();
	my $accept;

	my $version;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$version = $server->__version({
			accept => $accept,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($version) eq 'HASH') {
		__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_JSON);
		return $version;
	} elsif (ref($version) eq '' && $version eq '403') {
		send_error('Disabled by server administrator', $version);
	} elsif (ref($version) eq '') {
		my $resultHtml = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Server version" });
		$resultHtml .= $version;
		$resultHtml .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('1/version returned as HTML');
		send_as html => $resultHtml;
	} else {
		send_error('Unknown error', 500);
	}
};

get '/1/uptime' => sub {
	$server->logRequest();
	$server->handleSessionToken();
	my $dancerRequest = request();
	my $accept;

	my $result;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$result = $server->__uptime({
			accept => $accept,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		my $resultHtml = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Service uptime" });
		$resultHtml .= $result;
		$resultHtml .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('1/uptime returned as HTML');
		send_as html => $resultHtml;
	}

	$server->dic->logger->trace('1/uptime returned as JSON');
	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_JSON);
	return $result;
};

get '/1/info' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $dancerRequest = request();
	my $accept;

	my $result;
	eval {
		$accept = Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept'));
		$result = $server->__info({
			accept => $accept,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		my $resultHtml = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Bible info" });
		$resultHtml .= fetchStaticPage('info', {
			INFO_TABLES => $result,
		});
		$resultHtml .= fetchStaticPage('generic_tail');
		$result = $resultHtml;

		$server->dic->logger->trace('1/info returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/info returned as JSON');
	__setJsonResponseContentType($accept, $Chleb::Server::MediaType::CONTENT_TYPE_HTML);
	return $result;
};

sub run {
	my ($self) = @_;
	$server = Chleb::Server::Moose->new();
	__configSetPublicDir();
	return $self->dance;
}

1;
