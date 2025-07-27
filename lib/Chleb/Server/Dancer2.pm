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

package Chleb::Server::Dancer2;
use strict;
use warnings;
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
use English qw(-no_match_vars);
use HTTP::Status qw(:constants :is);
use POSIX qw(EXIT_SUCCESS);
use Scalar::Util qw(blessed);

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

sub serveStaticPage {
	my ($name, $templateParams) = @_;
	my $html = '';

	my $templateProcessor;
	my $filePathFailed;
	foreach my $filePath (@{ Chleb::Utils::explodeHtmlFilePath($name) }) {
		if (my $file = IO::File->new($filePath, 'r')) {
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
			send_as html => $html;
		}

		$filePathFailed = $filePath;
	}

	my $error = $ERRNO;
	send_error("Can't open file '$filePathFailed': $error", $server->dic->errorMapper->map(int($error)));
}

sub __configGetPublicDir {
	die('Moose server must be initialized') unless ($server);
	set public_dir => $server->dic->config->get('Dancer2', 'public_dir', 'data/static/public'),
}

get '/' => sub {
	$server->handleSessionToken();
	serveStaticPage('index');
	return;
};

get '/:version/random' => sub {
	$server->handleSessionToken();

	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(param('translations')));
	my $version = int(param('version') || 1);
	my $parental = Chleb::Utils::boolean('parental', param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', param('redirect'), 0);

	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__random({
			accept => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
			translations => $translations,
			testament => param('testament'),
			version => $version,
			parental => $parental,
 			redirect => $redirect,
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
	return $result;
};

get '/1/votd' => sub {
	$server->handleSessionToken();

	my $parental = Chleb::Utils::boolean('parental', param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', param('redirect'), 0);
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
	$server->handleSessionToken();

	my $parental = Chleb::Utils::boolean('parental', param('parental'), 0);
	my $redirect = Chleb::Utils::boolean('redirect', param('redirect'), 0);
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(param('translations')));
	my $when = param('when');
	my $testament = param('testament');
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
	$server->handleSessionToken();

	my $book = param('book');
	my $chapter = param('chapter');
	my $verse = param('verse');
	my $translations = Chleb::Utils::removeArrayEmptyItems(Chleb::Utils::forceArray(param('translations')));

	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__lookup({
			accept       => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
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
	$server->handleSessionToken();

	my $limit = param('limit');
	my $term = param('term');
	my $wholeword = param('wholeword');

	my $dancerRequest = request();

	my $result;
	eval {
		$result = $server->__search({
			accept    => Chleb::Server::MediaType->parseAcceptHeader($dancerRequest->header('Accept')),
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

get '/2/search' => sub {
	$server->handleSessionToken();

	my $limit = param('limit') ? int(param('limit')) : $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT;
	my $term = param('term');
	my $wholeword = param('wholeword');

	my %templateParams = (
		SEARCH_LIMIT_DEFAULT => $Chleb::Bible::Search::Query::SEARCH_RESULTS_LIMIT,
		SEARCH_LIMIT_MAX => 2_000, # What's reasonable?  It isn't enforced by the backend anyway
		SEARCH_LIMIT_VALUE => $limit,
		SEARCH_TERM => $term,
		SEARCH_WHOLEWORD => Chleb::Utils::boolean('wholeword', $wholeword, 0) ? 'checked' : '',
	);

	serveStaticPage('search', \%templateParams);

	return;
};

get '/1/ping' => sub {
	$server->handleSessionToken();
	return $server->__ping();
};

get '/1/version' => sub {
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
	$server->handleSessionToken();
	return $server->__uptime();
};

get '/1/info' => sub {
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
