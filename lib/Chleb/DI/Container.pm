# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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
use Chleb::Token::Repository::TempDir;
use Chleb::Utils::OSError::Mapper;

has bible => (is => 'rw'); # TODO: deprecated

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

TODO

=cut

has config => (is => 'rw', lazy => 1, builder => '_makeConfig');

=item C<exclusions>

TODO

=cut

has exclusions => (is => 'rw', lazy => 1, builder => '_makeExclusions');

=item C<tokenRepo>

TODO

=cut

has tokenRepo => (is => 'rw', lazy => 1, builder => '_makeTokenRepo');

=item C<errorMapper>

A Link to the L<Chleb::Utils::OSError::Mapper>.

There should only be one but for mocking purposes, it is not presently
a singleton.  There may be errors you want to remap in the test suite,
I am not sure at the moment.

The object is automagically constructed, once, on-demand using a hook
called L</_makeErrorMapper()>.

=cut

has errorMapper => (is => 'rw', lazy => 1, builder => '_makeErrorMapper');

=back

=head1 PROTECTED METHODS

=over

=item C<_makeLogger()>

The default lazy-initializer for L</logger>.

This can and may be overridden in a derivative of this object.
This is the recommended approach.

=cut

sub _makeLogger {
	foreach my $path ('etc/log4perl.conf', '/etc/chleb-bible-search/log4perl.conf') {
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

sub _makeConfig {
	my ($self) = @_;

	foreach my $path ('etc/main.yaml', '/etc/chleb-bible-search/main.yaml') {
		next unless (-e $path);
		return Chleb::DI::Config->new({ dic => $self, path => $path });
	}

	die('No config available!');
}

=item C<_makeExclusions()>

TODO

=cut

sub _makeExclusions {
	my ($self) = @_;
	return Chleb::Bible::Exclusions->new({ dic => $self });
}

=item C<_makeTokenRepo()>

TODO

=cut

sub _makeTokenRepo {
	my ($self) = @_;
	return Chleb::Token::Repository::TempDir->new({ dic => $self });
}

=item C<_makeErrorMapper()>

Constructs a L<Chleb::Utils::OSError::Mapper> for L</errorMapper>.

=cut

sub _makeErrorMapper {
	my ($self) = @_;
	return Chleb::Utils::OSError::Mapper->new({ dic => $self });
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
