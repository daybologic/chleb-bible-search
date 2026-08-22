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

package Chleb::DI::Container;
use MooseX::Singleton;
use Moose;
use Carp qw(croak);

=head1 NAME

Chleb::DI::Container - DIC

=head1 DESCRIPTION

Registry of "singletons" which may be replaced during any unit test.
This central registry should be populated by any module which needs
to use a specific library.  Objects such a loggers should only be accessed
via this "DIC" so that they may be reliably replaced during the test suites.

=cut

use Log::Log4perl;
use Chleb::Bible::Exclusions;
use Chleb::DI::Config;
use Chleb::DI::Time;
use Chleb::Token::Repository;
use Chleb::Utils::OSError::Mapper;
use Readonly;

=head1 CONSTANTS

=over

=item C<@DEFAULT_PATHS>

The paths we use to find the config files by default; hard-coded.
May be overridden by setting L</configPaths>.

=cut

Readonly our @DEFAULT_CONFIG_PATHS => (
	'etc',
	'/etc/chleb-bible-search',
);

has bible => (is => 'rw'); # TODO: deprecated

=back

=head1 ATTRIBUTES

=over

=item C<logger>

The logger object, which may be any object which accepts a series of
logger-level methods, such as C<warn>, C<debug>.

If not specified, a default hook brings in the L<Log::Log4perl> framework.
Otherwise, you should replace it with L<Chleb::DI::MockLogger> during a test.

=cut

has logger => (is => 'rw', lazy => 1, builder => '_makeLogger', clearer => 'resetLogger');

=item C<config>

The main runtime configuration object.  This is constructed from the first
available directory in L</configPaths> which contains C<main.yaml>, together
with split configuration files such as C<contact.yaml>, C<features.yaml>, and
C<tokens.yaml>.

=cut

has config => (is => 'rw', lazy => 1, builder => '_makeConfig');

=item C<exclusions>

The shared verse-exclusion rules used by verse-of-the-day and related lookups.

=cut

has exclusions => (is => 'rw', lazy => 1, builder => '_makeExclusions');

=item C<cache>

TODO

=cut

has cache => (is => 'rw', lazy => 1, builder => '_makeCache');

=item C<tokenRepo>

The session token repository facade.  It delegates to the configured token
backend implementations.

=cut

has tokenRepo => (is => 'rw', lazy => 1, builder => '_makeTokenRepo');

=item C<time>

The mockable wall-clock service.  Code which needs epoch time or sleeping should
use this instead of calling C<time> or C<sleep> directly.

=cut

has time => (is => 'rw', isa => 'Chleb::DI::Time', lazy => 1, builder => '_makeTime');

=item C<errorMapper>

A Link to the L<Chleb::Utils::OSError::Mapper>.

There should only be one but for mocking purposes, it is not presently
a singleton.  There may be errors you want to remap in the test suite,
I am not sure at the moment.

The object is automagically constructed, once, on-demand using a hook
called L</_makeErrorMapper()>.

=cut

has errorMapper => (is => 'rw', lazy => 1, builder => '_makeErrorMapper');

has __backendCache => (is => 'ro', isa => 'HashRef', default => sub { {} });

=item C<configPaths>

The paths in which we look for config files, defaulting to L</@DEFAULT_PATHS>.

=cut

has configPaths => (is => 'rw', isa => 'ArrayRef[Str]', lazy => 1, default => \&__makeConfigPaths);

=back

=head1 PROTECTED METHODS

=over

=item C<_makeLogger()>

The default lazy-initializer for L</logger>.

This can and may be overridden in a derivative of this object.
This is the recommended approach.

=cut

# Invoked by Moose as the lazy builder for the logger attribute.
sub _makeLogger { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;

	my $paths = $self->__makePathsFor('log4perl.conf');
	foreach my $path (@$paths) {
		next unless (-e $path);
		Log::Log4perl->init($path);
		last;
	}

	return Log::Log4perl->get_logger('chleb');
}

=item C<_makeConfig()>

The default lazy-initializer for L</config>.

Returns a L<Chleb::DI::Config>.

In this default initializtion, if the real config file cannt be found, the first access is fatal.

This can and may be overridden in a derivative of this object.
This is the recommended approach.

=cut

# Invoked by Moose as the lazy builder for the config attribute.
sub _makeConfig { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;

	my $configFileName = 'main.yaml';
	foreach my $dirName (@{ $self->configPaths }) {
		my $path = join('/', $dirName, $configFileName);
		next unless (-e $path);
		return Chleb::DI::Config->new({ dic => $self, path => $dirName });
	}

	croak("No config available ($configFileName)");
}

=item C<_makeExclusions()>

The default lazy-initializer for L</exclusions>.

=cut

# Invoked by Moose as the lazy builder for the exclusions attribute.
sub _makeExclusions { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return Chleb::Bible::Exclusions->new({ dic => $self });
}

=item C<_makeCache()>

TODO

=cut

sub _makeCache {
	my ($self) = @_;
	return Chleb::DI::Cache->new({ dic => $self });
}

=item C<_makeTokenRepo()>

The default lazy-initializer for L</tokenRepo>.

=cut

# Invoked by Moose as the lazy builder for the tokenRepo attribute.
sub _makeTokenRepo { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return Chleb::Token::Repository->new({ dic => $self });
}

=item C<_makeTime()>

The default lazy-initializer for L</time>.

=cut

# Invoked by Moose as the lazy builder for the time attribute.
sub _makeTime { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return Chleb::DI::Time->new();
}

=item C<_makeErrorMapper()>

Constructs a L<Chleb::Utils::OSError::Mapper> for L</errorMapper>.

=cut

# Invoked by Moose as the lazy builder for the errorMapper attribute.
sub _makeErrorMapper { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
	my ($self) = @_;
	return Chleb::Utils::OSError::Mapper->new({ dic => $self });
}

=item C<__makeConfigPaths()>

=cut

sub __makeConfigPaths {
	my ($self) = @_;
	return \@DEFAULT_CONFIG_PATHS;
}

=item C<__makePathsFor($fileName)>

=cut

sub __makePathsFor {
	my ($self, $fileName) = @_;

	my @fullPaths = ( );
	foreach my $dirName (@{ $self->configPaths }) {
		push(@fullPaths, join('/', $dirName, $fileName));
	}

	return \@fullPaths;
}

=back

=head1 METHODS

=over

=item C<backend($translation, $factory)>

Returns the cached L<Chleb::Bible::Backend> for C<$translation>.  On the first
call for a given translation the C<$factory> code reference is invoked to
construct the instance; every subsequent call within the same process returns
the previously constructed object without decompressing or probing the cache
file again.

=cut

sub backend {
	my ($self, $translation, $factory) = @_;
	$self->__backendCache->{$translation} //= $factory->();
	return $self->__backendCache->{$translation};
}

=item C<clearBackendCache()>

Discards all cached L<Chleb::Bible::Backend> instances.  Intended for use in
tests that need a fresh backend (e.g. after swapping data directories or
forcing a re-decompress).

=cut

sub clearBackendCache {
	my ($self) = @_;
	%{ $self->__backendCache } = ();
	return;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
