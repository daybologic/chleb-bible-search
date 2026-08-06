#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Server_Dancer2_notFoundTests;
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Server::Dancer2;
use Chleb::Server::MediaType;
use English qw(-no_match_vars);
use HTTP::Request::Common qw(GET);
use Plack::Test;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testHtmlNotFoundPage {
	my ($self) = @_;
	plan tests => 7;

	my $accept = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = Chleb::Server::Dancer2::__notFoundHtml(
		$accept,
		q{Book 'wibble' was not found in any requested translation, did you mean amos, hag, quran? <here>},
	);

	like($html, qr{ <title>Chleb[ ]Bible[ ]Search:[ ]Page[ ]not[ ]found</title> }x, 'page has a not-found title');
	like($html, qr{ <h1>Page[ ]not[ ]found</h1> }x, 'page has a not-found heading');
	like($html, qr{ <img[ ]src="/images/404_not_found\.webp" }x, 'page displays the not-found illustration');
	like($html, qr{ width="273"[ ]height="214" }x, 'page displays the illustration at a compact size');
	like($html, qr{ did[ ]you[ ]mean[ ]amos,[ ]hag,[ ]quran\?[ ]&lt;here&gt; }x,
		'page displays the escaped reason and suggestions');
	unlike($html, qr{ <here> }x, 'page does not insert reason markup');
	like($html, qr{ <a[ ]href="/">Return[ ]to[ ]Chleb[ ]Bible[ ]Search</a> }x, 'page links home');

	return EXIT_SUCCESS;
}

sub testJsonNotFoundPage {
	my ($self) = @_;
	plan tests => 1;

	my $accept = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	is(Chleb::Server::Dancer2::__notFoundHtml($accept), undef, 'JSON keeps the existing error response');

	return EXIT_SUCCESS;
}

sub testHtmlInternalServerErrorPage {
	my ($self) = @_;
	plan tests => 6;

	my $htmlAccept = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = Chleb::Server::Dancer2::httpErrorHtml($htmlAccept, 500);
	my $title = '<title>Chleb Bible Search: Internal server error</title>';
	ok(index($html, $title) >= 0, 'page has an internal-server-error title');
	like($html, qr{ <h1>Internal[ ]server[ ]error</h1> }x, 'page has an internal-server-error heading');
	like($html, qr{ <img[ ]src="/images/500_internal_server_error\.webp" }x,
		'page displays the internal-server-error illustration');
	like($html, qr{ width="273"[ ]height="214" }x, 'page displays the illustration at a compact size');
	like($html, qr{ <a[ ]href="/">Return[ ]to[ ]Chleb[ ]Bible[ ]Search</a> }x, 'page links home');

	my $jsonAccept = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	is(Chleb::Server::Dancer2::httpErrorHtml($jsonAccept, 500), undef,
		'JSON keeps the existing internal-server-error response');

	return EXIT_SUCCESS;
}

sub testMalformedLookupOrdinalIsNotFound {
	my ($self) = @_;
	plan tests => 4;

	foreach my $ordinals ([ '1x', undef, 'chapter' ], [ 1, '1x', 'verse' ]) {
		my $evalOk; $evalOk = eval {
			Chleb::Server::Dancer2::__validateLookupOrdinals($ordinals->[0], $ordinals->[1]);
			1;
		} or $evalOk = 0;
		my $exception = $EVAL_ERROR;

		isa_ok($exception, 'Chleb::Exception', "malformed $ordinals->[2] raises a Chleb exception");
		is($exception->statusCode(), 404, "malformed $ordinals->[2] is not found");
	}

	return EXIT_SUCCESS;
}

sub testRouteNegotiatesHtml {
	my ($self) = @_;
	plan tests => 4;

	my $app = Chleb::Server::Dancer2->to_app();
	test_psgi($app, sub {
		my ($callback) = @_;
		my $response = $callback->(GET('/1/test/http/404', Accept => 'text/html'));

		is($response->code(), 404, 'unknown route returns 404');
		like($response->header('Content-Type'), qr{ \Atext/html }x, 'unknown route returns HTML content type');
		like($response->decoded_content(), qr{ The[ ]page[ ]you[ ]requested[ ]could[ ]not[ ]be[ ]found\. }x,
			'unknown route returns the generic reason');
		like($response->decoded_content(), qr{ <a[ ]href="/"> }x, 'unknown route links home');
	});

	return EXIT_SUCCESS;
}

sub testRoutePreservesJson {
	my ($self) = @_;
	plan tests => 3;

	my $app = Chleb::Server::Dancer2->to_app();
	test_psgi($app, sub {
		my ($callback) = @_;
		my $response = $callback->(GET('/1/test/http/404', Accept => 'application/json'));

		is($response->code(), 404, 'unknown JSON route returns 404');
		like($response->header('Content-Type'), qr{ \Aapplication/json }x, 'unknown JSON route retains JSON content type');
		like($response->decoded_content(), qr{ "status":404 }x, 'unknown JSON route retains JSON body');
	});

	return EXIT_SUCCESS;
}

