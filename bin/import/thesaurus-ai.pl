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
use HTTP::Tiny;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);

=head1 NAME

thesaurus-ai.pl - generate Bible translation thesaurus candidates

=head1 DESCRIPTION

Compare corresponding verses from English translations and emit one-for-one
word substitutions suitable for thesaurus review. The default mode is fully
offline. Optional OpenAI Batch JSONL output is available for classifying the
generated candidates later; the script never contacts the API unless
C<--classify> is explicitly supplied.

=head1 OPTIONS

=over

=item C<--input-dir DIRECTORY>

Directory containing translation text files. Defaults to C<data/static>.

=item C<--translations LIST>

Comma-separated translation codes. Defaults to C<asv,kjv>.

=item C<--min-count NUMBER>

Minimum number of corresponding verses in which a substitution must occur.
Defaults to C<3>.

=item C<--output FILE>

Write candidate JSONL to FILE instead of standard output.

=item C<--batch-output FILE>

Write OpenAI Responses Batch API request JSONL for the candidates.

=item C<--classify>

Classify candidates synchronously with the OpenAI API. Requires
C<OPENAI_API_KEY>; use C<--model> or C<OPENAI_MODEL> to select the model.

=item C<--semantic-batch-output FILE>

Write Batch API requests that ask for related terms for selected vocabulary.
Use C<--words> to select words explicitly, or C<--max-words> to cap an
automatically generated vocabulary list.

=item C<--words LIST>

Comma-separated vocabulary words for C<--semantic-batch-output>.

=item C<--max-words NUMBER>

Maximum number of vocabulary words for semantic batch generation. Defaults to
C<0>, meaning all discovered non-stopwords are selected.

=item C<--model MODEL>

Model used by C<--classify> or C<--batch-output>. Defaults to
C<OPENAI_MODEL> or C<gpt-5-mini>.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	input_dir    => 'data/static',
	translations => 'asv,kjv',
	min_count    => 3,
	max_words    => 0,
	model        => $ENV{OPENAI_MODEL} // 'gpt-5-mini',
);

GetOptions(
	'input-dir=s'    => \$options{input_dir},
	'translations=s' => \$options{translations},
	'min-count=i'    => \$options{min_count},
	'output=s'       => \$options{output},
	'batch-output=s' => \$options{batch_output},
	'classify'       => \$options{classify},
	'semantic-batch-output=s' => \$options{semantic_batch_output},
	'words=s'        => \$options{words},
	'max-words=i'    => \$options{max_words},
	'model=s'        => \$options{model},
	'help'           => \$options{help},
) or croak(usage());

if ($options{help}) {
	print usage();
	exit(EXIT_SUCCESS);
}

die("--min-count must be positive\n") if ($options{min_count} < 1);
die("--max-words cannot be negative\n") if ($options{max_words} < 0);
die("--classify and --batch-output cannot be combined\n")
	if ($options{classify} && defined($options{batch_output}));
