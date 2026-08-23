#!/usr/bin/perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

use Carp qw(croak);
use DBI;
use English qw(-no_match_vars);
use File::Basename qw(dirname);
use File::Temp qw(tempfile);
use Getopt::Long qw(:config no_ignore_case);
use JSON::PP qw(decode_json);
use POSIX qw(EXIT_SUCCESS);

=head1 NAME

thesaurus-global-to-sqlite.pl - build the global thesaurus SQLite database

=head1 DESCRIPTION

Read the canonical global thesaurus JSON document and create a normalized
SQLite dictionary.  Canonical relations are stored once, while a bidirectional
lookup table provides efficient forward and reverse searches.

=head1 OPTIONS

=over

=item C<--input FILE>

Global thesaurus JSON input. Defaults to C<data/static/thesaurus.json>.

=item C<--output FILE>

SQLite output path. Defaults to C<data/dict.sqlite>.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	input  => 'data/static/thesaurus.json',
	output => 'data/dict.sqlite',
);

GetOptions(
	'input=s'  => \$options{input},
	'output=s' => \$options{output},
	'help'     => \$options{help},
) or croak(usage());

if ($options{help}) {
	print(usage());
	exit(EXIT_SUCCESS);
}

my $globalDocument = readDocument($options{input});
my $temporaryPath = writeDatabase($options{output}, $globalDocument);
rename($temporaryPath, $options{output})
	 or croak("Cannot rename $temporaryPath to $options{output}: $ERRNO\n");

printf(
	"Wrote %d words and %d relations to %s\n",
	scalar(keys(%{ $globalDocument->{words} })),
	scalar(@{ $globalDocument->{relations} }),
	$options{output},
);

exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: thesaurus-global-to-sqlite.pl [options]

Build a normalized SQLite dictionary from the global thesaurus JSON.
USAGE
}

=item C<readDocument($path)>

Read and validate the global thesaurus JSON document, returning normalized
words and relation records.

=cut

sub readDocument {
	my ($path) = @_;
	open(my $input, '<:encoding(UTF-8)', $path) or die("Cannot read $path: $ERRNO\n");
	local $INPUT_RECORD_SEPARATOR = undef;
	my $parsedDocument = decode_json(<$input>);
	close($input) or die("Cannot close $path: $ERRNO\n");

	croak("Global thesaurus JSON must contain a relations array\n")
		unless ref($parsedDocument) eq 'HASH' && ref($parsedDocument->{relations}) eq 'ARRAY';

	my %words = map { lc($_) => 1 } @{ $parsedDocument->{vocabulary} // [] };
	my @relations;
	my %seen;
	for my $relation (@{ $parsedDocument->{relations} }) {
		croak("Global thesaurus relation is malformed\n") unless ref($relation) eq 'HASH';
		my $source = lc($relation->{source} // '');
		my $target = lc($relation->{target} // '');
		my $kind = $relation->{relation} // '';
		my $confidence = $relation->{confidence};
		croak("Global thesaurus relation contains an empty word\n")
			if length($source) == 0 || length($target) == 0;
		croak("Global thesaurus relation contains an invalid confidence\n")
			if !defined($confidence) || $confidence < 0 || $confidence > 1;
		my $key = join("\x1f", $source, $target, $kind);
		next if $seen{$key}++;
		$words{$source} = 1;
		$words{$target} = 1;
		push(@relations, {
			source     => $source,
			target     => $target,
			relation   => $kind,
			confidence => 0 + $confidence,
		});
	}

	my %wordIds;
	my $id = 0;
	$wordIds{$_} = ++$id for sort(keys(%words));
	return { relations => \@relations, words => \%wordIds };
}

=item C<writeDatabase($output, $document)>

Create and populate a temporary SQLite database beside C<$output>, returning
its path for an atomic rename.

=cut

sub writeDatabase {
	my ($output, $document) = @_;
	my $directory = dirname($output);
	my ($handle, $tempPath) = tempfile('dict-XXXXXX', DIR => $directory, SUFFIX => '.sqlite', UNLINK => 0);
	close($handle) or croak("Cannot close $tempPath: $ERRNO\n");

	my $dbh = DBI->connect("dbi:SQLite:dbname=$tempPath", q{}, q{}, {
		RaiseError       => 1,
		AutoCommit       => 0,
		sqlite_unicode   => 1,
	});
	$dbh->do('PRAGMA foreign_keys = ON');
	$dbh->do('CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT NOT NULL)');
	$dbh->do('CREATE TABLE thesaurus_word (id INTEGER PRIMARY KEY, word TEXT NOT NULL UNIQUE)');
	$dbh->do(<<'SQL');
CREATE TABLE thesaurus_relation (
    id INTEGER PRIMARY KEY,
    source_word_id INTEGER NOT NULL,
    target_word_id INTEGER NOT NULL,
    relation TEXT NOT NULL,
    confidence REAL NOT NULL,
    UNIQUE (source_word_id, target_word_id, relation),
    FOREIGN KEY (source_word_id) REFERENCES thesaurus_word(id),
    FOREIGN KEY (target_word_id) REFERENCES thesaurus_word(id)
)
SQL
	$dbh->do(<<'SQL');
CREATE TABLE thesaurus_lookup (
    source_word_id INTEGER NOT NULL,
    target_word_id INTEGER NOT NULL,
    relation TEXT NOT NULL,
    confidence REAL NOT NULL,
    PRIMARY KEY (source_word_id, target_word_id, relation),
    FOREIGN KEY (source_word_id) REFERENCES thesaurus_word(id),
    FOREIGN KEY (target_word_id) REFERENCES thesaurus_word(id)
)
SQL
	$dbh->do('INSERT INTO metadata (name, value) VALUES (?, ?)', undef, 'schema', '1');
	$dbh->do('INSERT INTO metadata (name, value) VALUES (?, ?)', undef, 'source', 'thesaurus.json');

	my $insertWord = $dbh->prepare('INSERT INTO thesaurus_word (id, word) VALUES (?, ?)');
	$insertWord->execute($document->{words}->{$_}, $_) for sort(keys(%{ $document->{words} }));

	my $insertRelation = $dbh->prepare(<<'SQL');
INSERT INTO thesaurus_relation
    (source_word_id, target_word_id, relation, confidence)
VALUES (?, ?, ?, ?)
SQL
	my $insertLookup = $dbh->prepare(<<'SQL');
INSERT OR IGNORE INTO thesaurus_lookup
    (source_word_id, target_word_id, relation, confidence)
VALUES (?, ?, ?, ?)
SQL
	for my $relation (@{ $document->{relations} }) {
		my $source = $document->{words}->{ $relation->{source} };
		my $target = $document->{words}->{ $relation->{target} };
		$insertRelation->execute($source, $target, $relation->{relation}, $relation->{confidence});
		$insertLookup->execute($source, $target, $relation->{relation}, $relation->{confidence});
		$insertLookup->execute($target, $source, $relation->{relation}, $relation->{confidence});
	}

	$dbh->do('CREATE INDEX idx_thesaurus_lookup_source ON thesaurus_lookup(source_word_id, confidence DESC, target_word_id)');
	$dbh->do('CREATE INDEX idx_thesaurus_relation_source ON thesaurus_relation(source_word_id, confidence DESC)');
	$dbh->commit();
	$dbh->disconnect();
	return $tempPath;
}

=back

=cut