sub testDeliberateInternalServerErrorRoute {
	my ($self) = @_;
	plan tests => 8;

	my $app = Chleb::Server::Dancer2->to_app();
	test_psgi($app, sub {
		my ($callback) = @_;

		my $html = $callback->(GET('/1/test/http/500', Accept => 'text/html'));
		is($html->code(), 500, 'dummy HTML endpoint returns 500');
		like($html->header('Content-Type'), qr{ \Atext/html }x, 'dummy HTML endpoint returns HTML');
		like($html->decoded_content(), qr{ <h1>Internal[ ]server[ ]error</h1> }x,
			'dummy HTML endpoint returns the internal-server-error page');
		unlike($html->decoded_content(), qr{ Deliberate[ ]500[ ]for[ ]testing }x,
			'dummy HTML endpoint does not expose exception details');
		like($html->decoded_content(), qr{ <a[ ]href="/"> }x, 'dummy HTML endpoint links home');

		my $json = $callback->(GET('/1/test/http/500', Accept => 'application/json'));
		is($json->code(), 500, 'dummy JSON endpoint returns 500');
		like($json->header('Content-Type'), qr{ \Aapplication/json }x, 'dummy JSON endpoint returns JSON');
		like($json->decoded_content(), qr{ Deliberate[ ]500[ ]for[ ]testing }x,
			'dummy JSON endpoint explains the deliberate failure');
	});

	return EXIT_SUCCESS;
}

sub testAllRegisteredHttpErrorPages {
	my ($self) = @_;
	my @codes = (
		400 .. 417,
		421 .. 426,
		428, 429, 431, 451,
		500 .. 508,
		511,
	);
	plan tests => 1 + (scalar(@codes) * 3);

	is_deeply(Chleb::Server::Dancer2::httpErrorCodes(), \@codes,
		'error registry contains every registered non-obsolete HTTP error status');
	my $htmlAccept = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $jsonAccept = Chleb::Server::MediaType->parseAcceptHeader('application/json');
	foreach my $code (@codes) {
		my $html = Chleb::Server::Dancer2::httpErrorHtml($htmlAccept, $code);
		like($html, qr{ <main> }x, "$code has an HTML template");
		like($html, qr{ <a[ ]href="/">Return[ ]to[ ]Chleb[ ]Bible[ ]Search</a> }x,
			"$code template links home");
		is(Chleb::Server::Dancer2::httpErrorHtml($jsonAccept, $code), undef,
			"$code leaves JSON responses unchanged");
	}

	return EXIT_SUCCESS;
}

sub testAllDeliberateHttpErrorRoutes {
	my ($self) = @_;
	my @codes = @{ Chleb::Server::Dancer2::httpErrorCodes() };
	plan tests => scalar(@codes) * 4;

	my $app = Chleb::Server::Dancer2->to_app();
	test_psgi($app, sub {
		my ($callback) = @_;
		foreach my $code (@codes) {
			my $html = $callback->(GET("/1/test/http/$code", Accept => 'text/html'));
			is($html->code(), $code, "$code HTML endpoint returns its status");
			like($html->header('Content-Type'), qr{ \Atext/html }x, "$code HTML endpoint returns HTML");

			my $json = $callback->(GET("/1/test/http/$code", Accept => 'application/json'));
			is($json->code(), $code, "$code JSON endpoint returns its status");
			like($json->header('Content-Type'), qr{ \Aapplication/json }x, "$code JSON endpoint returns JSON");
		}
	});

	return EXIT_SUCCESS;
}

sub testDeliberateHttpErrorHeaders {
	my ($self) = @_;
	my %expected = (
		401 => [ 'WWW-Authenticate'   => 'Test realm="Chleb"' ],
		405 => [ 'Allow'              => 'GET' ],
		407 => [ 'Proxy-Authenticate' => 'Test realm="Chleb"' ],
		416 => [ 'Content-Range'      => 'bytes */0' ],
		426 => [ 'Upgrade'            => 'HTTP/1.1' ],
		429 => [ 'Retry-After'        => '60' ],
		451 => [ 'Link'               => '<https://example.invalid/legal>; rel="blocked-by"' ],
		503 => [ 'Retry-After'        => '60' ],
	);
	plan tests => scalar(keys(%expected));

	my $app = Chleb::Server::Dancer2->to_app();
	test_psgi($app, sub {
		my ($callback) = @_;
		foreach my $code (sort({ $a <=> $b } keys(%expected))) {
			my $response = $callback->(GET("/1/test/http/$code", Accept => 'text/html'));
			my ($name, $value) = @{ $expected{$code} };
			is($response->header($name), $value, "$code returns $name");
		}
	});

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;
exit(Server_Dancer2_notFoundTests->new->run);
