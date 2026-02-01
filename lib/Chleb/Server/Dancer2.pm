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
set content_type => $Chleb::Server::MediaType::CONTENT_TYPE_JSON;
set static_handler => 1;

sub _cookie {
	my (@args) = @_;
	return cookie(@args);
}

sub _request {
	my (@args) = @_;
	return request(@args);
}

sub handleException {
	my ($exception) = @_;

	my $str;
	if (blessed($exception)) {
		if ($exception->isa('Chleb::Exception')) {
			$server->dic->logger->debug('Returning ' . $exception->toString());
			if (is_redirect($exception->statusCode)) {
				return redirect $exception->location, $exception->statusCode;
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
	send_error($exception, 500);

	return;
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
	send_error("Can't open file '$filePathFailed': $error", $server->dic->errorMapper->map(int($error)));
}

sub serveStaticPage {
	my ($name, $templateParams) = @_;
	send_as html => fetchStaticPage($name, $templateParams);
}

sub __configGetPublicDir {
	die('Moose server must be initialized') unless ($server);
	set public_dir => $server->dic->config->get('Dancer2', 'public_dir', 'data/static/public'),
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
	return undef unless (defined($value));
	return __detaint($value, $name);
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

	my $mailingListVoTDHtml = '';
	if ($server->dic->config->get('features', 'mailing_list_votd', 'true', 1)) {
		$mailingListVoTDHtml = fetchStaticPage('mailing_list_votd', {
			MAILING_LIST_VOTD_GROUPNAME => $server->dic->config->get('mailing_list_votd', 'groupname', 'chleb-votd'),
			MAILING_LIST_VOTD_URL => $server->dic->config->get('mailing_list_votd', 'url', 'https://lists.sr.ht/~m6kvm/chleb-votd'),
		});
	}

	serveStaticPage('index', {
		FACEBOOK_HTML => $facebookHtml,
		HOSTNAME => hostname(),
		MAILING_LIST_VOTD_HTML => $mailingListVoTDHtml,
	});

	return;
};

get '/:version/random' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(_param('translations')));
	my $version = int(_param('version') || 1);
	my $parental = Chleb::Utils::boolean('parental', _param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', _param('redirect'), 0);

	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__random({
			accept => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
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
		my $resultHtml = $result;
		$result = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: random verse lookup" });
		$result .= $resultHtml;
		$result .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace("${version}/random returned as HTML");
		send_as html => $result;
	}

	$server->dic->logger->trace("${version}/random returned as JSON");
	return $result;
};

get '/1/votd' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $parental = Chleb::Utils::boolean('parental', _param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', _param('redirect'), 0);
	my $when = _param('when');
	my $testament = _param('testament');

	my $result;
	eval {
		$result = $server->__votd({
			parental    => $parental,
			redirect    => $redirect,
			when        => $when,
			testament   => $testament,
			form        => 0,
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	return $result;
};

get '/2/votd' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $parental = Chleb::Utils::boolean('parental', _param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', _param('redirect'), 0);
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(_param('translations')));
	my $when = _param('when');
	my $testament = _param('testament');
	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__votd({
			accept       => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
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
		my $resultHtml = $result;
		$result = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Verse of The Day" });
		$result .= $resultHtml;
		$result .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('2/votd returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('2/votd returned as JSON');
	return $result;
};

get '/1/lookup' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $book = _param('book') // '';
	my $chapter = _param('chapter') // 1;
	my $verse = _param('verse');

	if (defined($verse) && length($verse) > 0) {
		redirect "/1/lookup/${book}/${chapter}/${verse}", 307;
	}

	redirect "/1/lookup/${book}/${chapter}", 307;
};

get '/1/lookup/:book/:chapter' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $book = param('book') // '';
	my $chapter = param('chapter') // '';
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(param('translations')));

	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__lookup({
			accept       => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
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
		my $resultHtml = $result;
		$result = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Lookup ${book} ${chapter}" });
		$result .= $resultHtml;
		$result .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('1/lookup chapter returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/lookup chapter returned as JSON');
	return $result;
};

get '/1/lookup/:book/:chapter/:verse' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $book = _param('book') // '';
	my $chapter = _param('chapter') // '';
	my $verse = _param('verse') // '';
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(_param('translations')));

	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__lookup({
			accept       => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
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
		my $resultHtml = $result;
		$result = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Lookup ${book} ${chapter}:${verse}" });
		$result .= $resultHtml;
		$result .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('1/lookup verse returned as HTML');
		send_as html => $result;
	} elsif (ref($result) eq 'ARRAY') {
		$result = $result->[0];
	}

	$server->dic->logger->trace('1/lookup verse returned as JSON');
	return $result;
};

get '/1/search' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $limit = _param('limit') ? int(_param('limit')) : $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT;
	my $term = _param('term') // '';
	my $wholeword = _param('wholeword');
	my $form = Chleb::Utils::boolean('form', _param('form'), 0);

	my $dancerRequest = request();

	my $result = '';
	my $resultHash;
	if ($term) {
		eval {
			($result, $resultHash) = $server->__search({
				accept    => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
				form      => $form,
				limit     => $limit,
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
			SEARCH_RESULTS => $result,
			SEARCH_TERM => $term,
			SEARCH_WHOLEWORD => Chleb::Utils::boolean('wholeword', $wholeword, 0) ? 'checked' : '',
			TITLE => $title,
		);

		my $searchPage = fetchStaticPage('search', \%templateParams);
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
	return $result;
};

get '/1/ping' => sub {
	$server->logRequest();
	$server->handleSessionToken();
	return $server->__ping();
};

get '/1/version' => sub {
	$server->logRequest();
	$server->handleSessionToken();

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
	$server->logRequest();
	$server->handleSessionToken();
	return $server->__uptime();
};

get '/1/info' => sub {
	$server->logRequest();
	$server->handleSessionToken();

	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__info({
			accept => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
		});
	};

	if (my $exception = $EVAL_ERROR) {
		handleException($exception);
	}

	if (ref($result) ne 'HASH') {
		my $resultHtml = $result;
		$result = fetchStaticPage('generic_head', { TITLE => "${PROJECT}: Bible info" });
		$result .= $resultHtml;
		$result .= fetchStaticPage('generic_tail');

		$server->dic->logger->trace('1/info returned as HTML');
		send_as html => $result;
	}

	$server->dic->logger->trace('1/info returned as JSON');
	return $result;
};

sub run {
	my ($self) = @_;
	$server = Chleb::Server::Moose->new();
	__configGetPublicDir();
	return $self->dance;
}

1;
