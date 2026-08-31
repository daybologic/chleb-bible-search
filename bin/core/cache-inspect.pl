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
use YAML::XS qw(LoadFile);

my $EXPECTED_FORMAT_VERSION = 8;
my $EXPECTED_FILE_VERSION = 17;
my $KIBIBYTE = 1024;
my $MEBIBYTE = 1024 * 1024;
my $KIBIBYTE_THRESHOLD = 512;
my $MEBIBYTE_THRESHOLD = 512 * 1024;

sub usage {
	print STDERR "Usage: $0 [cache-entry.bin]\n";
	exit 2;
}

sub formatNumber {
	my ($value) = @_;
	my ($whole, $fraction) = split(/[.]/x, "$value", 2);
	$whole =~ s{(?<=\d)(?=(\d{3})+(?!\d))}{,}gx;
	return defined($fraction) ? "$whole.$fraction" : $whole;
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

sub formatBytes {
	my ($bytes) = @_;
	if ($bytes > $MEBIBYTE_THRESHOLD) {
		return sprintf('%s MiB', formatNumber(sprintf('%.2f', $bytes / $MEBIBYTE)));
	} elsif ($bytes > $KIBIBYTE_THRESHOLD) {
		return sprintf('%s KiB', formatNumber(sprintf('%.2f', $bytes / $KIBIBYTE)));
	}
	return formatNumber($bytes) . ' bytes';
}

sub memcachedConfig {
	foreach my $path ('etc/main.yaml', '/etc/chleb-bible-search/main.yaml') {
		next unless (-f $path);
		my $config = eval { LoadFile($path) };
		next unless (ref($config) eq 'HASH');
		my $rateLimit = $config->{rate_limit};
		my $backend = ref($rateLimit) eq 'HASH' ? $rateLimit->{backend_memcached} : undef;
		next unless (ref($backend) eq 'HASH');
		my $servers = $backend->{servers} // [ '127.0.0.1:11211' ];
		$servers = [ $servers ] unless (ref($servers) eq 'ARRAY');
		return ($servers, $backend->{prefix} // 'chleb:dampen');
	}
	return ([ '127.0.0.1:11211' ], 'chleb:dampen');
}

sub inspectMemcached {
	my ($servers, $prefix) = memcachedConfig();
	my $client = eval {
		require Cache::Memcached;
		Cache::Memcached->import();
		Cache::Memcached->new({
			servers => $servers,
			compress_threshold => 10_000,
		});
	};
	if (!$client) {
		print "Memcached: unavailable\n";
		return;
	}

	my $stats = eval { $client->stats('items') };
	if (ref($stats) ne 'HASH') {
		print "Memcached: unavailable\n";
		return;
	}

	my (%keys, $bytes, $serverCount, $cachedumpSupported);
	$bytes = 0;
	$serverCount = 0;
	$cachedumpSupported = 1;
	foreach my $server (@$servers) {
		my $hostStats = $stats->{hosts}->{$server};
		next unless (ref($hostStats) eq 'HASH');
		$serverCount++;
		my $items = $hostStats->{items} // '';
		$items =~ s{\r}{}gx;
		my @slabs = $items =~ m{^STAT[ ]items:(\d+):number[ ]\d+$}mgx;
		next if (scalar(@slabs) == 0);
		my $socket = $client->sock_to_host($server);
		foreach my $slab (@slabs) {
			my @lines = eval { $client->run_command($socket, "stats cachedump $slab 1000000\r\n") };
			if (scalar(@lines) == 0 || grep { /^ERROR\r?\n?\z/x } @lines) {
				$cachedumpSupported = 0;
				next;
			}
			foreach my $line (@lines) {
				my ($key, $size) = $line =~ m{^ITEM[ ]([^ ]+)[ ]\[(\d+)[ ]b;}x;
				next unless (defined($key) && defined($size));
				next unless ($key eq $prefix || index($key, $prefix . ':') == 0);
				next if (exists($keys{$key}));
				$keys{$key} = 1;
				$bytes += $size;
			}
		}
	}

	print "Memcached prefix: $prefix\n";
	if (!$cachedumpSupported) {
		print "Memcached entries: unavailable (cachedump unsupported)\n";
		return;
	}
	if ($serverCount == 0) {
		print "Memcached: unavailable\n";
		return;
	}
	print "Memcached servers: " . formatNumber($serverCount) . "\n";
	print "Memcached entries: " . formatNumber(scalar(keys(%keys))) . "\n";
	print "Memcached size: " . formatBytes($bytes) . "\n";
	print "Memcached expired entries: not observable (Memcached omits expired items)\n";
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
	print "Entry files: " . formatNumber(scalar(@paths)) . "\n";
	if ($bytes > $MEBIBYTE_THRESHOLD) {
		printf("Total size: %s MiB\n", formatNumber(sprintf('%.2f', $bytes / $MEBIBYTE)));
	} elsif ($bytes > $KIBIBYTE_THRESHOLD) {
		printf("Total size: %s KiB\n", formatNumber(sprintf('%.2f', $bytes / $KIBIBYTE)));
	} else {
		print "Total bytes: " . formatNumber($bytes) . "\n";
	}
	print "Valid entries: " . formatNumber($counts{valid}) . "\n";
	print "Expired/incompatible entries: " . formatNumber($counts{expired}) . "\n";
	print "Corrupt/unreadable entries: " . formatNumber($counts{corrupt}) . "\n";
	if (scalar(keys(%groups)) > 0) {
		print "Valid entries by translation/kind:\n";
		foreach my $group (sort keys(%groups)) {
			print "  $group: " . formatNumber($groups{$group}) . "\n";
		}
	}
	inspectMemcached();
	return;
}

usage() if (scalar(@ARGV) > 1);
if (scalar(@ARGV) == 1) {
	inspectOne($ARGV[0]);
} else {
	inspectAll();
}

exit 0;
