#!/usr/bin/perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;

use File::Temp qw(tempfile);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use DBI;
use Test::More;

use lib 'lib';
use Chleb::Bible;
use Chleb::Bible::Backend;

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

my $bible = Chleb::Bible->new({ translation => 'asv' });
my $backend = Chleb::Bible::Backend->new({ bible => $bible, cachePath => $database });

is_deeply(
	$backend->getThesaurusTerms('DROPPING'),
	[ 'dripping' ],
	'backend reads normalized thesaurus relations',
);

{
	no warnings 'redefine'; ## no critic (TestingAndDebugging::ProhibitNoWarnings)
	local *Chleb::Bible::getThesaurusTerms = sub {
		my ($self, $word) = @_;
		return lc($word) eq 'dropping' ? [ 'dripping' ] : [];
	};

is_deeply(
		$bible->newSearchQuery('dropping')->expandedWords(),
		[ [ 'dropping', 'dripping' ] ],
		'query expansion includes the translation-specific thesaurus term',
	);

my $results = $bible->newSearchQuery('dropping')->run();
ok(
		scalar(grep { $_->text =~ /dropping|dripping/ix } @{ $results->verses }),
		'expanded search returns verses matching the related term',
	);
}

done_testing();
