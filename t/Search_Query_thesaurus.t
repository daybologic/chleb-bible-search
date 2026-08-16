#!/usr/bin/perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

package SearchQueryThesaurusTests;
## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use DBI;
use File::Temp qw(tempfile);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Moose;

use lib 't/lib';
use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use Chleb::Bible;
use Chleb::Bible::Backend;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;
	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	my ($handle, $database) = tempfile(SUFFIX => '.sqlite', UNLINK => 1);
	close($handle) or die("Cannot close temporary database: $!\n");
	gunzip('data/asv.sqlite.gz' => $database)
		or die("Cannot decompress ASV database: $GunzipError\n");

	my $dbh = DBI->connect("dbi:SQLite:dbname=$database", q{}, q{}, {
		RaiseError => 1,
		sqlite_unicode => 1,
	});
	$dbh->do('DROP TABLE IF EXISTS thesaurus_relation');
	$dbh->do('DROP TABLE IF EXISTS thesaurus_word');
	$dbh->do(<<'SQL');
CREATE TABLE thesaurus_word (
	id INTEGER PRIMARY KEY,
	word TEXT NOT NULL UNIQUE
)
SQL
	$dbh->do(<<'SQL');
CREATE TABLE thesaurus_relation (
	source_word_id INTEGER NOT NULL,
	related_word_id INTEGER NOT NULL,
	relation TEXT NOT NULL,
	confidence REAL NOT NULL,
	PRIMARY KEY (source_word_id, related_word_id)
)
SQL
	$dbh->do('INSERT INTO thesaurus_word (id, word) VALUES (?, ?), (?, ?)', undef, 1, 'dropping', 2, 'dripping');
	$dbh->do('INSERT INTO thesaurus_relation VALUES (1, 2, ?, ?)', undef, 'synonym', 0.9);
	$dbh->disconnect();

	$self->{bible} = Chleb::Bible->new({ translation => 'asv' });
	$self->sut(Chleb::Bible::Backend->new({ bible => $self->{bible}, cachePath => $database }));

	return EXIT_SUCCESS;
}

sub testBackendForwardLookup {
	my ($self) = @_;
	plan tests => 1;

	is_deeply($self->sut->getThesaurusTerms('DROPPING'), [ 'dripping' ], 'backend reads normalized thesaurus relations');

	return EXIT_SUCCESS;
}

sub testBackendReverseLookup {
	my ($self) = @_;
	plan tests => 1;

	is_deeply($self->sut->getThesaurusTerms('DRIPPING'), [ 'dropping' ], 'backend reads thesaurus relations in reverse for search');

	return EXIT_SUCCESS;
}

sub testQueryExpansion {
	my ($self) = @_;
	plan tests => 1;
	my $bible = $self->{bible};

	$self->__mockGetThesaurusTerms();

	is_deeply($bible->newSearchQuery('dropping')->expandedWords(), [ [ 'dropping', 'dripping' ] ], 'query expansion includes the translation-specific thesaurus term');

	return EXIT_SUCCESS;
}

sub testExpandedSearch {
	my ($self) = @_;
	plan tests => 1;
	my $bible = $self->{bible};

	$self->__mockGetThesaurusTerms();

	my $results = $bible->newSearchQuery('dropping')->run();
	ok(scalar(grep { $_->text =~ /dropping|dripping/ix } @{ $results->verses }), 'expanded search returns verses matching the related term');

	return EXIT_SUCCESS;
}

=item C<__mockGetThesaurusTerms()>

Configure the mock thesaurus relation used by query expansion tests.

=cut

sub __mockGetThesaurusTerms {
	my ($self) = @_;
	$self->mock('Chleb::Bible', 'getThesaurusTerms', sub {
		my (undef, $word) = @_;
		return [ 'dripping' ] if (lc($word) eq 'dropping');
		return [ 'dropping' ] if (lc($word) eq 'dripping');
		return [];
	});

	return;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(SearchQueryThesaurusTests->new->run());
