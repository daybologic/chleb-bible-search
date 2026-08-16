#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Server_openapiTests;
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
use strict;
use warnings;
use Moose;

use lib 't/lib';
use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Chleb::Server::Dancer2;
use HTTP::Request::Common qw(GET);
use Plack::Test;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testPublishedOpenapiDocuments {
	my ($self) = @_;
	plan tests => 19;

	my $app = Chleb::Server::Dancer2->to_app();
	test_psgi($app, sub {
		my ($callback) = @_;

		my $yaml = $callback->(GET('/openapi.yaml'));
		is($yaml->code(), 200, 'published OpenAPI YAML is available');
		like($yaml->header('Content-Type'), qr{ \Aapplication/yaml }x,
			'published YAML has a YAML content type');
		like($yaml->decoded_content(), qr{ \nopenapi:[ ]3\.0\.0 \n}x,
			'published YAML is the OpenAPI document');

		my $json = $callback->(GET('/openapi.json'));
		is($json->code(), 200, 'published OpenAPI JSON is available');
		like($json->header('Content-Type'), qr{ \Aapplication/json }x,
			'published JSON has an application/json content type');
		like($json->decoded_content(), qr{ \A\{ }x,
			'published JSON is an object');
		like($json->decoded_content(), qr{ "openapi"\s*:\s*"3\.0\.0" }x,
			'published JSON contains the OpenAPI version');

		my $html = $callback->(GET('/docs.html'));
		is($html->code(), 200, 'HTML documentation is available');
		like($html->header('Content-Type'), qr{ \Atext/html }x,
			'HTML documentation has an HTML content type');
		like($html->decoded_content(), qr{ SwaggerUIBundle }x,
			'HTML documentation loads Swagger UI');

		my $docsYaml = $callback->(GET('/docs', Accept => 'application/yaml'));
		is($docsYaml->code(), 200, '/docs negotiates YAML');
		is($docsYaml->header('Content-Type'), 'application/yaml; charset=utf-8',
			'/docs YAML response has the YAML content type');
		like($docsYaml->decoded_content(), qr{ \nopenapi:[ ]3\.0\.0 \n}x,
			'/docs YAML response contains the OpenAPI document');

		my $docsJson = $callback->(GET('/docs', Accept => 'application/json'));
		is($docsJson->code(), 200, '/docs negotiates JSON');
		is($docsJson->header('Content-Type'), 'application/json',
			'/docs JSON response has the JSON content type');
		like($docsJson->decoded_content(), qr{ "openapi"\s*:\s*"3\.0\.0" }x,
			'/docs JSON response contains the OpenAPI document');

		my $docsHtml = $callback->(GET('/docs', Accept => 'text/html'));
		is($docsHtml->code(), 200, '/docs negotiates HTML');
		like($docsHtml->header('Content-Type'), qr{ \Atext/html }x,
			'/docs HTML response has the HTML content type');
		like($docsHtml->decoded_content(), qr{ SwaggerUIBundle }x,
			'/docs HTML response loads Swagger UI');
	});

	return EXIT_SUCCESS;
}

1;

package main;
use strict;
use warnings;

exit(Server_openapiTests->new->run);
