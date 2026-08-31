#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use File::Find qw(find);
use Storable qw(retrieve);

my $EXPECTED_FORMAT_VERSION = 8;
my $EXPECTED_FILE_VERSION = 17;

sub usage {
	print STDERR "Usage: $0 [cache-entry.bin]\n";
	exit 2;
}

sub readEntry {
	my ($path) = @_;
	my $entry;
	my $ok = eval {
		$entry = retrieve($path);
		1;
	};
	return ($ok, $entry, $@);
}

sub sourceIsCurrent {
	my ($source) = @_;
	return unless (ref($source) eq 'HASH');
	return unless (defined($source->{source_mtime}) && defined($source->{source_size}));

	my @sources = grep { -f $_ } (
		glob('data/*.sqlite.gz'),
		glob('/usr/share/chleb-bible-search/*.sqlite.gz'),
	);
	foreach my $path (@sources) {
		my @stat = stat($path);
		return 1 if (($stat[9] // -1) == $source->{source_mtime}
			&& ($stat[7] // -1) == $source->{source_size});
	}
	return 0;
}

sub entryStatus {
	my ($entry) = @_;
	return 'corrupt' unless (ref($entry) eq 'HASH');
	return 'expired' unless (($entry->{format_version} // -1) == $EXPECTED_FORMAT_VERSION
		&& ($entry->{file_version} // -1) == $EXPECTED_FILE_VERSION
		&& defined($entry->{translation})
		&& defined($entry->{kind})
		&& defined($entry->{key})
		&& ref($entry->{source}) eq 'HASH');
	return 'expired' unless sourceIsCurrent($entry->{source});
	return 'valid';
}

sub inspectOne {
	my ($path) = @_;
	my ($ok, $entry, $error) = readEntry($path);
	croak("Cannot read $path: $error") unless ($ok);
	local $Data::Dumper::Sortkeys = 1;
	print Dumper($entry);
	return;
}

sub cacheRoot {
	foreach my $path ('cache/shared', '/var/cache/chleb-bible-search/shared') {
		return $path if (-d $path);
	}
	croak("Cannot find a shared cache directory\n");
}

sub inspectAll {
	my $root = cacheRoot();
	my @paths;
	find({
		no_chdir => 1,
		wanted => sub {
			push(@paths, $File::Find::name) if (-f $_ && $_ =~ /[.]bin\z/x);
		},
	}, $root);

	my %counts = (valid => 0, expired => 0, corrupt => 0);
	my %groups;
	my $bytes = 0;
	foreach my $path (sort @paths) {
		$bytes += -s $path;
		my ($ok, $entry) = readEntry($path);
		if (!$ok) {
			$counts{corrupt}++;
			next;
		}
		my $status = entryStatus($entry);
		$counts{$status}++;
		if ($status eq 'valid') {
			my $group = join('/', $entry->{translation}, $entry->{kind});
			$groups{$group}++;
		}
	}

	print "Cache directory: $root\n";
	print "Entry files: " . scalar(@paths) . "\n";
	print "Total bytes: $bytes\n";
	print "Valid entries: $counts{valid}\n";
	print "Expired/incompatible entries: $counts{expired}\n";
	print "Corrupt/unreadable entries: $counts{corrupt}\n";
	if (scalar(keys(%groups)) > 0) {
		print "Valid entries by translation/kind:\n";
		foreach my $group (sort keys(%groups)) {
			print "  $group: $groups{$group}\n";
		}
	}
	return;
}

usage() if (scalar(@ARGV) > 1);
if (scalar(@ARGV) == 1) {
	inspectOne($ARGV[0]);
} else {
	inspectAll();
}

exit 0;
