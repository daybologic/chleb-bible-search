#!/usr/bin/env perl
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

package ConfigGetTests;
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use Carp qw(croak);
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Config;
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use English qw(-no_match_vars);
use File::Temp qw(tempdir);
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	my $dir = tempdir(CLEANUP => 1);
	__writeConfigFile("$dir/main.yaml", <<'YAML');
simple_boolean:
  off_value: off
  on_value: on
  true_value: true
  false_value: false
Dancer2:
  public_dir: data/static/public
session_tokens:
  backend_redis:
    db: 5
    host: redis-82.example.net
YAML
	$self->sut(Chleb::DI::Config->new({ path => $dir }));

	return EXIT_SUCCESS;
}

sub testGetSimpleString {
	my ($self) = @_;
	plan tests => 2;

	my $sectionName = 'Dancer2';
	my $default = $self->uniqueStr();
	my $expect = 'data/static/public';

	is($self->sut->get($sectionName, 'public_dir', $default, 0), $expect, 'key present');
	is($self->sut->get($sectionName, 'public_dir_1', $default, 0), $default, 'key *NOT* present');

	return EXIT_SUCCESS;
}

sub testGetSimpleBoolean {
	my ($self) = @_;
	plan tests => 5;

	my $sectionName = 'simple_boolean';
	my $default = 1;

	ok(!$self->sut->get($sectionName, 'off_value', $default, 1), 'key present; off');
	ok($self->sut->get($sectionName, 'on_value', $default, 1), 'key present; on');
	ok($self->sut->get($sectionName, 'missing_value', $default, 1), 'key *NOT* present; default');
	ok(!$self->sut->get($sectionName, 'false_value', $default, 1), 'key present; false');
	ok($self->sut->get($sectionName, 'true_value', $default, 1), 'key present; true');

	return EXIT_SUCCESS;
}

sub testSubsectionHash {
	my ($self) = @_;
	plan tests => 2;

	my $sectionName = 'session_tokens';
	my $subsectionName = 'backend_redis';

	my $subsection = $self->sut->get($sectionName, $subsectionName, { db => 2, host => 'x' });
	cmp_deeply($subsection, {
		db => 5,
		host => 'redis-82.example.net',
	}, 'defaults not used') or diag(explain($subsection));

	$subsection = $self->sut->get($sectionName, $subsectionName, { db => 2 });
	cmp_deeply($subsection, {
		db => 5,
		host => 'redis-82.example.net',
	}, "defaults not used; default keys don't affect keys returned") or diag(explain($subsection));

	return EXIT_SUCCESS;
}

sub testSubsectionHash_default {
	my ($self) = @_;
	plan tests => 1;

	my $sectionName = 'session_tokens';
	my $subsectionName = 'backend_redis';
	my $default = $self->uniqueStr();

	my $subsection = $self->sut->get($sectionName, $subsectionName, { host => 'x', nonExist => $default });
	cmp_deeply($subsection, {
		db => 5,
		host => 'redis-82.example.net',
		nonExist => $default,
	}, 'key not set - returning default within subsection') or diag(explain($subsection));

	return EXIT_SUCCESS;
}

sub testSplitConfigFiles {
	my ($self) = @_;
	plan tests => 6;

	my $dir = tempdir(CLEANUP => 1);
	__writeConfigFile("$dir/main.yaml", <<'YAML');
server:
  children: 3
  domain: main.example.org
session_tokens:
  backend_jwt:
    secret: from-main
  ttl: 10
features:
  sessions: on
YAML
	__writeConfigFile("$dir/contact.yaml", <<'YAML');
server:
  admin_name: Split Admin
  domain: contact.example.org
YAML
	__writeConfigFile("$dir/features.yaml", <<'YAML');
features:
  sessions: off
YAML
	__writeConfigFile("$dir/tokens.yaml", <<'YAML');
session_tokens:
  backend_jwt:
    issuer: split-tests
  ttl: 20
YAML

	my $config = Chleb::DI::Config->new({ path => $dir });

	is($config->get('server', 'children', 1), 3, 'main.yaml supplies general settings');
	is($config->get('server', 'admin_name', 'Unknown'), 'Split Admin', 'contact.yaml supplies contact settings');
	is($config->get('server', 'domain', 'default.example.org'), 'contact.example.org', 'later split files override earlier files');
	ok(!$config->get('features', 'sessions', 1, 1), 'features.yaml supplies feature flags');
	is($config->get('session_tokens', 'ttl', 1), 20, 'tokens.yaml supplies token settings');
	cmp_deeply(
		$config->get('session_tokens', 'backend_jwt', { secret => undef, issuer => undef }),
		{
			secret => 'from-main',
			issuer => 'split-tests',
		},
		'nested hashes are recursively merged',
	);

	return EXIT_SUCCESS;
}

sub testMainOnlyConfigFile {
	my ($self) = @_;
	plan tests => 1;

	my $dir = tempdir(CLEANUP => 1);
	__writeConfigFile("$dir/main.yaml", <<'YAML');
server:
  domain: single.example.org
YAML

	my $config = Chleb::DI::Config->new({ path => $dir });

	is($config->get('server', 'domain', 'default.example.org'), 'single.example.org', 'main.yaml works without split siblings');

	return EXIT_SUCCESS;
}

sub testPathMustBeDirectory {
	my ($self) = @_;
	plan tests => 1;

	my $dir = tempdir(CLEANUP => 1);
	__writeConfigFile("$dir/main.yaml", <<'YAML');
server:
  domain: file.example.org
YAML

	throws_ok {
		Chleb::DI::Config->new({ path => "$dir/main.yaml" });
	} qr/Config path is not a directory/, 'path rejects main.yaml filename';

	return EXIT_SUCCESS;
}

sub __writeConfigFile {
	my ($path, $content) = @_;

	open(my $fh, '>', $path) or croak("open $path: $ERRNO");
	print {$fh} $content or croak("print $path: $ERRNO");
	close($fh) or croak("close $path: $ERRNO");

	return;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(ConfigGetTests->new->run());
