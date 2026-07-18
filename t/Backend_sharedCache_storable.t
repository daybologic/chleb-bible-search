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

package BackendSharedCacheStorableTests;
use strict;
use warnings;
use Carp qw(croak);
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Bible;
use Chleb::Bible::Backend;
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Cwd qw(chdir getcwd);
use DBI;
use English qw(-no_match_vars);
use File::Temp qw(tempdir);
use IO::Compress::Gzip qw(gzip $GzipError);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

has root => (is => 'rw', isa => 'Str');

sub setUp {
	my ($self, %params) = @_;

	$self->SUPER::setUp(%params);
	$self->{__original_cwd} = getcwd();

	my $root = tempdir(CLEANUP => 1);
	mkdir($root . '/data') or croak("mkdir $root/data failed: $ERRNO");
	mkdir($root . '/cache') or croak("mkdir $root/cache failed: $ERRNO");
	$self->root($root);
	$self->__makeSourceFile($self->__sourcePath(), ['kjv']);
	chdir($root) or croak("chdir $root failed: $ERRNO");

	Chleb::DI::Container->instance->logger(Chleb::DI::MockLogger->new());
	$self->sut($self->__makeBackend('kjv'));

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;

	chdir($self->{__original_cwd}) if (defined($self->{__original_cwd}));
	$self->{__original_cwd} = undef;

	return $self->SUPER::tearDown();
}

sub testPersistsAcrossBackendInstances {
	my ($self) = @_;
	plan tests => 3;

	ok($self->sut->__sharedCacheSet('unit', 'alpha', { answer => 42 }), 'shared cache set succeeds');
	ok(-f $self->__sharedCachePath(), 'shared cache file exists');

	my $second = $self->__makeBackend('kjv');
	is_deeply($second->__sharedCacheGet('unit', 'alpha'), { answer => 42 },
		'second backend instance reads value from shared cache file');

	return EXIT_SUCCESS;
}

sub testDeferredWritesFlushWhenRequested {
	my ($self) = @_;
	plan tests => 3;

	$self->sut->deferSharedCacheWrites(1);
	ok($self->sut->__sharedCacheSet('unit', 'deferred', 'later'), 'deferred shared cache set succeeds');
	ok(!-f $self->__sharedCachePath(), 'deferred write does not create shared cache file immediately');
	ok($self->sut->flushSharedCache(), 'explicit flush writes deferred shared cache entries');

	return EXIT_SUCCESS;
}

sub testSentimentPersistsAcrossBackendInstances {
	my ($self) = @_;
	plan tests => 3;

	is_deeply($self->sut->getSentimentByOrdinal(1), {
		emotion => 'joy',
		tones   => [ 'praise', 'trust' ],
	}, 'sentiment loads from SQLite');

	my $second = $self->__makeBackend('kjv');
	is_deeply($second->__sharedCacheGet('sentiment', 'kjv'), [
		{
			emotion => 'joy',
			tones   => [ 'trust', 'praise' ],
		},
	], 'sentiment array is stored in the shared cache');
	is_deeply($second->getSentimentByOrdinal(1), {
		emotion => 'joy',
		tones   => [ 'praise', 'trust' ],
	}, 'second backend reads sentiment through shared cache');

	return EXIT_SUCCESS;
}

sub testStaleSourceMetadataInvalidatesTranslation {
	my ($self) = @_;
	plan tests => 2;

	$self->sut->__sharedCacheSet('unit', 'stale', 'old');
	is($self->__makeBackend('kjv')->__sharedCacheGet('unit', 'stale'), 'old',
		'value is available before source metadata changes');

	my $future = time() + 60;
	utime($future, $future, $self->__sourcePath()) or croak("utime failed: $ERRNO");
	is($self->__makeBackend('kjv')->__sharedCacheGet('unit', 'stale'), undef,
		'value is ignored after source metadata changes');

	return EXIT_SUCCESS;
}

sub testCorruptSharedCacheIsIgnored {
	my ($self) = @_;
	plan tests => 2;

	open(my $fh, '>', $self->__sharedCachePath()) or croak("open shared cache failed: $ERRNO");
	print {$fh} "not a storable file\n";
	close($fh) or croak("close shared cache failed: $ERRNO");

	my $backend = $self->__makeBackend('kjv');
	is($backend->__sharedCacheGet('unit', 'missing'), undef, 'corrupt shared cache is ignored');
	ok($backend->__sharedCacheSet('unit', 'replacement', 'ok'), 'corrupt shared cache can be replaced');

	return EXIT_SUCCESS;
}

sub __makeBackend {
	my ($self, $translation) = @_;
	return Chleb::Bible::Backend->new({
		bible    => Chleb::Bible->new({ translation => $translation }),
		dataDir  => $self->root . '/data',
		cacheDir => $self->root . '/cache',
	});
}

sub __sourcePath {
	my ($self) = @_;
	return $self->root . '/data/kjv.sqlite.gz';
}

sub __sharedCachePath {
	my ($self) = @_;
	return $self->root . '/cache/shared.bin';
}

sub __makeSourceFile {
	my ($self, $path, $translations) = @_;
	my $sqlitePath = $path;
	$sqlitePath =~ s/\.gz\z//;

	my $dbh = DBI->connect("dbi:SQLite:dbname=${sqlitePath}", q{}, q{}, {
		RaiseError => 1,
		AutoCommit => 1,
	});
	$dbh->do('CREATE TABLE master (sig CHAR(36) NOT NULL, version INTEGER NOT NULL, built_time TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
	$dbh->do(q{INSERT INTO master (sig, version) VALUES ('178d4220-2531-11f1-8c59-ab2e7e0be878', 14)});
	$dbh->do('CREATE TABLE translation (code TEXT NOT NULL)');
	$dbh->do('CREATE TABLE verse (id INTEGER NOT NULL, ordinal_relative_to_chapter INTEGER NOT NULL)');
	$dbh->do('CREATE TABLE sentiment (translation TEXT NOT NULL, ordinal INTEGER NOT NULL, emotion TEXT NOT NULL, tones TEXT NOT NULL)');
	foreach my $translation (@{ $translations }) {
		$dbh->do('INSERT INTO translation (code) VALUES (?)', undef, $translation);
		$dbh->do(q{INSERT INTO sentiment (translation, ordinal, emotion, tones) VALUES (?, 1, 'joy', '["trust","praise"]')}, undef, $translation);
	}
	$dbh->disconnect();

	gzip($sqlitePath => $path) or croak("gzip failed: $GzipError");
	unlink($sqlitePath) or croak("unlink $sqlitePath failed: $ERRNO");

	return;
}

exit(BackendSharedCacheStorableTests->new->run);
