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

use Chleb::Utils::OSError::Mapper;
use Chleb::Server::Moose;
use English qw(-no_match_vars);
use HTTP::Status qw(:constants :is);
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

sub serveStaticPage {
	my ($name) = @_;
	my $html = '';

	my $filePathFailed;
	foreach my $filePath (@{ Chleb::Utils::explodeHtmlFilePath($name) }) {
		if (my $file = IO::File->new($filePath, 'r')) {
			while (my $line = $file->getline()) {
				$html .= $line;
			}

			$file->close();
			send_as html => $html;
		}

		$filePathFailed = $filePath;
	}

	my $error = $ERRNO;
	send_error("Can't open file '$filePathFailed': $error", $server->dic->errorMapper->map(int($error)));
}

get '/' => sub {
	serveStaticPage('index');
	return;
};

get '/:version/random' => sub {
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
	return $self->dance;
}

1;
