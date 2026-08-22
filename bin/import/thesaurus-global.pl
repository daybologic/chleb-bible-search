#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

use Carp qw(croak);
use File::Basename qw(basename);
use File::Spec;
use Getopt::Long qw(:config no_ignore_case);
use JSON::PP qw(decode_json);
use JSON::PP (); ## no critic (Modules::ProhibitConditionalUseStatements)
use POSIX qw(EXIT_SUCCESS);

=head1 NAME

thesaurus-global.pl - merge translation thesauri into one global graph

=head1 DESCRIPTION

Read deterministic translation thesaurus JSON files and write one canonical
global JSON relation graph.  Duplicate relations are merged, retaining the
highest confidence and all translations which supplied the relation.

=head1 OPTIONS

=over

=item C<--input-dir DIRECTORY>

Directory containing C<thesaurus-*.json> files. Defaults to C<data/static>.

=item C<--output FILE>

Output JSON file. Defaults to C<data/static/thesaurus.json>.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	input_dir => 'data/static',
	output    => 'data/static/thesaurus.json',
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

my $relations = readThesauri($options{input_dir});
writeGlobalThesaurus($options{output}, $relations);

exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: thesaurus-global.pl [options]

Merge data/static/thesaurus-*.json into one canonical global thesaurus JSON file.
USAGE
}

=item C<readThesauri($directory)>

Read translation thesaurus files and return deduplicated relation records.

=cut

sub readThesauri {
	my ($directory) = @_;
	my %relationIndex;
	my @paths = sort grep { basename($_) ne 'thesaurus.json' } glob(File::Spec->catfile($directory, 'thesaurus-*.json'));

	for my $path (@paths) {
		open(my $input, '<:encoding(UTF-8)', $path) or die("Cannot read $path: $!\n");
		local $/ = undef;
		my $document = decode_json(<$input>);
		close($input) or die("Cannot close $path: $!\n");
		my $translation = $document->{translation};
		if (!defined($translation) || length($translation) == 0) {
			$translation = basename($path);
			$translation =~ s{\Athesaurus-}{}x;
			$translation =~ s{\.json\z}{}x;
		}
		$translation = lc($translation);

		for my $source (sort keys %{ $document->{terms} // {} }) {
			for my $term (@{ $document->{terms}{$source} // [] }) {
				next unless (ref($term) eq 'HASH' && defined($term->{term}) && defined($term->{relation}));
				my $target = lc($term->{term});
				my $relation = lc($term->{relation});
				my $key = join("\0", lc($source), $target, $relation);
				$relationIndex{$key} //= {
					confidence  => 0,
					relation    => $relation,
					source      => lc($source),
					target      => $target,
					translations => {},
				};
				$relationIndex{$key}{confidence} = $term->{confidence}
					if (defined($term->{confidence}) && $term->{confidence} > $relationIndex{$key}{confidence});
				$relationIndex{$key}{translations}{$translation} = 1;
			}
		}
	}

	return [
		map {
			{
				confidence   => 0 + $relationIndex{$_}{confidence},
				relation     => $relationIndex{$_}{relation},
				source       => $relationIndex{$_}{source},
				target       => $relationIndex{$_}{target},
				translations => [sort keys %{ $relationIndex{$_}{translations} }],
			}
		} sort {
			$relationIndex{$a}{source} cmp $relationIndex{$b}{source}
				|| $relationIndex{$a}{target} cmp $relationIndex{$b}{target}
				|| $relationIndex{$a}{relation} cmp $relationIndex{$b}{relation}
		} keys %relationIndex
	];
}

=item C<writeGlobalThesaurus($path, $relations)>

Write the canonical, pretty-printed global thesaurus JSON document.

=cut

sub writeGlobalThesaurus {
	my ($path, $relationRecords) = @_;
	open(my $output, '>:encoding(UTF-8)', $path) or die("Cannot write $path: $!\n");
	my $json = JSON::PP->new->canonical(1)->pretty(1)->utf8(0);
	print {$output} $json->encode({
		language  => 'en',
		relations => $relationRecords,
		version   => 1,
	}), "\n" or die("Cannot write $path: $!\n");
	close($output) or die("Cannot close $path: $!\n");
	return;
}

=back

=cut
