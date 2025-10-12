#!/usr/bin/env perl
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

package UtilsSecureStringTests;
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Utils::SecureString;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Readonly;
use Test::Deep qw(all bool cmp_deeply isa methods);
use Test::Exception;
use Test::More 0.96;

sub testDirectlyInstantiate {
	my ($self) = @_;
	plan tests => 1;

	my $value = $self->uniqueStr();
	my $sut = Chleb::Utils::SecureString->new({ value => $value });
	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			stripped => bool(0),
			tainted  => bool(1),
			value    => $value,
		),
	), 'object');

	return EXIT_SUCCESS;
}

sub testUTF8 {
	my ($self) = @_;
	plan tests => 1;

	my $value = $self->uniqueStr();
	my $sut = Chleb::Utils::SecureString->new({ value => '🙏☦️🙌' });

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			stripped => bool(0),
			tainted  => bool(1),
			value    => "\x{1F64F}\x{2626}\x{FE0F}\x{1F64C}",
		),
	), 'object');

	return EXIT_SUCCESS;
}

sub testDetaintPermissiveNormalString {
	my ($self) = @_;
	plan tests => 1;

	my $value = $self->uniqueStr();
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_PERMIT);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			stripped => bool(0),
			tainted  => bool(0),
			value    => $value,
		),
	), 'object');

	return EXIT_SUCCESS;
}

sub testDetaintPermissiveUTF8String {
	my ($self) = @_;
	plan tests => 1;

	my $strippedValue = $self->uniqueStr();
	my $value = '🙏🙌' . $strippedValue . '☦️';
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_PERMIT);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			stripped => bool(1),
			tainted  => bool(0),
			value    => $strippedValue,
		),
	), 'object') or diag(explain($sut->value));

	return EXIT_SUCCESS;
}

sub testDetaintPermissiveUndef {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint(undef, $Chleb::Utils::SecureString::MODE_PERMIT);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = '$value (<undef>) in call to Chleb::Utils::SecureString/detaint, should be a Chleb::Utils::SecureString or scalar (Str)';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => undef,
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testDetaintTrapUndef {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint(undef, $Chleb::Utils::SecureString::MODE_TRAP);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = '$value (<undef>) in call to Chleb::Utils::SecureString/detaint, should be a Chleb::Utils::SecureString or scalar (Str)';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => undef,
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testDetaintPermissiveUnblessed {
	my ($self) = @_;
	plan tests => 2;

	my $value = { };
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_PERMIT);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'Wrong $value ref type (HASH) in call to Chleb::Utils::SecureString/detaint, should be a Chleb::Utils::SecureString or scalar (Str)';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => "$value",
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testDetaintTrapUnblessed {
	my ($self) = @_;
	plan tests => 2;

	my $value = { };
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'Wrong $value ref type (HASH) in call to Chleb::Utils::SecureString/detaint, should be a Chleb::Utils::SecureString or scalar (Str)';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => "$value",
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testDetaintPermissiveWrongbless {
	my ($self) = @_;
	plan tests => 2;

	my $value = $self;
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_PERMIT);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'Wrong $value ref type (UtilsSecureStringTests) in call to Chleb::Utils::SecureString/detaint, should be a Chleb::Utils::SecureString or scalar (Str)';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => "$value",
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testDetaintTrapWrongbless {
	my ($self) = @_;
	plan tests => 2;

	my $value = $self;
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'Wrong $value ref type (UtilsSecureStringTests) in call to Chleb::Utils::SecureString/detaint, should be a Chleb::Utils::SecureString or scalar (Str)';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => "$value",
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(UtilsSecureStringTests->new->run());
