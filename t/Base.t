#!/usr/bin/perl
package BaseTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use English qw(-no_match_vars);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::Bible::Base;
use Chleb::DI::MockLogger;
use Test::Deep qw(cmp_deeply all isa methods bool re);
use Test::Exception;
use Test::More;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Bible::Base->new());

	return EXIT_SUCCESS;
}

sub testDateString {
	my ($self) = @_;
	plan tests => 1;

	my $str = '1810-09-14T12:00:00+0000';
	cmp_deeply(
		$self->sut->_resolveISO8601($str),
		all(
			isa('DateTime'),
			methods(
				year  => 1810,
				month => 9,
				day   => 14,
			),
		),
	$str);

	return EXIT_SUCCESS;
}

sub testDateObject {
	my ($self) = @_;
	plan tests => 1;

	my $object = DateTime->new(year => 2011, month => 3, day => 5);
	cmp_deeply(
		$self->sut->_resolveISO8601($object),
		all(
			isa('DateTime'),
			methods(
				year  => 2011,
				month => 3,
				day   => 5,
			),
		),
	'object');

	return EXIT_SUCCESS;
}

sub testDefault {
	my ($self) = @_;
	plan tests => 1;

	cmp_deeply(
		$self->sut->_resolveISO8601(undef),
		all(
			isa('DateTime'),
		),
	'object');

	return EXIT_SUCCESS;
}

sub testMangledPlus {
	my ($self) = @_;
	plan tests => 1;

	my $str = '1810-09-14T12:00:00 0000';
	cmp_deeply(
		$self->sut->_resolveISO8601($str),
		all(
			isa('DateTime'),
			methods(
				year  => 1810,
				month => 9,
				day   => 14,
			),
		),
	$str);

	return EXIT_SUCCESS;
}

sub testCmpAddress {
	my ($self) = @_;
	plan tests => 4;

	$self->__checkCmpAddressBadArgCount();
	$self->__checkCmpAddressMismatch();
	$self->__checkCmpAddressMismatchNull();
	$self->__checkCmpAddressMatch();

	return EXIT_SUCCESS;
}

sub __checkCmpAddressBadArgCount {
	my ($self) = @_;

	my $this = (split(m/::/, (caller(0))[3]))[1];
	subtest $this => sub {
		my $c = 10;
		plan tests => $c;

		for (my $argCount = 0; $argCount <= $c; $argCount++) {
			if ($argCount == 2) {
				$self->debug("skipped argument count $argCount because this is permitted and expected");
				next;
			}

			my @args = ( );
			push(@args, (($self->uniqueStr()) x $argCount));
			throws_ok {
				$self->sut->_cmpAddress(@args)
			} qr/Must pass two objects to _cmpAddress, expected 2, received $argCount /, "expected $argCount arguments";
		}
	};

	return;
}

sub __checkCmpAddressMismatch {
	my ($self) = @_;

	my $this = (split(m/::/, (caller(0))[3]))[1];
	subtest $this => sub {
		plan tests => 2;

		ok(!$self->sut->_cmpAddress($self, $self->sut), 'object address mismatch');
		$self->sut->dic->logger->isLogged(qr/mismatch/);
	};

	return;
}

sub __checkCmpAddressMismatchNull {
	my ($self) = @_;

	my $this = (split(m/::/, (caller(0))[3]))[1];
	subtest $this => sub {
		plan tests => 2;

		ok(!$self->sut->_cmpAddress(undef, $self->sut), 'object address mismatch NULL A');
		ok(!$self->sut->_cmpAddress($self->sut, undef), 'object address mismatch NULL B');
	};

	return;
}

sub __checkCmpAddressMatch {
	my ($self) = @_;

	my $this = (split(m/::/, (caller(0))[3]))[1];
	subtest $this => sub {
		plan tests => 2;

		ok($self->sut->_cmpAddress($self->sut, $self->sut), 'object address match');
		$self->sut->dic->logger->isLogged(qr/MATCH/);
	};

	return;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;
exit(BaseTests->new->run);
