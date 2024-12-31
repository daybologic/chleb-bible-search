#!/usr/bin/perl
package TokenRepository_TempDirTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Chleb::DI::MockLogger;
use Chleb::Token;
use Chleb::Token::Repository;
use Chleb::Token::Repository::TempDir;
use Test::Deep qw(cmp_deeply all isa methods bool re);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Chleb::Token::Repository::TempDir->new());
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
					isa('Chleb::Token::Repository::TempDir'),
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
					description => 'sessionToken expired via Chleb::Token::Repository::TempDir',
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
		$token = $self->sut->load($self->uniqueStr());
	};

	if (my $evalError = $EVAL_ERROR) {
		cmp_deeply($evalError, all(
			isa('Chleb::Exception'),
			methods(
				description => 'sessionToken unrecognized via Chleb::Token::Repository::TempDir',
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
exit(TokenRepository_TempDirTests->new->run);
