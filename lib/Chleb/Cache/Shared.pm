#!/usr/bin/perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package Chleb::Cache::Shared;
use strict;
use warnings;
use Carp qw(croak);
use Moose;

use Crypt::xxHash qw(xxhash64_hex);
use English qw(-no_match_vars);
use File::Path qw(make_path);
use File::Temp qw(tempfile);
use Readonly;
use Storable qw(nstore_fd retrieve);

=head1 NAME

Chleb::Cache::Shared - small atomic Storable files in the shared cache

=head1 DESCRIPTION

Provides a generic filesystem cache for values which are safe to share between
workers and restarts.  Each value is stored independently beneath a named
cache kind, using a tiered xxHash64 path and an envelope containing the kind
and key for diagnostics.

=cut

=head1 ATTRIBUTES

=over

=item C<root>

The directory containing the shared cache kinds.

=cut

has root => (is => 'ro', isa => 'Str', required => 1);

=item C<logger>

Optional logger used for non-fatal cache IO warnings.

=cut

has logger => (is => 'ro', isa => 'Maybe[Object]', predicate => 'has_logger');

=item C<version>

The application or format version which invalidates entries after a deployment.

=cut

has version => (is => 'ro', isa => 'Str', required => 1);

=back

=cut

Readonly my $FORMAT_VERSION => 1;
Readonly my $KEY_PREFIX_LENGTH => 2;

=head1 METHODS

=over

=item C<get($kind, $key)>

Return a cached value, or C<undef> when the entry does not exist or is not a
valid entry for the requested kind and key.

=cut

sub get {
	my ($self, $kind, $key) = @_;
	my $path = $self->path($kind, $key);
	return unless (-f $path);

	my $entry;
	my $ok; $ok = eval { $entry = retrieve($path); 1; } or $ok = 0;
	if (!$ok) {
		$self->__warn("Cannot load shared cache entry from $path: $EVAL_ERROR");
		return;
	}
	return unless (
		ref($entry) eq 'HASH'
		&& ($entry->{format_version} // -1) == $FORMAT_VERSION
		&& ($entry->{version} // '') eq $self->version
		&& ($entry->{kind} // '') eq ($kind // '')
		&& ($entry->{key} // '') eq ($key // '')
	);

	return $entry->{value};
}

=item C<set($kind, $key, $value)>

Atomically write one value to the shared cache.  Cache failures are logged and
return false because the cache is an optimization, not a service dependency.

=cut

sub set { ## no critic (NamingConventions::ProhibitAmbiguousNames)
	my ($self, $kind, $key, $value) = @_;
	my $path = $self->path($kind, $key);
	my ($directory) = ($path =~ m{\A(.+)/[^/]+\z}x);
	my $ok = 1;
	my ($tempHandle, $tempPath);
	my $evalOk; $evalOk = eval {
		make_path($directory) unless (-d $directory);
		($tempHandle, $tempPath) = tempfile(DIR => $directory, UNLINK => 0);
		binmode($tempHandle, ':raw');
		nstore_fd({
			format_version => $FORMAT_VERSION,
			version => $self->version,
			kind => $kind,
			key => $key,
			value => $value,
		}, $tempHandle);
		$tempHandle->flush() if ($tempHandle->can('flush'));
		close($tempHandle) or croak("close($tempPath) failed: $ERRNO");
		rename($tempPath, $path) or croak("rename($tempPath -> $path) failed: $ERRNO");
		1;
	} or $evalOk = 0;
	if (!$evalOk) {
		$ok = 0;
		$self->__warn("Cannot store shared cache entry to $path: $EVAL_ERROR");
		close($tempHandle) if ($tempHandle);
		unlink($tempPath) if (defined($tempPath) && -f $tempPath);
	}

	return $ok;
}

=item C<path($kind, $key)>

Return the tiered path for one cache entry.  The digest includes the kind so
that a key cannot collide across cache categories.

=cut

sub path {
	my ($self, $kind, $key) = @_;
	my $digest = xxhash64_hex(($kind // '') . "\0" . ($key // ''), 0);
	return join('/', $self->root, $kind, substr($digest, 0, $KEY_PREFIX_LENGTH), "$digest.bin");
}

=item C<__warn($message)>

Log a non-fatal cache warning when a logger was supplied.

=cut

sub __warn {
	my ($self, $message) = @_;
	$self->logger->warn($message) if ($self->has_logger);
	return;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
