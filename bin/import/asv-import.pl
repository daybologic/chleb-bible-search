#!/usr/bin/env perl

package main;
use strict;
use warnings;

use Data::Dumper;
use English;
use IO::File;

my $globalVerseCount = 0;

sub processBook {
	my ($bible, $bible2, $bookShortName) = @_;
	my $fileName = sprintf('%s.txt', $bookShortName);
	if (my $fh = IO::File->new($fileName, 'r')) {
		my $bigLine = '';
		while (my $line = <$fh>) {
			$line =~ s/\n/ /;
			$bigLine .= $line;
		}
		my (@rawVerses) = split(m/\{(\d+):(\d+)\}/, $bigLine);
		warn scalar(@rawVerses) / 3 if ($bookShortName eq 'Rev');
		#print Dumper \@rawVerses;
		#die 'trap' if ($bookShortName eq 'Rev');
		my ($chapter, $verse) = (0, 0);
		my $verseCount = 0;
		my $mode = 0;
		for (my $i = 1; $i < scalar(@rawVerses); $i++) {
			if ($mode == 2) { # text
				my $text = $rawVerses[$i];
				$text =~ s/^\s+//;
				$text =~ s/\s+$//;
				if ($chapter > 0) {
					printf("asv:%s:%d:%d::%s\n", $bookShortName, $chapter, $verse, $text) if ($bookShortName eq 'Rev');

					my $key2 = sprintf("asv:%s:%d:%d", $bookShortName, $chapter, $verse);
					printf("key2: $key2\n") if ($key2 =~ m/^asv:/);
					if ($bible->{$bookShortName}->{$chapter}->{$verse}) {
						if (0) {
							warn(sprintf("'asv:%s:%d:%d' already exists: %s", $bookShortName, $chapter, $verse,
							    $bible->{$bookShortName}->{$chapter}->{$verse}));
						}
					} else {
						$bible->{$bookShortName}->{$chapter}->{$verse} = $text;
					}

					if ($bible2->{$key2}) {
						if ($bookShortName eq 'Rev') {
							die(sprintf("'%s' already exists:\n%s\n%s\n", $key2, $bible2->{$key2}, $text))
						}
					} else {
						$bible2->{$key2} = $text;
					}

					$verseCount++;
				}
				$mode = 0;
			} elsif ($mode == 0) {
				$chapter = $rawVerses[$i];
				printf("chapter %d\n", $chapter);
				$mode = 1;
			} elsif ($mode == 1) {
				$verse = $rawVerses[$i];
				printf("verse %d\n", $verse);
				$mode = 2;
			}
#			die $i if ($i == 7);
		}
		$fh->close();
		printf("verse count %d for %s\n", $verseCount, $fileName) if ($bookShortName eq 'Rev');
		$globalVerseCount += $verseCount;
	} else {
		printf(STDERR "'%s' -- %s\n", $fileName, $ERRNO);
		die('Must process all books!');
	}

	return;
}

sub writeBible {
	my ($bible) = @_;

	my $writtenVerseCount = 0;
	my $writtenBookCount = 0;
	my $revelationVerseCount = 0;
	my $fileName = 'asv.txt';
	if (my $fh = IO::File->new($fileName, 'w')) {
		foreach my $book (sort(keys(%$bible))) {
			$writtenBookCount++;
			foreach my $chapter (sort(keys(%{ $bible->{ $book } }))) {
				foreach my $verse (sort(keys(%{ $bible->{ $book }->{ $chapter } }))) {
					printf($fh "asv:%s:%d:%d::%s\n", $book, $chapter, $verse, $bible->{ $book }->{ $chapter }->{ $verse });
					$writtenVerseCount++;
					$revelationVerseCount++ if ($book eq 'Rev');
				}
			}
		}
	}

	printf("Written out %d books\n", $writtenBookCount);
	printf("Revelation verse count written (should be 404): %d\n", $revelationVerseCount);

	my $msg = sprintf("Wrote %d verses to '%s'", $writtenVerseCount, $fileName);
	if ($writtenVerseCount == 31_102) {
		printf("%s\n", $msg);
	} else {
		die("ERROR! $msg");
	}

	return;
}

sub writeBible2 {
	my ($bible2) = @_;

	my $writtenVerseCount = 0;
	my $writtenBookCount = 0;
	my $revelationVerseCount = 0;
	my $fileName = 'asv.txt';
	if (my $fh = IO::File->new($fileName, 'w')) {
		foreach my $key2 (sort(keys(%$bible2))) {
			printf($fh "%s::%s\n", $key2, $bible2->{$key2});
			$writtenVerseCount++;
		}
	}

	my $msg = sprintf("Bible2: Wrote %d verses to '%s'", $writtenVerseCount, $fileName);
	if ($writtenVerseCount == 31_102) {
		printf("%s\n", $msg);
	} else {
		die("ERROR! $msg");
	}

	return;
}

sub main {
	my %bible = ( );
	my %bible2 = ( );
	if (my $fh = IO::File->new('kjv.cvs', 'r')) { # yes this is a misnomer, and I am using the kjv index to process asv
		while (my $line = <$fh>) {
			chomp($line);
			my ($bookShortName, $numChapters) = split(m/;/, $line);
			printf("%s -> %d\n", $bookShortName, $numChapters) if ($bookShortName eq 'Rev');
			processBook(\%bible, \%bible2, $bookShortName);
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
	writeBible2(\%bible2);

	return 0;
}

exit(main()) unless (caller());
