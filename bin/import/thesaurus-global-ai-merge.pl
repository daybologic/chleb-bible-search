#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

use Carp qw(croak);
use Digest::SHA qw(sha1_hex);
use Getopt::Long qw(:config no_ignore_case);
use JSON::PP qw(decode_json encode_json);
use POSIX qw(EXIT_SUCCESS);

=head1 NAME

thesaurus-global-ai-merge.pl - filter global thesaurus batch results

=head1 DESCRIPTION

Match global thesaurus requests and Batch API responses, retain valid model
terms, and write a deterministic global relation graph.  Historical and
archaic relations are supported alongside synonym, translation-variant, and
inflection relations.

=head1 OPTIONS

=over

=item C<--requests FILE>

Global request JSONL file. Defaults to
C<data/static/thesaurus-global-batch.jsonl>.

=item C<--results FILE>

Completed Batch API result JSONL file. Required.

=item C<--output FILE>

Filtered global JSON output. Defaults to
C<data/static/thesaurus.json>.

=item C<--minimum-confidence NUMBER>

Minimum confidence to retain. Defaults to C<0.6>.

=item C<--retry-output FILE>

Write one new request for every source word whose response was malformed,
empty, or contained filtered terms.

=item C<--model MODEL>

Model for retry requests. Defaults to C<gpt-5-mini>.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	minimum_confidence => 0.6,
	model              => 'gpt-5-mini',
output             => 'data/static/thesaurus.json',
	requests           => 'data/static/thesaurus-global-batch.jsonl',
);
my %allowedRelations = map { $_ => 1 } qw(synonym translation-variant inflection historical archaic);

GetOptions(
	'minimum-confidence=f' => \$options{minimum_confidence},
	'output=s'             => \$options{output},
	'requests=s'           => \$options{requests},
	'results=s'            => \$options{results},
	'retry-output=s'       => \$options{retry_output},
	'model=s'              => \$options{model},
	help                  => \$options{help},
) or croak(usage());

if ($options{help}) {
	print(usage());
	exit(EXIT_SUCCESS);
}
croak("--results is required\n") if !defined($options{results}) || length($options{results}) == 0;
croak("--minimum-confidence must be between 0 and 1\n")
	if $options{minimum_confidence} < 0 || $options{minimum_confidence} > 1;

my $requestsById = readRequests($options{requests});
my $filteredDocument = readResults($options{results}, $requestsById, $options{minimum_confidence});
writeOutput($options{output}, $filteredDocument);
writeRetryRequests($options{retry_output}, $filteredDocument->{retry_sources}, $options{model})
	if defined($options{retry_output});
printf("Wrote %d global relations to %s\n", scalar(@{ $filteredDocument->{relations} }), $options{output});
exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: thesaurus-global-ai-merge.pl --results FILE [options]

Filter completed global thesaurus Batch API results.
USAGE
}

=item C<readRequests($path)>

Read request identifiers and their source words.

=cut

