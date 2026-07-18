# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the Daybo Logic nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package Chleb::DI::Config;
use strict;
use warnings;
use Carp qw(croak);
use Moose;

extends 'Chleb::Bible::Base';

=head1 NAME

Chleb::DI::Config - runtime configuration reader

=head1 DESCRIPTION

Loads the YAML configuration files from a configuration directory and exposes
section/key lookups through C<get>.  The directory must contain C<main.yaml>;
optional sibling files such as C<contact.yaml>, C<features.yaml>, and
C<tokens.yaml> are merged over it when present.

=cut

use Chleb::Utils;
use Data::Dumper;
use English qw(-no_match_vars);
use IO::File;
use Readonly;
use YAML::XS 'LoadFile';

Readonly my @SPLIT_CONFIG_FILE_NAMES => qw(
	main.yaml
	contact.yaml
	features.yaml
	tokens.yaml
);

has __data => (is => 'ro', isa => 'HashRef', lazy => 1, builder => '__makeData');

=head1 ATTRIBUTES

=over

=item C<path>

Directory containing the runtime YAML configuration files.  This is a directory
path, not the path to C<main.yaml>.

=cut

has path => (is => 'ro', isa => 'Str', required => 1);

=back

=head1 METHODS

=over

=item C<BUILD()>

Moose construction hook.  Validates that L</path> is a directory and that it
contains C<main.yaml>, failing early when callers still pass a YAML filename.

=cut

sub BUILD {
	my ($self) = @_;

	if (!-d $self->path) {
		croak("Config path is not a directory: " . $self->path);
	}

	if (!-e $self->path . '/main.yaml') {
		croak("No config available (" . $self->path . '/main.yaml)');
	}

	return;
}

=item C<get($section, $key, $default, $isBoolean)>

Return a configuration value from the merged configuration data.  Missing
values return C<$default> and are logged as defaults.  When C<$isBoolean> is
true, the value is parsed using the project's boolean parser.

=cut

sub get {
	my ($self, $section, $key, $default, $isBoolean) = @_;

	my $defaultUsed = 0;
	my $value = $self->__get({
		section      => $section,
		key          => $key,
		default      => $default,
		isBoolean    => $isBoolean,
		pDefaultUsed => \$defaultUsed,
	});
	my $valuePrintable = (defined($value) && ref($value)) ? (Dumper $value) : $value;
	my $defaultPrintable = (defined($default) && ref($default)) ? (Dumper $default) : $default;
	my $msg = sprintf('[%s] %s: %s (default %s)', $section, $key, $valuePrintable, $defaultPrintable);

	my $level = 'trace';
	if ($defaultUsed) {
		$level = 'warn';
		$msg .= ' -- default used!  We recommend you set this value explicitly in your config!';
	}

	$self->dic->logger->$level($msg);
	return $value;
}

=back

=head1 PRIVATE METHODS

=over

=item C<__makeData()>

Lazy builder for the merged configuration hash.  It walks the configured YAML
file list from C<__configPaths> and recursively merges each file that exists.

=cut

# Invoked by Moose as the lazy builder for the __data attribute.
sub __makeData { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	my $data = { };

	foreach my $path (@{ $self->__configPaths }) {
		next unless (-e $path);
		__mergeHashRef($data, LoadFile($path) || { });
	}

	return $data;
}

=item C<__get($args)>

Internal implementation for C<get>.  It performs the actual section/key lookup,
fills missing keys in nested hashes from hash defaults, applies boolean parsing
when requested, and reports whether the outer default was used.

=cut

sub __get {
	my ($self, $args) = @_;
	my ($section, $key, $default, $isBoolean, $pDefaultUsed) =
		@{$args}{qw(section key default isBoolean pDefaultUsed)};

	if (defined($self->__data->{$section}->{$key})) {
		my $value = $self->__data->{$section}->{$key};

		if ($value && ref($value) eq 'HASH' && $default) {
			$self->dic->logger->trace("key '$key' found in section '$section': building ephemeral section");

			# section partially populated, construction an ephemeral section and populate keys from default, where supplied
			my %ephemeralSection = ( );
			my %allKeys = (
				%{ $self->__data->{$section}->{$key} },
				%$default,
			);

			foreach my $k (keys(%allKeys)) {
				my $v;
				if (exists($self->__data->{$section}->{$key}->{$k})) {
					$self->dic->logger->trace(Dumper $self->__data);
					$v = $self->__data->{$section}->{$key}->{$k};
					$self->dic->logger->trace("$section -> $key -> $k: '$v' (from real config)");
				} else {
					$v = $default->{$k};
					$self->dic->logger->trace("$section -> $key -> $k: '$v' (from default)");
				}

				$ephemeralSection{$k} = $v;
			}

			$self->dic->logger->trace('Ephemeral section content: ' . Dumper \%ephemeralSection);
			return \%ephemeralSection;
		}

		return Chleb::Utils::boolean($key, $value, $default, $Chleb::Utils::BOOLEAN_FLAG_EMPTY_IS_FALSE) if ($isBoolean);
		return $value;
	}

	$$pDefaultUsed = 1;
	return Chleb::Utils::boolean($key, $default, 0, $Chleb::Utils::BOOLEAN_FLAG_EMPTY_IS_FALSE) if ($isBoolean);
	return $default;
}

=item C<__configPaths()>

Return the ordered list of YAML files to merge for this configuration directory.
C<main.yaml> is loaded first, followed by the split files that may override or
extend it.

=cut

sub __configPaths {
	my ($self) = @_;

	my @paths = map { $self->path . '/' . $_ } @SPLIT_CONFIG_FILE_NAMES;
	return \@paths;
}

=item C<__mergeHashRef($target, $source)>

Recursively merge C<$source> into C<$target>.  Nested hash references are merged
key-by-key; all other values from C<$source> replace the value in C<$target>.

=cut

sub __mergeHashRef {
	my ($target, $source) = @_;

	foreach my $key (keys(%$source)) {
		if (
			exists($target->{$key})
			&& ref($target->{$key}) eq 'HASH'
			&& ref($source->{$key}) eq 'HASH'
		) {
			__mergeHashRef($target->{$key}, $source->{$key});
			next;
		}

		$target->{$key} = $source->{$key};
	}

	return $target;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
