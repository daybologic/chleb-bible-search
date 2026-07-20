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

package BackendSourceSelectionTests;
## no critic (RegularExpressions::RequireExtendedFormatting)
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
use strict;
use warnings;
use Carp qw(croak);
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use DBI;
use Cwd qw(chdir getcwd);
use File::Temp qw(tempdir);
use IO::Compress::Gzip qw(gzip $GzipError);
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::Bible;
use Chleb::Bible::Backend;
use Test::More 0.96;

package BackendSourceSelectionTests;

sub setUp {
	my ($self, %params) = @_;

	$self->SUPER::setUp(%params);
	$self->{__original_cwd} = getcwd();

	my $root = tempdir(CLEANUP => 1);
	mkdir($root . '/data') or croak("mkdir $root/data failed: $!");
	mkdir($root . '/cache') or croak("mkdir $root/cache failed: $!");
	$self->__makeSourceFile($root . '/data', 'core.sqlite.gz', ['asv', 'kjv']);
	$self->__makeSourceFile($root . '/data', 'kjv.sqlite.gz', ['kjv']);
	chdir($root) or croak("chdir $root failed: $!");

	$self->sut(Chleb::Bible::Backend->new({
		bible    => Chleb::Bible->new({ translation => 'kjv' }),
		dataDir  => $root . '/data',
		cacheDir => $root . '/cache',
	}));

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;

	chdir($self->{__original_cwd}) if (defined($self->{__original_cwd}));
	$self->{__original_cwd} = undef;

	return $self->SUPER::tearDown();
}

sub testPreferSingleTranslationFile {
	my ($self) = @_;

	is($self->sut->__makeSourceCompressedPath(), $self->sut->dataDir . '/kjv.sqlite.gz',
		'prefers the single-translation kjv file');

	return EXIT_SUCCESS;
}

sub testFallbackToCoreWhenNoSingleFile {
	my ($self) = @_;

	my $sut = Chleb::Bible->new({ translation => 'asv' })->__backend;
	is($sut->__makeSourceCompressedPath(), $sut->dataDir . '/core.sqlite.gz',
		'falls back to the multi-translation core file');

	return EXIT_SUCCESS;
}

sub testLocalDataDirWinsWithoutGeneratedSqlite {
	my ($self) = @_;

	my $root = tempdir(CLEANUP => 1);
	mkdir($root . '/data') or croak("mkdir $root/data failed: $!");
	mkdir($root . '/data/static') or croak("mkdir $root/data/static failed: $!");

	chdir($root) or croak("chdir $root failed: $!");
	my $backend = bless({}, 'Chleb::Bible::Backend');
	is($backend->__makeDataDir(), 'data', 'source checkout data dir wins even before generated SQLite exists');

	return EXIT_SUCCESS;
}

sub __makeSourceFile {
	my ($self, $dir, $fileName, $translations) = @_;

	my $sqlitePath = $dir . '/' . $fileName;
	$sqlitePath =~ s/\.gz\z//;

	my $dbh = DBI->connect("dbi:SQLite:dbname=${sqlitePath}", q{}, q{}, {
		RaiseError => 1,
		AutoCommit => 1,
	});
	$dbh->do('CREATE TABLE master (sig CHAR(36) NOT NULL, version INTEGER NOT NULL, built_time TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
	$dbh->do(q{INSERT INTO master (sig, version) VALUES ('178d4220-2531-11f1-8c59-ab2e7e0be878', 15)});
	$dbh->do('CREATE TABLE translation (code TEXT NOT NULL)');
	$dbh->do('CREATE TABLE properties (translation TEXT NOT NULL, name TEXT NOT NULL, value TEXT NOT NULL)');
	foreach my $translation (@{ $translations }) {
		$dbh->do('INSERT INTO translation (code) VALUES (?)', undef, $translation);
	}
	$dbh->disconnect();

	gzip($sqlitePath => $dir . '/' . $fileName) or croak("gzip failed: $GzipError");
	unlink($sqlitePath) or croak("unlink $sqlitePath failed: $!");

	return;
}

package main;
use strict;
use warnings;
exit(BackendSourceSelectionTests->new->run);