sub readRequests {
	my ($path) = @_;
	open(my $input, '<:raw', $path) or croak("Cannot read $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
	my %requestMap;
	while (my $line = <$input>) {
		my $request = decode_json($line);
		my $prompt = $request->{body}{input} // '';
		$requestMap{$request->{custom_id}} = lc($1)
			if $prompt =~ m{\nWord:\s*([^\n]+)}x;
	}
	close($input) or croak("Cannot close $path: $!\n");
	return \%requestMap;
}

=item C<readResults($path, $requests, $minimumConfidence)>

Read, filter, deduplicate, and sort completed model relations.

=cut

sub readResults {
	my ($path, $requestLookup, $minimumConfidence) = @_;
	my %relations;
	my %vocabulary = map { $_ => 1 } values %$requestLookup;
	my %retrySources;
	open(my $input, '<:raw', $path) or croak("Cannot read $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
	while (my $line = <$input>) {
		my $result = decode_json($line);
		my $source = $requestLookup->{ $result->{custom_id} };
		next unless defined($source);
		my $decoded = decodeModelTerms($result);
		if (!defined($decoded)) {
			$retrySources{$source} = 1;
			next;
		}
		$retrySources{$source} = 1 if scalar(@{ $decoded->{terms} }) == 0;
		for my $term (@{ $decoded->{terms} }) {
			if (!validTerm($term, $minimumConfidence, $source)) {
				$retrySources{$source} = 1;
				next;
			}
			$vocabulary{ $term->{term} } = 1;
			my $key = join("\0", $source, $term->{term}, $term->{relation});
			$relations{$key} = {
				confidence => 0 + $term->{confidence},
				relation   => $term->{relation},
				source     => $source,
				target     => $term->{term},
			} if !defined($relations{$key}) || $term->{confidence} > $relations{$key}{confidence};
		}
	}
	close($input) or croak("Cannot close $path: $!\n");
	return {
		language   => 'en',
		relations  => [map { $relations{$_} } sort {
			$relations{$a}{source} cmp $relations{$b}{source}
				|| $relations{$a}{target} cmp $relations{$b}{target}
				|| $relations{$a}{relation} cmp $relations{$b}{relation}
		} keys %relations],
		vocabulary => [sort keys %vocabulary],
		retry_sources => [sort keys %retrySources],
		version    => 1,
	};
}

=item C<writeRetryRequests($path, $sources, $model)>

Write fresh requests for source words requiring another attempt.

=cut

sub writeRetryRequests {
	my ($path, $sources, $model) = @_;
	open(my $output, '>:encoding(UTF-8)', $path) or croak("Cannot write $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
	for my $source (@$sources) {
		my $request = {
			body => {
				input => retryPrompt($source),
				max_output_tokens => 600,
				model => $model,
				reasoning => { effort => 'minimal' },
				store => JSON::PP::false,
			},
			custom_id => 'global-semantic-retry-' . sha1_hex($source),
			method => 'POST',
			url => '/v1/responses',
		};
		print {$output} encode_json($request), "\n" or croak("Cannot write $path: $!\n");
	}
	close($output) or croak("Cannot close $path: $!\n");
	printf("Wrote %d retry requests to %s\n", scalar(@$sources), $path);
	return;
}

=item C<retryPrompt($source)>

Return the strict retry prompt for one source word.

=cut

sub retryPrompt {
	my ($source) = @_;
	return <<"PROMPT";
Return JSON only in this shape:
{"terms":[{"term":"...","relation":"synonym|translation-variant|inflection|historical|archaic","confidence":0.0}]}

Give useful modern, historical, archaic, and biblical equivalents for the one
English word below. Use only lowercase single words, never phrases, spaces,
underscores, proper names, antonyms, or associated concepts. Use historical or
archaic when appropriate. Do not return the input word. Return at least one
defensible term if possible, and no more than twenty terms.

Word: $source
PROMPT
}

=item C<decodeModelTerms($result)>

Decode the model's JSON terms object from one Batch API response.

=cut

sub decodeModelTerms {
	my ($result) = @_;
	my $text = '';
	for my $output (@{ $result->{response}{body}{output} // [] }) {
		next unless ($output->{type} // '') eq 'message';
		for my $content (@{ $output->{content} // [] }) {
			$text .= $content->{text} // '' if ($content->{type} // '') eq 'output_text';
		}
	}
	my $decoded = eval { decode_json($text) };
	return if !defined($decoded) || ref($decoded) ne 'HASH' || ref($decoded->{terms}) ne 'ARRAY';
	return $decoded;
}

=item C<validTerm($term, $minimumConfidence, $source)>

Apply the conservative global-term validation policy.

=cut

sub validTerm {
	my ($term, $minimumConfidence, $source) = @_;
	return 0 unless ref($term) eq 'HASH';
	return 0 unless defined($term->{term}) && defined($term->{relation});
	return 0 unless $allowedRelations{$term->{relation}};
	return 0 if !defined($term->{confidence}) || $term->{confidence} > 1;
	return 0 if $term->{relation} ne 'historical' && $term->{relation} ne 'archaic'
		&& $term->{confidence} < $minimumConfidence;
	return 0 unless $term->{term} =~ m{\A [a-z]+ (?:['-][a-z]+)* \z}x;
	return 0 if $term->{term} eq $source;
	return 1;
}

=item C<writeOutput($path, $document)>

Write the filtered global JSON document.

=cut

sub writeOutput {
	my ($path, $globalDocument) = @_;
	my %publicDocument = map { $_ => $globalDocument->{$_} } qw(language relations vocabulary version);
	open(my $output, '>:encoding(UTF-8)', $path) or croak("Cannot write $path: $!\n");
	print {$output} JSON::PP->new->canonical(1)->pretty(1)->encode(\%publicDocument), "\n"
		or croak("Cannot write $path: $!\n");
	close($output) or croak("Cannot close $path: $!\n");
	return;
}

=back

=cut
