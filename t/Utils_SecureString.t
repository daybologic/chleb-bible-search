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
			coerced  => bool(0),
			stripped => bool(0),
			tainted  => bool(1),
			trimmed  => bool(0),
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
			coerced  => bool(0),
			stripped => bool(0),
			tainted  => bool(1),
			trimmed  => bool(0),
			value    => "\x{1f64f}\x{2626}\x{fe0f}\x{1f64c}",
		),
	), 'object');

	return EXIT_SUCCESS;
}

sub testDefaultModeUTF8String {
	my ($self) = @_;
	plan tests => 2;

	my $strippedValue = 'xy';
	my $value = 'x🙏☦️🙌y';
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = '$value contains illegal character 0x1f64f at position 2 of ' . length($value);
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

sub testDetaintPermissiveNormalString {
	my ($self) = @_;
	plan tests => 1;

	my $value = $self->uniqueStr();
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_PERMIT);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(0),
			stripped => bool(0),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $value,
		),
	), 'object');

	return EXIT_SUCCESS;
}

sub testDetaintTrapNormalString {
	my ($self) = @_;
	plan tests => 1;

	my $value = $self->uniqueStr();
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(0),
			stripped => bool(0),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $value,
		),
	), 'object');

	return EXIT_SUCCESS;
}

sub testDetaintTrapNormalObjectTainted {
	my ($self) = @_;
	plan tests => 2;

	my $inputValue = $self->uniqueStr();
	my $value = Chleb::Utils::SecureString->new({ value => $inputValue });
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(0),
			stripped => bool(0),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $inputValue,
		),
	), 'object');

	isnt($sut, $value, 'tainted object replaced (no shortcut)');

	return EXIT_SUCCESS;
}

sub testDetaintTrapNormalObjectNotTainted {
	my ($self) = @_;
	plan tests => 2;

	my $inputValue = $self->uniqueStr();
	my $value = Chleb::Utils::SecureString->new({ tainted => 0, value => $inputValue });
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(0),
			stripped => bool(0),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $inputValue,
		),
	), 'object');

	is($sut, $value, 'untainted object returned (shortcut)');

	return EXIT_SUCCESS;
}

sub testDetaintPermissiveUTF8StringLow {
	my ($self) = @_;
	plan tests => 1;

	my $strippedValue = $self->uniqueStr();
	my $value = "\a$strippedValue\a";
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_PERMIT);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(0),
			stripped => bool(1),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $strippedValue,
		),
	), 'object') or diag(explain($sut->value));

	return EXIT_SUCCESS;
}

sub testDetaintTrapUTF8StringLow {
	my ($self) = @_;
	plan tests => 2;

	my $strippedValue = $self->uniqueStr();
	my $value = "\a$strippedValue\a";
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = '$value contains illegal character 0x7 at position 1 of ' . length($value);
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

sub testDetaintPermissiveUTF8StringHigh {
	my ($self) = @_;
	plan tests => 1;

	my $strippedValue = $self->uniqueStr();
	my $value = '🙏🙌' . $strippedValue . '☦️';
	my $sut = Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_PERMIT);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(0),
			stripped => bool(1),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $strippedValue,
		),
	), 'object') or diag(explain($sut->value));

	return EXIT_SUCCESS;
}

sub testDetaintTrapUTF8StringHigh {
	my ($self) = @_;
	plan tests => 2;

	my ($strippedValueFirst, $strippedValueSecond) = ('be', 'an');
	my $value = $strippedValueFirst . '🙏🙌' . $strippedValueSecond . '☦️';
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $Chleb::Utils::SecureString::MODE_TRAP);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = '$value contains illegal character 0x1f64f at position 3 of 8';
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

sub testDetaintDefaultModeUndef {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint(undef);
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

sub testIllegalModeUTF8 {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Exception';
	my $mode = 1 << 5;
	my $value = '😲';

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $mode);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'Illegal mode 32 in call to Chleb::Utils::SecureString/detaint';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			location => undef,
			statusCode => 500,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testIllegalModeNormalString {
	my ($self) = @_;
	plan tests => 2;

	my $exceptionType = 'Chleb::Exception';
	my $mode = 1 << 5;
	my $value = $self->uniqueStr();

	throws_ok {
		Chleb::Utils::SecureString::detaint($value, $mode);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = 'Illegal mode 32 in call to Chleb::Utils::SecureString/detaint';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			location => undef,
			statusCode => 500,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testCoerceAndTrim {
	my ($self) = @_;
	plan tests => 1;

	my $coercedValue = "\"Christ Jesus; The Lord\" - as 'he`' is known";
	my $inputValue = "\x{2002}“Christ\x{00a0}Jesus;\x{2003}The\x{2009}Lord”\x{200a} \x{2013} as\x{2008}\x{2018}he`\x{2019}\x{3000}is\x{200b}known\x{feff}";
	my $mode = $Chleb::Utils::SecureString::MODE_COERCE | $Chleb::Utils::SecureString::MODE_TRIM;

	my $sut;
	eval {
		$sut = Chleb::Utils::SecureString::detaint($inputValue, $mode);
	};

	if (my $evalError = $EVAL_ERROR) {
		diag($evalError->toString());
	}

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(1),
			stripped => bool(0),
			tainted  => bool(0),
			trimmed  => bool(1),
			value    => $coercedValue,
		),
	), 'object') or diag(explain($sut->value));

	return EXIT_SUCCESS;
}

