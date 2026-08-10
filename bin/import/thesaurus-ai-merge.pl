#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

use Carp qw(croak);
use Getopt::Long qw(:config no_ignore_case);
use JSON::PP qw(decode_json encode_json);
use File::Spec;
use POSIX qw(EXIT_SUCCESS);

=head1 NAME

thesaurus-ai-merge.pl - merge completed thesaurus batch results

=head1 DESCRIPTION

Match saved Batch API requests and responses by C<custom_id>, apply later
retry responses over earlier responses, validate the model JSON, and emit a
deterministic translation-specific thesaurus.

=head1 OPTIONS

=over

=item C<--directory DIRECTORY>

Directory containing the saved request and result JSONL files. Defaults to the
current directory.

=item C<--output FILE>

Output JSON file. Defaults to C<thesaurus.json> in the selected directory.

=item C<--split-directory DIRECTORY>

Also write one JSON file per translation into DIRECTORY.

=item C<--minimum-confidence NUMBER>

Minimum confidence to retain. Defaults to C<0.7>.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	directory          => '.',
	minimum_confidence => 0.7,
);

GetOptions(
	'directory=s'          => \$options{directory},
	'output=s'             => \$options{output},
	'split-directory=s'    => \$options{split_directory},
	'minimum-confidence=f' => \$options{minimum_confidence},
	'help'                 => \$options{help},
) or croak(usage());

if ($options{help}) {
	print usage();
	exit(EXIT_SUCCESS);
}

die("--minimum-confidence must be between 0 and 1\n")
	if ($options{minimum_confidence} < 0 || $options{minimum_confidence} > 1);

my $output = $options{output}
	// File::Spec->catfile($options{directory}, 'thesaurus.json');
my @translations = qw(asv kjv pickthall);
my $requestMap = readRequests($options{directory}, \@translations);
my $terms = readResults($options{directory}, $requestMap, $options{minimum_confidence});

open(my $output_fh, '>:encoding(UTF-8)', $output)
	or die("Cannot write $output: $!\n");
print {$output_fh} encode_json({
	version      => 1,
	translations => $terms,
}), "\n" or die("Cannot write $output: $!\n");
close($output_fh) or die("Cannot close $output: $!\n");

writeSplitFiles($options{split_directory}, $terms) if defined($options{split_directory});

my $word_count = 0;
my $term_count = 0;
for my $translation (keys %$terms) {
	$word_count += scalar(keys %{ $terms->{$translation} });
	$term_count += scalar(map { @{ $terms->{$translation}{$_} } } keys %{ $terms->{$translation} });
}
printf("Wrote %d source words and %d related terms to %s\n", $word_count, $term_count, $output);

exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: thesaurus-ai-merge.pl [options]

Merge thesaurus-ai.pl Batch API requests and responses.
USAGE
}

=item C<readRequests($directory, $translations)>

Read request JSONL files and map each batch request identifier to its
translation and source word.

=cut

