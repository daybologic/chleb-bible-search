#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

use Carp qw(croak);
use File::Spec;
use Getopt::Long qw(:config no_ignore_case);
use JSON::PP (); ## no critic (Modules::ProhibitConditionalUseStatements)
use POSIX qw(EXIT_SUCCESS);

=head1 NAME

wordnet-to-thesaurus.pl - convert Princeton WordNet synsets to thesaurus JSON

=head1 DESCRIPTION

Read the WordNet 3.0 noun, verb, adjective, and adverb database files and
write a deterministic thesaurus source.  Each synset contributes a synonym
relation between each pair of single-word lemmas.  Multi-word expressions are
excluded because the current search tokenizer operates on individual words.

=head1 OPTIONS

=over

=item C<--input-dir DIRECTORY>

WordNet dictionary directory. Defaults to C</usr/share/wordnet>.

=item C<--output FILE>

Output JSON file. Defaults to C<data/static/thesaurus-wordnet.json>.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	input_dir => '/usr/share/wordnet',
	output    => 'data/static/thesaurus-wordnet.json',
);

GetOptions(
	'input-dir=s' => \$options{input_dir},
	'output=s'    => \$options{output},
	'help'        => \$options{help},
) or croak(usage());

if ($options{help}) {
	print(usage());
	exit(EXIT_SUCCESS);
}

my $terms = readWordNet($options{input_dir});
writeThesaurus($options{output}, $terms);
printf("Wrote %d WordNet source terms to %s\n", scalar(keys %$terms), $options{output});
exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: wordnet-to-thesaurus.pl [options]

Convert WordNet 3.0 synsets into a thesaurus source JSON file.
USAGE
}

=item C<readWordNet($directory)>

Read all supported WordNet data files and return a source-to-target relation map.

=cut

sub readWordNet { ## no critic (InputOutput::RequireBriefOpen)
	my ($directory) = @_;
	my %relations;
	for my $part (qw(noun verb adj adv)) {
		my $path = File::Spec->catfile($directory, "data.$part");
		open(my $input, '<:encoding(UTF-8)', $path) or die("Cannot read $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
		while (my $line = <$input>) {
			next if ($line =~ /^\s*\#/x || $line !~ /\|/x);
			$line =~ s/\s*\|.*\z//x;
			my @fields = split(/\s+/x, $line);
			next if (scalar(@fields) < 4 || $fields[0] !~ /^\d+$/x);
			my $word_count = hex($fields[3]);
			my @lemmas;
			for my $index (0 .. $word_count - 1) {
				my $word_index = 4 + ($index * 2);
				last if ($word_index >= scalar(@fields));
				my $word = lc($fields[$word_index]);
				$word =~ s/_/ /gx;
				if ($word =~ /^[a-z]+(?:['-][a-z]+)*\z/x) {
					push(@lemmas, $word);
					$relations{$word} //= {};
				}
			}
			for my $source (@lemmas) {
				for my $target (@lemmas) {
					next if ($source eq $target);
					$relations{$source}{$target} = 1;
				}
			}
		}
		close($input) or die("Cannot close $path: $!\n");
	}
	return \%relations;
}

=item C<writeThesaurus($path, $relations)>

Write the canonical, pretty-printed WordNet source document.

=cut

sub writeThesaurus {
	my ($path, $relations) = @_;
	my %terms;
	for my $source (sort keys %$relations) {
		$terms{$source} = [
			map {
				{
					confidence => 0.9,
					relation   => 'synonym',
					term       => $_,
				}
			} sort keys %{ $relations->{$source} }
		];
	}
	open(my $output, '>:encoding(UTF-8)', $path) or die("Cannot write $path: $!\n");
	my $json = JSON::PP->new->canonical(1)->pretty(1)->utf8(0);
	print {$output} $json->encode({
		license   => 'WordNet 3.0 License',
		source    => 'Princeton WordNet 3.0',
		terms     => \%terms,
		version   => 1,
	}), "\n" or die("Cannot write $path: $!\n");
	close($output) or die("Cannot close $path: $!\n");
	return;
}

=back

=cut
