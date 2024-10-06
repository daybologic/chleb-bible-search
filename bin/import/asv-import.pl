#!/usr/bin/env perl

package main;
use strict;
use warnings;

use English;
use IO::File;

my $globalVerseCount = 0;

sub processBook {
	my ($bible, $bookShortName, $bookLongName) = @_;
	my $fileName = sprintf('%s.txt', $bookShortName);
	#$fileName = sprintf('%s.txt', $bookLongName) unless (-f $fileName);
	if (my $fh = IO::File->new($fileName, 'r')) {
		my $bigLine = '';
		while (my $line = <$fh>) {
			$line =~ s/\n/ /;
			$bigLine .= $line;
		}
		my (@rawVerses) = split(m/\{(\d+):(\d+)\}/, $bigLine);
		my ($chapter, $verse) = (0, 0);
		my $verseCount = 0;
		for (my $i = 0; $i < scalar(@rawVerses); $i++) {
			if ($i % 3 == 0) { # text
				my $text = $rawVerses[$i];
				$text =~ s/^\s+//;
				$text =~ s/\s+$//;
				if ($chapter > 0) {
					#printf("%s\n\n", $text);
					$verseCount++;
					$bible->{$bookShortName}->{$chapter}->{$verse} = $text;
				}
			} elsif ($i % 2 == 0) {
				$chapter = $rawVerses[$i];
				#printf("verse %d\n", $verse);
			} else {
				$verse = $rawVerses[$i];
				#printf("chapter %d\n", $chapter);
			}
		}
		$fh->close();
		printf("verse count %d for %s\n", $verseCount, $fileName);
		$globalVerseCount += $verseCount;
	} else {
		printf(STDERR "'%s' -- %s\n", $fileName, $ERRNO);
		die('Must process all books!');
	}

	return;
}

sub writeBible {
	my ($bible) = @_;

	if (my $fh = IO::File->new('asv.txt', 'w')) {
		foreach my $book (sort(keys(%$bible))) {
			foreach my $chapter (sort(keys(%{ $bible->{ $book } }))) {
				foreach my $verse (sort(keys(%{ $bible->{ $book }->{ $chapter } }))) {
					printf($fh "asv:%s:%d:%d::%s\n", $book, $chapter, $verse, $bible->{ $book }->{ $chapter }->{ $verse });
				}
			}
		}
	}

	return;
}

sub main {
	my %bible = ( );
	if (my $fh = IO::File->new('kjv.cvs', 'r')) { # yes this is a misnomer, and I am using the kjv index to process asv
		while (my $line = <$fh>) {
			chomp($line);
			my ($bookShortName, $numChapters, $bookLongName) = split(m/;/, $line);
			printf("%s -> %d\n", $bookShortName, $numChapters);
			processBook(\%bible, $bookShortName, $bookLongName);
		}
		$fh->close();
	} else {
		printf(STDERR "ERROR: $ERRNO");
		return 1;
	}

	printf("global verse count %d\n", $globalVerseCount);
	printf("Gen 1:1 %s\n", $bible{Gen}->{1}->{1});
	printf("Rev 22:21 %s\n", $bible{Rev}->{22}->{21});

	die("Verse count wrong!  Must be 31,102: $globalVerseCount") if ($globalVerseCount != 31_102);

	writeBible(\%bible);

	return 0;
}

exit(main()) unless (caller());