die("--classify requires OPENAI_API_KEY\n")
	if ($options{classify} && length($ENV{OPENAI_API_KEY} // '') == 0);

my @translations = grep { length($_) > 0 } split(m{\s*,\s*}x, $options{translations});
die("At least two translations are required for comparison or classification\n")
	if (scalar(@translations) < 2
	&& (defined($options{batch_output}) || $options{classify}));

my $verseTexts = readTranslations($options{input_dir}, \@translations);
my $candidateRecords = generateCandidates($verseTexts, \@translations, $options{min_count});

if ($options{classify}) {
	$candidateRecords = classifyCandidates($candidateRecords, $options{model});
}

writeJsonLines($candidateRecords, $options{output});
writeBatchFile($candidateRecords, $options{batch_output}, $options{model})
	if defined($options{batch_output});
if (defined($options{semantic_batch_output})) {
	my @words = grep { length($_) > 0 } split(m{\s*,\s*}x, $options{words} // '');
	writeSemanticBatchFile(
		{
			verses      => $verseTexts,
			translations => \@translations,
			words       => \@words,
			maximum     => $options{max_words},
			path        => $options{semantic_batch_output},
			model       => $options{model},
		},
	);
}

exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: thesaurus-ai.pl [options]

Generate translation-equivalent thesaurus candidates from data/static/*.txt.
USAGE
}

=item C<readTranslations($inputDir, $translations)>

Read selected translation files and return verse text grouped by reference.

=cut

sub readTranslations {
	my ($inputDir, $translations) = @_;
	my %verses;
	foreach my $translation (@$translations) {
		my $path = File::Spec->catfile($inputDir, "$translation.txt");
		open(my $input, '<', $path) or die("Cannot read $path: $!\n");
		while (my $line = <$input>) {
			chomp($line);
			if ($line =~ m{\A \Q$translation\E : ([^:]+) : (\d+) : (\d+) :: (.*) \z}x) {
				$verses{"$1:$2:$3"}{$translation} = $4;
			}
		}
		close($input) or die("Cannot close $path: $!\n");
	}
	return \%verses;
}

=item C<generateCandidates($verses, $translations, $minimumCount)>

Find repeated one-for-one content-word substitutions between translations.

=cut

sub generateCandidates {
	my ($verses, $translations, $minimumCount) = @_;
	my %counts;
	my %examples;
	for my $reference (sort keys %$verses) {
		my $texts = $verses->{$reference};
		for (my $translationIndex = 0; $translationIndex < scalar(@$translations); $translationIndex++) {
			for (my $otherIndex = $translationIndex + 1; $otherIndex < scalar(@$translations); $otherIndex++) {
				my ($a, $b) = @{$translations}[$translationIndex, $otherIndex];
				next unless (defined($texts->{$a}) && defined($texts->{$b}));
				my ($from, $to) = oneForOneDifference($texts->{$a}, $texts->{$b});
				next unless (defined($from) && defined($to));
				my $key = "$from\t$to";
				$counts{$key}++;
				$examples{$key} //= {
					from         => $from,
					to           => $to,
					relation     => 'translation-equivalent',
					translations => [ $a, $b ],
					references   => [],
				};
				push(@{ $examples{$key}{references} }, {
					ref  => $reference,
					from => $texts->{$a},
					to   => $texts->{$b},
				}) if (scalar(@{ $examples{$key}{references} }) < 3);
			}
		}
	}

	my @result;
	foreach my $key (sort keys %counts) {
		next if ($counts{$key} < $minimumCount);
		my $candidate = { %{ $examples{$key} } };
		$candidate->{count} = $counts{$key};
		push(@result, $candidate);
	}
	return \@result;
}

=item C<oneForOneDifference($leftText, $rightText)>

Return the sole content-word substitution between two verse texts, or no
value when the verses differ in more than one content word.

=cut

sub oneForOneDifference {
	my ($leftText, $rightText) = @_;
	my @leftWords = words($leftText);
	my @rightWords = words($rightText);
	my %leftCounts = map { $_ => 0 } @leftWords;
	my %rightCounts = map { $_ => 0 } @rightWords;
	$leftCounts{$_}++ foreach (@leftWords);
	$rightCounts{$_}++ foreach (@rightWords);

	my @removed;
	my @added;
	foreach my $word (keys %leftCounts) {
		push(@removed, ($word) x ($leftCounts{$word} - ($rightCounts{$word} // 0)))
			if ($leftCounts{$word} > ($rightCounts{$word} // 0) && !isStopWord($word));
	}
	foreach my $word (keys %rightCounts) {
		push(@added, ($word) x ($rightCounts{$word} - ($leftCounts{$word} // 0)))
			if ($rightCounts{$word} > ($leftCounts{$word} // 0) && !isStopWord($word));
	}
	return if (scalar(@removed) != 1 || scalar(@added) != 1);
	return ($removed[0], $added[0]);
}

=item C<words($text)>

Return normalized content-word tokens from a verse.

=cut

sub words {
	my ($text) = @_;
	return map { lc($_) } ($text =~ m{[A-Za-z]+(?:['-][A-Za-z]+)*}gx);
}

=item C<isStopWord($word)>

Return true for function words that should not become thesaurus entries.

=cut

sub isStopWord {
	my ($word) = @_;
	my @stopWords = qw(a an and are as at be been but by for from he her his in is it me my not of on or our that the their them there they this to was we were what which with you your);
	return scalar(grep { $_ eq $word } @stopWords) > 0;
}

=item C<classifyCandidates($candidates, $model)>

Classify candidates through the Responses API and retain accepted JSON
records. This is intentionally opt-in because it performs network requests.

=cut

sub classifyCandidates {
	my ($candidateList, $model) = @_;
	my $http = HTTP::Tiny->new(timeout => 120);
	my @accepted;
	foreach my $candidate (@$candidateList) {
		my $response = $http->post('https://api.openai.com/v1/responses', {
			headers => {
				Authorization  => "Bearer $ENV{OPENAI_API_KEY}",
				'Content-Type' => 'application/json',
			},
			content => encode_json({
				model => $model,
				input => classificationPrompt($candidate),
				max_output_tokens => 200,
				reasoning => { effort => 'minimal' },
				store => JSON::PP::false,
			}),
		});
		die("OpenAI request failed: $response->{status} $response->{reason}\n")
			unless ($response->{success});
		my $decoded = decode_json($response->{content});
		my $text = join('', map {
			map { $_->{text} // '' } grep { ($_->{type} // '') eq 'output_text' } @{ $_->{content} // [] }
		} @{ $decoded->{output} // [] });
		$text =~ s{\A\s*```json\s*}{}x;
		$text =~ s{\s*```\s*\z}{}x;
		my $decision = decode_json($text);
		push(@accepted, { %$candidate, %{ $decision } })
			if (ref($decision) eq 'HASH' && $decision->{accept});
	}
	return \@accepted;
}

=item C<classificationPrompt($candidate)>

Return the bounded prompt used to judge one candidate substitution.

=cut

sub classificationPrompt {
	my ($candidate) = @_;
	my $examples = join("\n", map {
		"Reference $_->{ref}\nA: $_->{from}\nB: $_->{to}"
	} @{ $candidate->{references} });
	return <<'PROMPT';
Decide whether this word substitution is useful for Bible search.
Return JSON only: {"accept":true|false,"confidence":0.0,"relation":"translation-equivalent"}.
Accept only when the words express the same meaning in these corresponding verses.
Do not infer broad, unrelated, hypernym, or antonym relationships.

Candidate: $candidate->{from} <-> $candidate->{to}
$examples
PROMPT
}

=item C<writeJsonLines($records, $path)>

Write records as UTF-8 JSON Lines to a file or standard output.

=cut

sub writeJsonLines { ## no critic (InputOutput::RequireBriefOpen)
	my ($records, $path) = @_;
	my $output;
	if (defined($path)) {
		open($output, '>', $path) or die("Cannot write $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
	} else {
		$output = *STDOUT;
	}
	foreach my $record (@$records) {
		print {$output} encode_json($record), "\n" or die("Cannot write JSON output: $!\n");
	}
	close($output) if (defined($path));
	return;
}

=item C<writeBatchFile($records, $path, $model)>

Write Responses API Batch JSONL requests for later offline classification.

=cut

sub writeBatchFile { ## no critic (InputOutput::RequireBriefOpen)
	my ($records, $path, $model) = @_;
	open(my $output, '>', $path) or die("Cannot write $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
	my $id = 0;
	foreach my $record (@$records) {
		print {$output} encode_json({
			custom_id => sprintf('candidate-%06d', ++$id),
			method    => 'POST',
			url       => '/v1/responses',
			body      => {
				model => $model,
				input => classificationPrompt($record),
				max_output_tokens => 200,
				reasoning => { effort => 'minimal' },
				store => JSON::PP::false,
			},
		}), "\n" or die("Cannot write batch JSON: $!\n");
	}
	close($output) or die("Cannot close $path: $!\n");
	return;
}

=item C<writeSemanticBatchFile($args)>

Write one bounded semantic-expansion request per selected translation word.

=cut

sub writeSemanticBatchFile { ## no critic (InputOutput::RequireBriefOpen)
	my ($args) = @_;
	my ($verses, $translations, $requestedWords, $maximum, $path, $model) = @{$args}{qw(verses translations words maximum path model)};
	my %contexts;
	for my $reference (sort keys %$verses) {
		for my $translation (@$translations) {
			next unless (defined($verses->{$reference}{$translation}));
			my %seen;
			for my $word (words($verses->{$reference}{$translation})) {
				next if isStopWord($word);
				next if ($seen{$word}++);
				push(@{ $contexts{$translation}{$word} }, {
					ref  => $reference,
					text => $verses->{$reference}{$translation},
				}) if (scalar(@{ $contexts{$translation}{$word} // [] }) < 3);
			}
		}
	}

	my %wanted = map { lc($_) => 1 } @$requestedWords;
	my @jobs;
	foreach my $translation (sort keys %contexts) {
		foreach my $word (sort keys %{ $contexts{$translation} }) {
			next if (scalar(@$requestedWords) > 0 && !$wanted{$word});
			push(@jobs, [ $translation, $word ]);
		}
	}
	@jobs = @jobs[0 .. $maximum - 1] if ($maximum > 0 && scalar(@jobs) > $maximum);

	open(my $output, '>', $path) or die("Cannot write $path: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
	my $jobId = 0;
	foreach my $job (@jobs) {
		my ($translation, $word) = @$job;
		my $candidate = {
			translation => $translation,
			word        => $word,
			references  => $contexts{$translation}{$word},
		};
		print {$output} encode_json({
			custom_id => sprintf('semantic-%06d', ++$jobId),
			method    => 'POST',
			url       => '/v1/responses',
			body      => {
				model => $model,
				input => semanticPrompt($candidate),
				max_output_tokens => 600,
				reasoning => { effort => 'minimal' },
				store => JSON::PP::false,
			},
		}), "\n" or die("Cannot write semantic batch JSON: $!\n");
	}
	close($output) or die("Cannot close $path: $!\n");
	return;
}

=item C<semanticPrompt($candidate)>

Return the bounded prompt used to expand one translation word semantically.

=cut

sub semanticPrompt {
	my ($candidate) = @_;
	my $examples = join("\n", map {
		"Reference $_->{ref}: $_->{text}"
	} @{ $candidate->{references} });
	my $prompt = <<'PROMPT';
You are building a conservative thesaurus for Bible search.
Given one word from one Bible translation and up to three Bible contexts,
return JSON only in this shape:
{"terms":[{"term":"...","relation":"synonym|translation-variant|inflection","confidence":0.0}]}

Include only words that would be useful for finding verses with the same
meaning. Do not include antonyms, broad categories, guesses, proper names,
or merely associated words. Include at most twenty terms. The terms must be
lowercase single words.

PROMPT
	$prompt .= "Translation: $candidate->{translation}\n"
	    . "Word: $candidate->{word}\n"
	    . "$examples\n";
	return $prompt;
}

=back

=cut
