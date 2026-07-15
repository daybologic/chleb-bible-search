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

package TokenRepository_JWTTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::DI::Config;
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Token::Repository;
use Chleb::Token::Repository::JWT;
use Digest::SHA qw(hmac_sha256);
use English qw(-no_match_vars);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use JSON::PP;
use MIME::Base64 qw(decode_base64url encode_base64url);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods num);
use Test::More 0.96;

has dic => (is => 'rw', isa => 'Chleb::DI::Container');

sub setUp {
	my ($self) = @_;

	my $dir = tempdir(CLEANUP => 1);
	make_path($dir);
	open(my $fh, '>', "$dir/main.yaml") or die("open $dir/main.yaml: $!");
	print {$fh} <<'EOF';
session_tokens:
  backend_jwt:
    secret: unit-test-secret
  ttl: 1800
EOF
	close($fh) or die("close $dir/main.yaml: $!");

	$self->dic(Chleb::DI::Container->instance);
	$self->dic->config(Chleb::DI::Config->new({ dic => $self->dic, path => $dir }));
	$self->dic->logger(Chleb::DI::MockLogger->new());
	$self->dic->time->set(2_000_000_000);
	$self->sut(Chleb::Token::Repository::JWT->new({ dic => $self->dic }));

	return EXIT_SUCCESS;
}

sub testRepositoryFactory {
	my ($self) = @_;
	plan tests => 1;

	cmp_deeply($self->sut->repo->repo('JWT'), isa('Chleb::Token::Repository::JWT'), 'JWT backend is registered');

	return EXIT_SUCCESS;
}

sub testSaveLoad {
	my ($self) = @_;
	plan tests => 11;

	my $now = $self->dic->time->get();
	my $token = $self->sut->create();
	$token->ipAddress('127.0.0.1');
	$token->userAgent('Unit Test');
	my $firstValue = $token->value;

	$self->sut->save($token);

	like($firstValue, qr/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/, 'created value is a JWT');
	like($token->value, qr/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/, 'saved value is a JWT');
	isnt($token->value, $firstValue, 'save re-signs changed token data');
	cmp_ok(length($token->value), '<', 700, 'JWT does not recursively embed previous values');

	my (undef, $encodedPayload) = split(m/\./, $token->value, 3);
	my $payload = JSON::PP->new->decode(decode_base64url($encodedPayload));
	cmp_deeply($payload->{iat}, num($now, 1), 'JWT contains issued-at claim');
	cmp_deeply($payload->{exp}, num($now + 1800, 1), 'JWT contains expiration claim');
	ok(!exists($payload->{created}), 'JWT omits private created claim');
	ok(!exists($payload->{expires}), 'JWT omits private expires claim');
	ok(!exists($payload->{userAgent}), 'JWT omits user agent');

	my $loaded = $self->sut->load($token->value);
	cmp_deeply($loaded, all(
		isa('Chleb::Token'),
		methods(
			created => num($now, 1),
			expires => num($now + 1800, 1),
			ipAddress => '127.0.0.1',
			repo => isa('Chleb::Token::Repository'),
			source => isa('Chleb::Token::Repository::JWT'),
			userAgent => '',
			value => $token->value,
		),
	), 'token loaded from JWT');

	ok(!$loaded->dirty, 'loaded token is clean');

	return EXIT_SUCCESS;
}

sub testLoadTampered {
	my ($self) = @_;
	plan tests => 1;

	my $token = $self->sut->create();
	my $value = $token->value;
	substr($value, -1, 1) = substr($value, -1, 1) eq 'a' ? 'b' : 'a';

	eval {
		$self->sut->load($value);
	};

	cmp_deeply($EVAL_ERROR, all(
		isa('Chleb::Exception'),
		methods(
			description => 'sessionToken unrecognized via Chleb::Token::Repository::JWT',
			location    => undef,
			statusCode  => 401,
		),
	), 'tampered JWT is rejected');

	return EXIT_SUCCESS;
}

sub testLoadExpired {
	my ($self) = @_;
	plan tests => 1;

	my $token = $self->sut->create();
	$token->expires($self->dic->time->get() - 1);
	$self->sut->save($token);

	eval {
		$self->sut->load($token->value);
	};

	cmp_deeply($EVAL_ERROR, all(
		isa('Chleb::Exception'),
		methods(
			description => 'sessionToken expired via Chleb::Token::Repository::JWT',
			location    => undef,
			statusCode  => 401,
		),
	), 'expired JWT is rejected');

	return EXIT_SUCCESS;
}

sub testLoadInvalidFormat {
	my ($self) = @_;
	plan tests => 1;

	eval {
		$self->sut->load($self->uniqueStr());
	};

	cmp_deeply($EVAL_ERROR, all(
		isa('Chleb::Exception'),
		methods(
			description => 'The sessionToken format must be JWT',
			location    => undef,
			statusCode  => 401,
		),
	), 'non-JWT value is rejected');

	return EXIT_SUCCESS;
}

sub testLoadLegacyClaims {
	my ($self) = @_;
	plan tests => 1;

	my $token = $self->sut->create();
	my (undef, $encodedPayload) = split(m/\./, $token->value, 3);
	my $payload = JSON::PP->new->decode(decode_base64url($encodedPayload));
	$payload->{created} = delete($payload->{iat});
	$payload->{expires} = delete($payload->{exp});

	eval {
		$self->sut->load(__makeJWT($payload));
	};

	cmp_deeply($EVAL_ERROR, all(
		isa('Chleb::Exception'),
		methods(
			description => 'sessionToken unrecognized via Chleb::Token::Repository::JWT',
			location    => undef,
			statusCode  => 401,
		),
	), 'legacy time claims are rejected');

	return EXIT_SUCCESS;
}

sub __makeJWT {
	my ($payload) = @_;

	my $json = JSON::PP->new->canonical->utf8;
	my $signingInput = join('.', map {
		my $encoded = encode_base64url($json->encode($_));
		$encoded =~ s/=+\z//;
		$encoded;
	} ({
		alg => 'HS256',
		typ => 'JWT',
	}, $payload));

	my $signature = encode_base64url(hmac_sha256($signingInput, 'unit-test-secret'));
	$signature =~ s/=+\z//;
	return join('.', $signingInput, $signature);
}

package main;
use strict;
use warnings;
exit(TokenRepository_JWTTests->new->run);
