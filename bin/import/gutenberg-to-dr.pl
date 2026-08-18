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

=head1 __chapterFromHeading($text)

Return the chapter number from a Gutenberg chapter heading, if C<$text> is a
chapter heading rather than verse content.

=cut

sub __chapterFromHeading {
	my ($text) = @_;
	my ($chapter) = $text =~ /\A\s*(?:[A-Za-z0-9 ]+)\s+Chapter\s+(\d+)\b/x;
	return $chapter if (defined($chapter));
	($chapter) = $text =~ /\A\s*\(Psalm\s+Chapter\s+(\d+)\s+according\b/x;
	return $chapter if (defined($chapter));
	return;
}

=head1 __bookIndexForNode($node)

Return a book index when C<$node> identifies the start of a Gutenberg book.

=cut

sub __bookIndexForNode {
	my ($node) = @_;
	return __bookIndex($node) if ($node->tag eq 'h1');
	return unless ($node->tag eq 'a' && defined($node->attr('id')));
	my ($bookNumber) = $node->attr('id') =~ /\ABook(\d{2})\z/x;
	return unless (defined($bookNumber));
	return __bookIndexFromNumber($bookNumber);
}

=head1 __verseParts($text)

Return the chapter, verse, and normalized text from a numbered verse paragraph.

=cut

sub __verseParts {
	my ($text) = @_;
	my ($chapter, $verse) = $text =~ /\A\s*(\d+)[.:](\d+)\.\s*/x;
	return unless (defined($chapter) && defined($verse));
	$text =~ s/\A\s*\d+[.:]\d+\.\s*//x;
	$text =~ s/\s+/ /gx;
	$text =~ s/\s+\z//x;
	return if (length($text) == 0);
	return ($chapter, $verse, $text);
}

=head1 __containsVerseParagraph($node)

Return true when a node contains a paragraph beginning with a verse marker.

=cut

sub __containsVerseParagraph {
	my ($node) = @_;
	my $paragraph = $node->look_down(
		_tag => 'p',
		sub {
			my ($child) = @_;
			my @parts = __verseParts($child->as_text);
			return scalar(@parts) > 0;
		},
	);
	return defined($paragraph);
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
	my $chapter;
	my $verseOrdinal = 0;
	my %seenBooks;
	for my $node ($tree->look_down(_tag => qr/\A(?:a|h1|p|div)\z/x)) {
		my $nodeBookIndex = __bookIndexForNode($node);
		if (defined($nodeBookIndex)) {
			$bookIndex = $nodeBookIndex;
			$chapter = undef;
			$verseOrdinal = 0;
			$bookCount++ unless ($seenBooks{$bookIndex}++);
			next;
		}

		next unless (defined($bookIndex));
	if ($node->tag eq 'div') {
		# A wrapper containing ordinary paragraphs will be visited through those
		# paragraphs; process only divs which hold an otherwise unvisited verse.
		next if (__containsVerseParagraph($node));
	}
		my $text = $node->as_text;
		my $headingChapter = __chapterFromHeading($text);
		if (defined($headingChapter)) {
			$verseOrdinal = 0 if (!defined($chapter) || $headingChapter != $chapter);
			$chapter = $headingChapter;
			next;
		}
		my ($markerChapter, $verse, $verseText) = __verseParts($text);
		next unless (defined($markerChapter));
		if ($verseOrdinal > 0 && defined($chapter) && $markerChapter > $chapter) {
			$chapter = $markerChapter;
			$verseOrdinal = 0;
		}
		my $outputChapter = $chapter // $markerChapter;
		$verseOrdinal++;
		printf {$file} "dr:%s:%d:%d::%s\n", $BOOK_CODES[$bookIndex], $outputChapter, $verseOrdinal, $verseText;
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