sub testCoercePermitAndTrim {
	my ($self) = @_;
	plan tests => 1;

	my $coercedValue = "\"Christ Jesus; The Lord\" - as 'he`' is known";
	my $inputValue = "\x{2002}“Christ\x{00a0}Jesus;\x{2003}The\x{2009}Lord”\x{200a} \x{2013} as\x{2008}\x{2018}he`\x{2019}\x{3000}is\x{200b}known\x{feff}\x{2020}";
	my $mode = $Chleb::Utils::SecureString::MODE_COERCE | $Chleb::Utils::SecureString::MODE_PERMIT | $Chleb::Utils::SecureString::MODE_TRIM;

	my $sut;
	eval {
		$sut = Chleb::Utils::SecureString::detaint($inputValue, $mode);
	};

	if (my $evalError = $EVAL_ERROR) {
		diag($evalError->toString());
	}

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(1),
			stripped => bool(1),
			tainted  => bool(0),
			trimmed  => bool(1),
			value    => $coercedValue,
		),
	), 'object') or diag(explain($sut->value));

	return EXIT_SUCCESS;
}

sub testCoerceAndPermit {
	my ($self) = @_;
	plan tests => 1;

	my $coercedValue = " \"Christ Jesus; The Lord\"  - as 'he`' is known ";
	my $inputValue = "\x{2002}“Christ\x{00a0}Jesus;\x{2003}The\x{2009}Lord”\x{200a} \x{2013} as\x{2008}\x{2018}he`\x{2019}\x{3000}is\x{200b}known\x{feff}\x{2020}";
	my $mode = $Chleb::Utils::SecureString::MODE_COERCE | $Chleb::Utils::SecureString::MODE_PERMIT;

	my $sut;
	eval {
		$sut = Chleb::Utils::SecureString::detaint($inputValue, $mode);
	};

	if (my $evalError = $EVAL_ERROR) {
		diag($evalError->toString());
	}

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(1),
			stripped => bool(1),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $coercedValue,
		),
	), 'object') or diag(explain($sut->value));

	return EXIT_SUCCESS;
}

sub testCoerce {
	my ($self) = @_;
	plan tests => 2;

	my $coercedValue = " \"Christ Jesus; The Lord\"  - as 'he`' is known ";
	my $inputValue = "\x{2002}“Christ\x{00a0}Jesus;\x{2003}The\x{2009}Lord”\x{200a} \x{2013} as\x{2008}\x{2018}he`\x{2019}\x{3000}is\x{200b}known\x{feff}\x{2020}";
	my $exceptionType = 'Chleb::Utils::TypeParserException';

	throws_ok {
		Chleb::Utils::SecureString::detaint($inputValue, $Chleb::Utils::SecureString::MODE_COERCE);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $description = '$value contains illegal character 0x2020 at position 48 of 48';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => "\x{2002}“Christ\x{00a0}Jesus;\x{2003}The\x{2009}Lord”\x{200a} \x{2013} as\x{2008}\x{2018}he`\x{2019}\x{3000}is\x{200b}known\x{feff}\x{2020}",
			location => undef,
			statusCode => 400,
		),
	), $description);

	return EXIT_SUCCESS;
}

sub testExceedMaximumLength {
	my ($self) = @_;
	plan tests => 5;

	my @chars = map { $self->uniqueStr() } 1..4096;
	my $inputValue = join('', @chars);
	my $exceptionType = 'Chleb::Utils::TypeParserException';
	my $name = 'Abraham';

	throws_ok {
		Chleb::Utils::SecureString::detaint($inputValue, $Chleb::Utils::SecureString::MODE_TRAP, $name);
	} $exceptionType, $exceptionType;
	my $evalError = $EVAL_ERROR; # save ASAP

	my $length = length($inputValue);
	my $description = "$name exceeds maximum length ($length/4096)";
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => $length,
			location => undef,
			statusCode => 400,
		),
	), $description);

	$name = undef;
	$inputValue = substr($inputValue, 0, 4097);

	throws_ok {
		Chleb::Utils::SecureString::detaint($inputValue, $Chleb::Utils::SecureString::MODE_TRAP, $name);
	} $exceptionType, $exceptionType;
	$evalError = $EVAL_ERROR; # save ASAP

	$length = length($inputValue);
	$description = '$value exceeds maximum length (4097/4096)';
	cmp_deeply($evalError, all(
		isa($exceptionType),
		methods(
			description => $description,
			name => $length,
			location => undef,
			statusCode => 400,
		),
	), $description);

	$inputValue = substr($inputValue, 0, 4096);
	my $sut = Chleb::Utils::SecureString::detaint($inputValue, $Chleb::Utils::SecureString::MODE_TRAP, $name);

	cmp_deeply($sut, all(
		isa('Chleb::Utils::SecureString'),
		methods(
			coerced  => bool(0),
			stripped => bool(0),
			tainted  => bool(0),
			trimmed  => bool(0),
			value    => $inputValue,
		),
	), 'object from 4096 length string') or diag(explain($sut->value));

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(UtilsSecureStringTests->new->run());
