#!/usr/bin/perl
package TokenTests;
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
use Chleb::Token::Repository::Dummy;
use Test::Deep qw(cmp_deeply all isa methods bool re shallow);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Chleb::Token::Repository->new());
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub testRequired {
	my ($self) = @_;
	plan tests => 3;

	throws_ok {
		Chleb::Token->new({ _repo => $self->sut });
	} qr/source is required/, 'source is required';

	throws_ok {
		Chleb::Token->new({ _source => $self->sut->repo('TempDir') });
	} qr/repo is required/, 'repo is required';

	lives_ok {
		Chleb::Token->new({ _repo => $self->sut, _source => $self->sut->repo('TempDir') });
	} 'object created';

	return EXIT_SUCCESS;
}

sub testInitWithValue {
	my ($self) = @_;
	plan tests => 4;

	my $value = $self->uniqueStr();
	$self->sut(Chleb::Token->new({
		_repo => $self->sut,
		_source => $self->sut->repo('TempDir'),
		_value => $value,
	}));

	is($self->sut->value, $value, 'value is set correctly');

	$self->__readOnlyValueCheck($value);
	$self->__readOnlyValueCheck($self->uniqueStr());

	is($self->sut->value, $value, 'value is still set correctly');

	return EXIT_SUCCESS;
}

sub testInitWithoutValue {
	my ($self) = @_;
	plan tests => 4;

	$self->sut(Chleb::Token->new({
		_repo => $self->sut,
		_source => $self->sut->repo('TempDir'),
	}));

	my $value = $self->sut->value;
	isnt($value, undef, 'value is not undef') or BAIL_OUT('Critical test failure -- Cannot continue');

	$self->__readOnlyValueCheck($self->uniqueStr());

	is($self->sut->value, $value, 'value is the same upon second reading');

	is(length($self->sut->value), 64, 'value length is 64 (256-bit)');

	$self->debug(sprintf("The value is '%s'", $value));

	return EXIT_SUCCESS;
}

sub testSave {
	my ($self) = @_;
	plan tests => 1;

	my ($mockPackage, $mockMethod) = ('Chleb::Token::Repository::Dummy', 'save');
	$self->mock($mockPackage, $mockMethod);

	$self->sut(Chleb::Token->new({
		_repo => $self->sut,
		_source => $self->sut->repo('Dummy'),
	}));

	$self->sut->save();

	my $mockCalls = $self->mockCalls($mockPackage, $mockMethod);
	cmp_deeply($mockCalls, [[shallow($self->sut)]], sprintf('one call to %s/%s', $mockPackage, $mockMethod)) or diag(explain($mockCalls));

	return EXIT_SUCCESS;
}

sub __readOnlyValueCheck {
	my ($self, $value) = @_;

	throws_ok {
		$self->sut->value($value);
	} qr/read-only/, 'value cannot be written';

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
exit(TokenTests->new->run);