sub readRequests {
	my ($directory, $translations) = @_;
	my %requests;
	for my $translation (@$translations) {
		for my $suffix ('', '-retry', '-final-retry') {
			my $path = File::Spec->catfile($directory, "thesaurus-$translation$suffix.jsonl");
			next unless -f $path;
			open(my $input, '<:raw', $path) or die("Cannot read $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
			while (my $line = <$input>) {
				my $request = decode_json($line);
				my $prompt = $request->{body}{input} // '';
				if ($prompt =~ m{Translation:\s*([^\n]+)\nWord:\s*([^\n]+)}x) {
					$requests{"$translation\t$request->{custom_id}"} = {
						translation => lc($1),
						word        => lc($2),
					};
				}
			}
			close($input) or die("Cannot close $path: $!\n");
		}
	}
	return \%requests;
}

=item C<readResults($directory, $requests, $minimumConfidence)>

Read result JSONL files, retaining valid terms at or above the confidence
threshold and allowing later retry files to replace earlier responses.

=cut

sub readResults {
	my ($directory, $requests, $minimumConfidence) = @_;
	my %terms;
	for my $translation (qw(asv kjv pickthall)) {
		for my $suffix ('', '-retry', '-final-retry') {
			my $path = File::Spec->catfile($directory, "thesaurus-$translation$suffix-results.jsonl");
			next unless -f $path;
			open(my $input, '<:raw', $path) or die("Cannot read $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
			while (my $line = <$input>) {
				my $result = decode_json($line);
				my $request = $requests->{ "$translation\t$result->{custom_id}" };
				next unless defined($request);
				my $decoded = decodeModelTerms($result);
				next unless defined($decoded);
				for my $term (@{ $decoded->{terms} }) {
					next unless validTerm($term, $minimumConfidence, $request->{word});
					my $existing = $terms{$request->{translation}}{$request->{word}}{$term->{term}};
					if (!defined($existing) || $term->{confidence} > $existing->{confidence}) {
						$terms{$request->{translation}}{$request->{word}}{$term->{term}} = {
							relation   => $term->{relation},
							confidence => 0 + $term->{confidence},
						};
					}
				}
			}
			close($input) or die("Cannot close $path: $!\n");
		}
	}
	my %sorted;
	for my $translation (sort keys %terms) {
		for my $word (sort keys %{ $terms{$translation} }) {
			$sorted{$translation}{$word} = [
				map {
					{
						term       => $_,
						relation   => $terms{$translation}{$word}{$_}{relation},
						confidence => $terms{$translation}{$word}{$_}{confidence},
					}
				} sort keys %{ $terms{$translation}{$word} }
			];
		}
	}
	return \%sorted;
}

=item C<decodeModelTerms($result)>

Decode the model's JSON terms object from a Batch API response.

=cut

sub decodeModelTerms {
	my ($result) = @_;
	my $text = '';
	for my $output (@{ $result->{response}{body}{output} // [] }) {
		next unless (($output->{type} // '') eq 'message');
		for my $content (@{ $output->{content} // [] }) {
			$text .= $content->{text} // ''
				if (($content->{type} // '') eq 'output_text');
		}
	}
	utf8::encode($text);
	my $decoded = eval { decode_json($text) };
	return if !defined($decoded) || ref($decoded) ne 'HASH' || ref($decoded->{terms}) ne 'ARRAY';
	return $decoded;
}

=item C<validTerm($term, $minimumConfidence, $sourceWord)>

Return true when one model term meets the conservative import policy.

=cut

sub validTerm {
	my ($term, $minimumConfidence, $sourceWord) = @_;
	return 0 unless ref($term) eq 'HASH';
	return 0 unless defined($term->{term}) && defined($term->{relation});
	return 0 unless $term->{relation} =~ m{\A (?:synonym|translation-variant|inflection) \z}x;
	return 0 if !defined($term->{confidence}) || $term->{confidence} < $minimumConfidence;
	return 0 unless $term->{term} =~ m{\A [a-z]+ (?:['-][a-z]+)* \z}x;
	return 0 if $term->{term} eq $sourceWord;
	return 1;
}

=item C<writeSplitFiles($directory, $terms)>

Write one versioned JSON artifact for each translation.

=cut

sub writeSplitFiles {
	my ($directory, $termMap) = @_;
	for my $translation (sort keys %$termMap) {
		my $path = File::Spec->catfile($directory, "thesaurus-$translation.json");
		open(my $translationOutput, '>:encoding(UTF-8)', $path)
			or die("Cannot write $path: $!\n");
		print {$translationOutput} encode_json({
			version      => 1,
			translation  => $translation,
			terms        => $termMap->{$translation},
		}), "\n" or die("Cannot write $path: $!\n");
		close($translationOutput) or die("Cannot close $path: $!\n");
	}
	return;
}

=back

=cut
