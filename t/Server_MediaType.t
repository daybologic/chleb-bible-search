#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package ServerMediaTypeTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb;
use Chleb::DI::MockLogger;
use Chleb::Server::MediaType;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	#$self->sut(Chleb->new());

	return EXIT_SUCCESS;
}

sub testAny {
	my ($self) = @_;
	plan tests => 3;

	my $check = sub {
		my ($input) = @_;

		my $printable = defined($input) ? "'$input'" : '<undef>';
		my $mediaType = Chleb::Server::MediaType->parseAcceptHeader($input);
		cmp_deeply($mediaType, all(
			isa('Chleb::Server::MediaType'),
			methods(
				major => '*',
				minor => '*',
			),
		), "type inspection ${printable} is */*") or diag(explain($mediaType->toString()));
	};

	$check->(undef);
	$check->('');
	$check->('*/*');

	return EXIT_SUCCESS;
}

sub testAnyText {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/*');
	cmp_deeply($mediaType, all(
		isa('Chleb::Server::MediaType'),
		methods(
			major => 'text',
			minor => '*',
		),
	), 'type inspection is text/*') or diag(explain($mediaType->toString()));

	return EXIT_SUCCESS;
}

sub testTooShort {
	my ($self) = @_;
	plan tests => 10;

	my $check = sub {
		my ($input) = @_;

		eval {
			Chleb::Server::MediaType->parseAcceptHeader($input);
		};

		if (my $evalError = $EVAL_ERROR) {
			my $description = 'Accept: header too short';
			cmp_deeply($evalError, all(
				isa('Chleb::Exception'),
				methods(
					description => $description,
					location    => undef,
					statusCode  => 406,
				),
			), "'${input}': ${description}");
		} else {
			fail('No exception raised, as was expected');
		}
	};

	foreach my $char (qw(a/ /a a 0 / // */ /*)) {
		$check->($char);
	}

	$check->(' ');
	$check->('  ');

	return EXIT_SUCCESS;
}

sub testIncomplete {
	my ($self) = @_;
	plan tests => 10;

	my $check = sub {
		my ($input) = @_;

		eval {
			Chleb::Server::MediaType->parseAcceptHeader($input);
		};

		if (my $evalError = $EVAL_ERROR) {
			my $description = 'Accept: incomplete spec';
			cmp_deeply($evalError, all(
				isa('Chleb::Exception'),
				methods(
					description => $description,
					location    => undef,
					statusCode  => 406,
				),
			), "'${input}': ${description}");
		} else {
			fail("'${input}': No exception raised, as was expected");
		}
	};

	$check->('   ');
	$check->('///');
	$check->('/ /');
	$check->(' / ');
	$check->('part/');
	$check->('/part');
	$check->('/part/');
	$check->('//part');
	$check->('part//');
	$check->('part');

	return EXIT_SUCCESS;
}

sub testIllegal {
	my ($self) = @_;
	plan tests => 2;

	my $check = sub {
		my ($input) = @_;

		eval {
			Chleb::Server::MediaType->parseAcceptHeader($input);
		};

		if (my $evalError = $EVAL_ERROR) {
			my $description = 'Accept: wildcard misused';
			cmp_deeply($evalError, all(
				isa('Chleb::Exception'),
				methods(
					description => $description,
					location    => undef,
					statusCode  => 406,
				),
			), "'${input}': ${description}");
		} else {
			fail('No exception raised, as was expected');
		}
	};

	$check->('*/json');
	$check->('*/text');

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;

exit(ServerMediaTypeTests->new->run());