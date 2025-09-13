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

package TokenRepository_LocalTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Token;
use Chleb::Token::Repository;
use Chleb::Token::Repository::Local;
use Test::Deep qw(cmp_deeply all isa methods bool re);
use Test::Exception;
use Test::More 0.96;

has dic => (is => 'rw', isa => 'Chleb::DI::Container');

sub setUp {
	my ($self) = @_;

	$self->dic(Chleb::DI::Container->instance);
	$self->dic->configPaths(['etc-local']);
	$self->sut(Chleb::Token::Repository::Local->new({ dic => $self->dic }));
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub testSaveLoad {
	my ($self) = @_;
	plan tests => 3;

	my $value;
	my $now = time();
	$self->debug("now is $now");

	subtest save => sub {
		plan tests => 6;

		my $token;
		lives_ok {
			$token = $self->sut->create({ now => $now });
		} 'create called';

		cmp_ok($token->expires, '==', $now + 604_800, 'default expiry in one week');
		cmp_ok($token->expires($now + 5), '==', $now + 5, 'set expiry time five seconds from now');
		cmp_ok($token->created, '==', $now, "created is now (setting expires doesn't change that)");

		lives_ok {
			$token->save();
		} 'save called on token';
		if (my $evalError = $EVAL_ERROR) {
			BAIL_OUT($evalError->toString());
		}

		$value = $token->value;
		ok($value, 'value retrieved');
	};

	subtest load => sub {
		plan tests => 2;

		my $token;
		lives_ok {
			$token = $self->sut->load($value);
		} 'load called';

		cmp_deeply($token, all(
			isa('Chleb::Token'),
			methods(
				created => $now, # original time from file, not object reconstruction
				expires => $now + 5,
				repo => isa('Chleb::Token::Repository'),
				source => all(
					isa('Chleb::Token::Repository::Local'),
				),
				value => $value,
			),
		), 'token');
	};

	$self->debug('sleeping until token expires (5s)');
	sleep(5);

	subtest expired => sub {
		plan tests => 2;

		my $token;
		eval {
			$self->sut->load($value);
		};

		if (my $evalError = $EVAL_ERROR) {
			cmp_deeply($evalError, all(
				isa('Chleb::Exception'),
				methods(
					description => 'sessionToken expired via Chleb::Token::Repository::Local',
					location    => undef,
					statusCode  => 401,
				),
			), '403 Unauthorized');
		} else {
			fail('No exception raised, as was expected');
		}

		ok(!$token, 'token not set');
	};

	return EXIT_SUCCESS;
}

sub testLoadNotFound {
	my ($self) = @_;
	plan tests => 2;

	my $token;
	eval {
		$token = $self->sut->load('a6b2934af53fbfa4c42266765075c4fd7b602345089a5aa825c9117847535aa6');
	};

	my $evalError = $EVAL_ERROR;
	ok(!$evalError, 'no exception thrown');

	ok(!$token, 'token not set');

	return EXIT_SUCCESS;
}

sub testLoadNotInvalidHash {
	my ($self) = @_;
	plan tests => 2;

	my $token;
	eval {
		$token = $self->sut->load($self->uniqueStr());
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => 'The sessionToken format must be SHA-256',
				location    => undef,
				statusCode  => 401,
			),
		), '401 Unauthorized');
	} else {
		fail('No exception raised, as was expected');
	}

	ok(!$token, 'token not set');

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;
exit(TokenRepository_LocalTests->new->run);
