#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

use Carp qw(croak);
use Getopt::Long qw(:config no_ignore_case);
use JSON::PP qw(decode_json encode_json);
use JSON::PP (); ## no critic (Modules::ProhibitConditionalUseStatements)
use POSIX qw(EXIT_SUCCESS);

=head1 NAME

thesaurus-global-ai.pl - create global thesaurus expansion requests

=head1 DESCRIPTION

Create OpenAI Batch API JSONL requests for a translation-independent English
thesaurus.  The generated prompts may return modern, historical, or biblical
terms; they are not restricted to the vocabulary of any current translation.
This script only writes requests and never contacts the API.

=head1 OPTIONS

=over

=item C<--input FILE>

Global thesaurus JSON input. Defaults to C<data/static/thesaurus.json>.

=item C<--output FILE>

Batch request JSONL output. Defaults to
C<data/static/thesaurus-global-batch.jsonl>.

=item C<--max-words NUMBER>

Limit the number of unique terms. Zero means all terms. Defaults to zero.

=item C<--model MODEL>

Model name. Defaults to C<OPENAI_MODEL> or C<gpt-5-mini>.

=item C<--batch-size NUMBER>

Maximum requests per output file. Defaults to 50,000. When exceeded, output
files are named with C<.part-NNN> before the C<.jsonl> suffix.

=item C<--parts NUMBER>

Split the requests into this many balanced output files. Cannot be combined
with C<--batch-size>.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	input  => 'data/static/thesaurus.json',
	model  => $ENV{OPENAI_MODEL} // 'gpt-5-mini',
	output => 'data/static/thesaurus-global-batch.jsonl',
	batch_size => 50_000,
);

GetOptions(
	'input=s'      => \$options{input},
	'output=s'     => \$options{output},
	'max-words=i'  => \$options{max_words},
	'model=s'      => \$options{model},
	'batch-size=i' => sub { $options{batch_size} = $_[1]; $options{batch_size_explicit} = 1; },
	'parts=i'      => \$options{parts},
	'help'         => \$options{help},
) or croak(usage());

if ($options{help}) {
	print(usage());
	exit(EXIT_SUCCESS);
}

die("--max-words cannot be negative\n") if (($options{max_words} // 0) < 0);
die("--batch-size must be positive\n") if (($options{batch_size} // 0) <= 0);
die("--parts must be positive\n") if (defined($options{parts}) && $options{parts} <= 0);
die("--parts cannot be combined with --batch-size\n")
	if defined($options{parts}) && $options{batch_size_explicit};

my $terms = readTerms($options{input});
@$terms = @$terms[0 .. $options{max_words} - 1]
	if (($options{max_words} // 0) > 0 && scalar(@$terms) > $options{max_words});
my $calculatedBatchSize = defined($options{parts})
	? int((scalar(@$terms) + $options{parts} - 1) / $options{parts})
	: $options{batch_size};
my $outputs = writeRequests($options{output}, $terms, $options{model}, $calculatedBatchSize);
printf("Wrote %d global thesaurus requests to %s\n", scalar(@$terms), join(', ', @$outputs));

exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: thesaurus-global-ai.pl [options]

Write translation-independent global thesaurus Batch API requests.
USAGE
}

=item C<readTerms($path)>

Read and sort the unique source and target terms in a global thesaurus JSON.

=cut

sub readTerms {
	my ($path) = @_;
	open(my $input, '<:encoding(UTF-8)', $path) or die("Cannot read $path: $!\n");
	local $/ = undef;
	my $document = decode_json(<$input>);
	close($input) or die("Cannot close $path: $!\n");
	my %terms;
	$terms{lc($_)} = 1 for @{ $document->{vocabulary} // [] };
	for my $relation (@{ $document->{relations} // [] }) {
		$terms{lc($relation->{source})} = 1 if (defined($relation->{source}));
		$terms{lc($relation->{target})} = 1 if (defined($relation->{target}));
	}
	return [sort keys %terms];
}

=item C<writeRequests($path, $termList, $model, $batchSize)>

Write one deterministic Batch API request per global vocabulary term.

=cut

sub writeRequests {
	my ($path, $termList, $model, $batchSize) = @_;
	my @outputs;
	my $singleFile = scalar(@$termList) <= $batchSize;
	my ($output, $currentPart);
	for my $index (0 .. $#$termList) {
		my $part = $singleFile ? 1 : 1 + int($index / $batchSize);
		if (!defined($currentPart) || $part != $currentPart) {
			close($output) if defined($output);
			my $partPath = $singleFile
				? $path
				: sprintf('%s.part-%03d.jsonl', $path =~ s/\.jsonl\z//xr, $part);
			open($output, '>:encoding(UTF-8)', $partPath) or die("Cannot write $partPath: $!\n"); ## no critic (InputOutput::RequireBriefOpen)
			push(@outputs, $partPath);
			$currentPart = $part;
		}
		my $line = encode_json({
			body => {
				input => semanticPrompt($termList->[$index]),
				max_output_tokens => 600,
				model => $model,
				reasoning => { effort => 'minimal' },
				store => JSON::PP::false,
			},
			custom_id => sprintf('global-semantic-%06d', $index + 1),
			method => 'POST',
			url => '/v1/responses',
		}) . "\n";
		print {$output} $line or die("Cannot write request: $!\n");
	}
	close($output) if defined($output);
	return \@outputs;
}

=item C<semanticPrompt($word)>

Return the conservative global thesaurus prompt for one word.

=cut

sub semanticPrompt {
	my ($word) = @_;
	my $prompt = <<'PROMPT';
You are building a conservative, translation-independent English thesaurus for Bible search.
Given one English word, return JSON only in this shape:
{"terms":[{"term":"...","relation":"synonym|translation-variant|inflection|historical|archaic","confidence":0.0}]}

Include useful modern, historical, archaic, and biblical terms with the same meaning.
Use the historical or archaic relation labels when those labels apply; retain
those terms even when their confidence is lower than the normal threshold.
Do not restrict terms to any current Bible translation. Do not include antonyms,
broad categories, proper names, or merely associated words. Include at most twenty
terms. Terms must be lowercase single English words, and the input word itself must
not be returned. Use confidence from 0.0 to 1.0.

PROMPT
	$prompt .= "Word: $word\n";
	return $prompt;
}

=back

=cut
