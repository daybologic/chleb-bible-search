#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

use strict;
use warnings;

use Carp qw(croak);
use File::Temp qw(tempfile);
use HTTP::Tiny;
use IPC::Open3 qw(open3);
use JSON::PP qw(decode_json encode_json);
use Symbol qw(gensym);
use Text::Wrap ();

my ($previous_version, $current_version) = @ARGV;
die("Usage: $0 previous-version current-version\n")
	if (!defined($previous_version) || !defined($current_version)
	|| $previous_version !~ m{\A [0-9]+ \. [0-9]+ \. [0-9]+ \z}x
	|| $current_version !~ m{\A [0-9]+ \. [0-9]+ \. [0-9]+ \z}x);

my ($tag) = grep {
	chomp;
	my $version = $_;
	$version =~ s{\Av}{}x;
	$version =~ m{\A [0-9]+ \. [0-9]+ \. [0-9]+ \z}x
	&& version_is_less($version, $current_version);
	} split(m{\R}x, run_git('git', 'tag', '--list', 'v*', '--sort=-version:refname'));
chomp($tag) if defined($tag);
die("Cannot find a previous release tag for $current_version\n")
	if !defined($tag) || length($tag) == 0;

my $history = run_git('git', 'log', '--format=%h %s%n%b', "$tag..HEAD");
my $stat = run_git('git', 'diff', '--stat', "$tag..HEAD");
$history = substr($history, 0, 16000);
$stat = substr($stat, 0, 6000);

my $temporary_path;
my ($fh, $path) = tempfile('chleb-release-notes-XXXXXX', SUFFIX => '.txt', UNLINK => 0);
$temporary_path = $path;
close($fh) or die("Cannot close temporary file $path: $!\n");

my $notes;
if (length($ENV{OPENAI_API_KEY} // '') > 0) {
	$notes = generate_notes($tag, $previous_version, $current_version, $history, $stat);
	if (!defined($notes) || length($notes) == 0) {
		warn("OpenAI changelog generation failed; opening the release-note editor.\n");
	}
}

if (!defined($notes) || length($notes) == 0) {
	$notes = edit_notes($path, $tag, $previous_version, $current_version);
}

$notes = normalize_notes($notes);
die("No release notes were supplied\n") if length($notes) == 0;

open(my $out, '>', $path) or die("Cannot write temporary file $path: $!\n");
print {$out} $notes, "\n" or die("Cannot write temporary file $path: $!\n");
close($out) or die("Cannot close temporary file $path: $!\n");

print "$path\n";
$temporary_path = undef;

END {
	unlink($temporary_path) if defined($temporary_path) && length($temporary_path) > 0;
}

sub generate_notes {
	my ($release_tag, $previous_release, $current_release, $commit_history, $file_stat) = @_;
	my $model = $ENV{OPENAI_MODEL} // 'gpt-5-mini';
	my $prompt = <<~"PROMPT";
		Prepare Debian changelog notes for Chleb Bible Search version $current_release,
		covering the changes since release $previous_release (tag $release_tag).

		Return only concise release-note lines. Each line must describe a user-visible
		or maintainer-relevant change, start with a suitable Gitmoji when appropriate,
		and contain no Markdown bullets, heading, code fence, or introductory text.
		Do not invent changes; use only the commit history and changed-file summary.

		Commit history:
		$commit_history

		Changed-file summary:
		$file_stat
	PROMPT

	my $http = HTTP::Tiny->new(timeout => 120);
	my $response = $http->post(
		'https://api.openai.com/v1/responses',
		{
			headers => {
				'Authorization' => "Bearer $ENV{OPENAI_API_KEY}",
				'Content-Type' => 'application/json',
			},
			content => encode_json({
				model => $model,
				input => $prompt,
				max_output_tokens => 500,
				reasoning => { effort => 'minimal' },
				store => JSON::PP::false,
			}),
		},
	);

	if (!$response->{success}) {
		warn("OpenAI request failed: $response->{status} $response->{reason}\n");
		return;
	}

	my $decoded = eval { decode_json($response->{content}) };
	if ($@ || ref($decoded) ne 'HASH') {
		warn("OpenAI returned invalid JSON\n");
		return;
	}

	my @text;
	for my $item (@{$decoded->{output} // []}) {
		for my $content (@{$item->{content} // []}) {
			push(@text, $content->{text}) if ($content->{type} // '') eq 'output_text';
		}
	}
	return join("\n", @text);
}

sub edit_notes {
	my ($notes_path, $release_tag, $previous_release, $current_release) = @_;
	open(my $template, '>', $notes_path) or die("Cannot write temporary file $notes_path: $!\n");
	print {$template} "# Release notes for $current_release (since $previous_release, $release_tag)\n",
		"# Enter one note per line. Comments and blank lines are ignored.\n";
	close($template) or die("Cannot close temporary file $notes_path: $!\n");

	my $editor = $ENV{VISUAL} // $ENV{EDITOR} // 'vi';
	system($editor, $notes_path) == 0 or die("Editor failed for $notes_path\n");

	open(my $input, '<', $notes_path) or die("Cannot read temporary file $notes_path: $!\n");
	local $/ = undef;
	my $contents = <$input>;
	close($input) or die("Cannot close temporary file $notes_path: $!\n");
	return $contents;
}

sub normalize_notes {
	my ($raw_notes) = @_;
	my @lines;
	local $Text::Wrap::columns = 80;
	for my $line (split(m{\R}x, $raw_notes // '')) {
		$line =~ s{\A\s+}{}x;
		$line =~ s{\s+\z}{}x;
		next if length($line) == 0 || $line =~ m{\A \#}x;
		$line =~ s{\A (?: [-*+] \s+ | \x{2022} \s+ )}{}x;
		$line =~ s{\A \d+ [.)] \s+}{}x;
		push(@lines, Text::Wrap::wrap('  * ', '    ', $line)) if length($line) > 0;
	}
	return join("\n", @lines);
}

sub version_is_less {
	my ($lower_version, $higher_version) = @_;
	my @lower_parts = split(m{\.}x, $lower_version);
	my @higher_parts = split(m{\.}x, $higher_version);
	for my $index (0 .. 2) {
		return 1 if $lower_parts[$index] < $higher_parts[$index];
		return 0 if $lower_parts[$index] > $higher_parts[$index];
	}
	return 0;
}

sub run_git {
	my (@command) = @_;
	my ($stdin, $stdout, $stderr);
	$stderr = gensym();
	my $pid = open3($stdin, $stdout, $stderr, @command);
	close($stdin) or die("Cannot close Git command input: $!\n");
	local $/ = undef;
	my $output = <$stdout> // '';
	my $error = <$stderr> // '';
	waitpid($pid, 0);
	croak("Git command failed: $error") if $? != 0;
	return $output;
}
