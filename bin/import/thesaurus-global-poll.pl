#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

use Carp qw(croak);
use Getopt::Long qw(:config no_ignore_case);
use HTTP::Tiny;
use JSON::PP qw(decode_json);
use POSIX qw(EXIT_SUCCESS);

=head1 NAME

thesaurus-global-poll.pl - monitor and retrieve an OpenAI thesaurus batch

=head1 DESCRIPTION

Poll an OpenAI Batch API request until it reaches a terminal state.  On
successful completion, download the output and error JSONL files into the
selected directory.  The API key is read from C<OPENAI_API_KEY>.

=head1 OPTIONS

=over

=item C<--batch-id ID>

Batch ID to monitor. Required.

=item C<--output-dir DIRECTORY>

Directory for downloaded files. Defaults to C<data/static>.

=item C<--interval SECONDS>

Seconds between status checks. Defaults to 60.

=item C<--once>

Perform one status check and exit without waiting.

=item C<--help>

Display usage information.

=back

=cut

my %options = (
	interval   => 60,
	output_dir => 'data/static',
);

GetOptions(
	'batch-id=s'    => \$options{batch_id},
	'output-dir=s'  => \$options{output_dir},
	'interval=i'    => \$options{interval},
	once            => \$options{once},
	help            => \$options{help},
) or croak(usage());

if ($options{help}) {
	print(usage());
	exit(EXIT_SUCCESS);
}

croak("--batch-id is required\n") if !defined($options{batch_id}) || length($options{batch_id}) == 0;
croak("OPENAI_API_KEY is not set\n") if !defined($ENV{OPENAI_API_KEY}) || length($ENV{OPENAI_API_KEY}) == 0;
croak("--interval must not be negative\n") if $options{interval} < 0;

my $pollHttp = HTTP::Tiny->new();
monitorBatch($pollHttp, \%options);
exit(EXIT_SUCCESS);

=head1 PRIVATE METHODS

=over

=item C<usage()>

Return the command-line usage text.

=cut

sub usage {
	return <<'USAGE';
Usage: thesaurus-global-poll.pl --batch-id ID [options]

Poll an OpenAI Batch API request and download terminal output files.
USAGE
}

=item C<monitorBatch($client, $options)>

Poll the batch and download files after completion.

=cut

sub monitorBatch {
	my ($monitorHttp, $options) = @_;
	while (1) {
		my $batch = requestJson($monitorHttp, "/v1/batches/$options->{batch_id}");
		my $counts = $batch->{request_counts} // {};
		printf("status=%s total=%d completed=%d failed=%d\n",
			$batch->{status} // 'unknown',
			$counts->{total} // 0,
			$counts->{completed} // 0,
			$counts->{failed} // 0,
		);
		if ($batch->{status} eq 'completed' || $batch->{status} eq 'cancelled') {
			downloadFiles($monitorHttp, $batch, $options);
			return;
		}
		return if $options->{once};
		sleep($options->{interval});
	}
	return;
}

=item C<requestJson($client, $path)>

Retrieve and decode one authenticated JSON API response.

=cut

sub requestJson {
	my ($jsonClient, $path) = @_;
	my $response = $jsonClient->get("https://api.openai.com$path", {
		headers => { Authorization => "Bearer $ENV{OPENAI_API_KEY}" },
	});
	croak("OpenAI request failed ($response->{status}): $response->{reason}\n")
		unless $response->{success};
	return decode_json($response->{content});
}

=item C<downloadFiles($client, $batch, $options)>

Download any success and error files exposed by a terminal batch.

=cut

sub downloadFiles {
	my ($downloadClient, $batch, $options) = @_;
	for my $kind (qw(output error)) {
		my $fileId = $batch->{"${kind}_file_id"};
		next if !defined($fileId) || length($fileId) == 0;
		my $response = $downloadClient->get("https://api.openai.com/v1/files/$fileId/content", {
			headers => { Authorization => "Bearer $ENV{OPENAI_API_KEY}" },
		});
		croak("Cannot download $kind file ($response->{status}): $response->{reason}\n")
			if !$response->{success};
		my $path = "$options->{output_dir}/thesaurus-global-${kind}-$options->{batch_id}.jsonl";
		open(my $output, '>:raw', $path) or croak("Cannot write $path: $!\n");
		print {$output} $response->{content} or croak("Cannot write $path: $!\n");
		close($output) or croak("Cannot close $path: $!\n");
		print("Downloaded $kind results to $path\n");
	}
	return;
}

=back

=cut
