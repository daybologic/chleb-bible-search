#!/usr/bin/perl
package BaseTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses::Base;
use Test::Deep qw(cmp_deeply all isa methods bool re);
use Test::Exception;
use Test::More;

sub setUp {
	my ($self) = @_;

	$self->sut(Religion::Bible::Verses::Base->new());

	return EXIT_SUCCESS;
}

sub testDateString {
	my ($self) = @_;
	plan tests => 1;

	my $str = '1810-09-14T12:00:00+0000';
	cmp_deeply(
		$self->sut->__resolveISO8601($str),
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
		$self->sut->__resolveISO8601($object),
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
		$self->sut->__resolveISO8601(undef),
		all(
			isa('DateTime'),
		),
	'object');

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;
exit(BaseTests->new->run);