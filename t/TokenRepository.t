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

package TokenRepositoryTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::DI::MockLogger;
use Chleb::Exception;
use Chleb::Token::Repository;
use English qw(-no_match_vars);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use POSIX qw(EXIT_SUCCESS);
use Test::Deep qw(all cmp_deeply isa methods re);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Chleb::Token::Repository->new());
	$self->sut->dic->logger(Chleb::DI::MockLogger->new());

	return EXIT_SUCCESS;
}

sub testRedisLoadFailureRaisesChlebException {
	my ($self) = @_;
	plan tests => 1;

	local @INC = (sub {
		my ($self, $filename) = @_;
		die "simulated Redis repository load failure\n"
		    if ($filename eq 'Chleb/Token/Repository/Redis.pm');
		return;
	}, @INC);
	local $INC{'Chleb/Token/Repository/Redis.pm'};
	delete $INC{'Chleb/Token/Repository/Redis.pm'};

	eval {
		$self->sut->repo('Redis');
	};

	cmp_deeply($EVAL_ERROR, all(
		isa('Chleb::Exception'),
		methods(
			description => re(qr/^Failed to load Redis: /),
			location    => undef,
			statusCode  => 500,
		),
	), 'Redis repository load failure is raised as Chleb::Exception');

	return EXIT_SUCCESS;
}

sub testRedisUnavailableWithoutClientModule {
	my ($self) = @_;
	plan tests => 1;

	local @INC = (sub {
		my ($self, $filename) = @_;
		die "simulated Redis client load failure\n"
		    if ($filename eq 'Redis/Fast.pm' || $filename eq 'Redis.pm');
		return;
	}, @INC);
	local @INC{qw(Chleb/Token/Repository/Redis.pm Redis/Fast.pm Redis.pm)};
	delete @INC{qw(Chleb/Token/Repository/Redis.pm Redis/Fast.pm Redis.pm)};

	my $evalError;
	{
		no strict qw(refs);
		local ${'Chleb::Token::Repository::Redis::REDIS_CLASS'};

		my $repo = $self->sut->repo('Redis');
		eval {
			$repo->do;
		};
		$evalError = $EVAL_ERROR;
	}

	cmp_deeply($evalError, all(
		isa('Chleb::Exception'),
		methods(
			description => 'Redis backend is unavailable: neither Redis nor Redis::Fast is installed',
			location    => undef,
			statusCode  => 500,
		),
	), 'missing Redis client module is raised as Chleb::Exception');

	return EXIT_SUCCESS;
}

sub testRedisFastPreferredWhenAvailable {
	my ($self) = @_;
	plan tests => 1;

	my $dir = tempdir(CLEANUP => 1);
	make_path("$dir/Redis");
	__writeFile("$dir/Redis/Fast.pm", "package Redis::Fast;\n1;\n");
	__writeFile("$dir/Redis.pm", "package Redis;\ndie 'plain Redis should not be loaded when Redis::Fast is available';\n");

	my $script = 'exit(($Chleb::Token::Repository::Redis::REDIS_CLASS // q{}) eq q{Redis::Fast} ? 0 : 1)';
	my $exitStatus = system($EXECUTABLE_NAME, '-I', $dir, '-I', 'lib', '-MChleb::Token::Repository::Redis', '-e', $script);
	is($exitStatus, 0, 'Redis::Fast is preferred over Redis');

	return EXIT_SUCCESS;
}

sub __writeFile {
	my ($path, $content) = @_;

	open(my $fh, '>', $path) or die("open $path: $!");
	print {$fh} $content;
	close($fh) or die("close $path: $!");

	return;
}

package main;
use strict;
use warnings;
exit(TokenRepositoryTests->new->run);
