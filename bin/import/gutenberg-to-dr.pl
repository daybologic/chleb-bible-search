#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package main;
use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);
use HTML::TreeBuilder;
use HTTP::Tiny;
use IO::File;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;

Readonly my $DEFAULT_URL => 'https://www.gutenberg.org/cache/epub/8300/pg8300-images.html';
Readonly my @BOOK_CODES => qw(
	Gen Exo Lev Num Deu Josh Judg Ruth 1Ki 2Ki 3Ki 4Ki 1Ch 2Ch Ezr Neh Tob Jdt Est Job Psa Pro Ecc
	Song Wis Sir Isa Jer Lam Bar Eze Dan Hos Joe Amo Oba Jon Mic Nah Hab Zep Hag Zec Mal 1Ma 2Ma Mat
	Mark Luke John Acts Rom 1Co 2Co Gal Eph Phi Col 1Th 2Th 1Ti 2Ti Tit Phile Heb Jam 1Pe 2Pe 1Jo 2Jo
	3Jo Jud Rev
);

=head1 NAME

gutenberg-to-dr.pl - Convert the Gutenberg Douay-Rheims HTML into Chleb input

=head1 SYNOPSIS

gutenberg-to-dr.pl [--url URL] [--output FILE]

=head1 DESCRIPTION

Download the Gutenberg Douay-Rheims HTML and write Chleb's line-oriented
translation format. Only paragraphs beginning with a chapter and verse marker
such as C<1:1.> are retained; introductions, headings, notes, and other prose
are ignored.

=cut

sub __usage {
	print STDERR "Usage: $0 [--url URL] [--output FILE]\n";
	return EXIT_FAILURE;
}

sub __fetch {
	my ($url) = @_;
	my $response = HTTP::Tiny->new(timeout => 120)->get($url);
	die("Cannot download $url: $response->{status} $response->{reason}\n")
		unless ($response->{success});
	return $response->{content};
}

=head1 __bookIndexFromNumber($bookNumber)

Return the zero-based internal book index for a Gutenberg book number.

=cut

sub __bookIndexFromNumber {
	my ($bookNumber) = @_;
	my $index = int($bookNumber) - 1;
	die("Gutenberg book number '$bookNumber' is outside the expected range\n")
		if (($index < 0) || ($index >= scalar(@BOOK_CODES)));
	return $index;
}

sub __bookIndex {
	my ($node) = @_;
	my $text = $node->as_text;
	my ($bookNumber) = $text =~ /Book\s+(\d{2})/x;
	return unless (defined($bookNumber));
	return __bookIndexFromNumber($bookNumber);
}

sub __writeVerses {
	my ($html, $output) = @_;
	my $tree = HTML::TreeBuilder->new;
	$tree->parse_content($html);
	$tree->eof();

	my $file = IO::File->new($output, '>:encoding(UTF-8)')
		or die("Cannot open $output: $!\n");
	my $bookIndex;
	my $verseCount = 0;
	my $bookCount = 0;
	my %seenBooks;
	for my $node ($tree->look_down(_tag => qr/\A(?:a|h1|p)\z/x)) {
		my $nodeBookIndex;
		$nodeBookIndex = __bookIndex($node) if ($node->tag eq 'h1');
		if ($node->tag eq 'a' && defined($node->attr('id'))
			&& $node->attr('id') =~ /\ABook(\d{2})\z/x) {
			$nodeBookIndex = __bookIndexFromNumber($1);
		}
		if (defined($nodeBookIndex)) {
			$bookIndex = $nodeBookIndex;
			$bookCount++ unless ($seenBooks{$bookIndex}++);
			next;
		}

		next unless (defined($bookIndex));
		my $text = $node->as_text;
		my ($chapter, $verse) = $text =~ /\A\s*(\d+)[.:](\d+)\.\s*/x;
		next unless (defined($chapter) && defined($verse));
		$text =~ s/\A\s*\d+[.:]\d+\.\s*//x;
		$text =~ s/\s+/ /gx;
		$text =~ s/\s+\z//x;
		next if (length($text) == 0);
		printf {$file} "dr:%s:%d:%d::%s\n", $BOOK_CODES[$bookIndex], $chapter, $verse, $text;
		$verseCount++;
	}

	$tree->delete();
	$file->close() or die("Cannot close $output: $!\n");
	die("Expected 73 Gutenberg books, found $bookCount\n") unless ($bookCount == scalar(@BOOK_CODES));
	return $verseCount;
}

sub main {
	my $url = $DEFAULT_URL;
	my $output = 'data/static/dr-gutenberg.txt';
	return __usage() unless (GetOptions('url=s' => \$url, 'output=s' => \$output));
	my $html = __fetch($url);
	my $verseCount = __writeVerses($html, $output);
	printf("Wrote %d verses to %s\n", $verseCount, $output);
	return EXIT_SUCCESS;
}

exit(main()) unless (caller());
