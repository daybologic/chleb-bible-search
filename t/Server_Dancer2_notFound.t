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
	plan tests => 5;

	my $accept = Chleb::Server::MediaType->parseAcceptHeader('text/html');
	my $html = Chleb::Server::Dancer2::__notFoundHtml(
		$accept,
		q{Book 'wibble' was not found in any requested translation, did you mean amos, hag, quran? <here>},
	);

	like($html, qr{ <title>Chleb[ ]Bible[ ]Search:[ ]Page[ ]not[ ]found</title> }x, 'page has a not-found title');
	like($html, qr{ <h1>Page[ ]not[ ]found</h1> }x, 'page has a not-found heading');
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
		my $response = $callback->(GET('/definitely-not-a-route', Accept => 'text/html'));

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
		my $response = $callback->(GET('/definitely-not-a-route', Accept => 'application/json'));

		is($response->code(), 404, 'unknown JSON route returns 404');
		like($response->header('Content-Type'), qr{ \Aapplication/json }x, 'unknown JSON route retains JSON content type');
		like($response->decoded_content(), qr{ "status":404 }x, 'unknown JSON route retains JSON body');
	});

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;
exit(Server_Dancer2_notFoundTests->new->run);
