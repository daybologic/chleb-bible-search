# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package Religion::Bible::Verses::DI::Container;
use MooseX::Singleton;
use Moose;

use Log::Log4perl;
use Religion::Bible::Verses::DI::Config;
use Religion::Bible::Verses::Exclusions;

has logger => (is => 'rw', lazy => 1, builder => '_makeLogger');

has config => (is => 'rw', lazy => 1, builder => '_makeConfig');

has exclusions => (is => 'rw', lazy => 1, builder => '_makeExclusions');

sub _makeLogger {
	foreach my $path ('etc/log4perl.conf', '/etc/chleb-bible-search/log4perl.conf') {
		next unless (-e $path);
		Log::Log4perl->init($path);
		last;
	}

	return Log::Log4perl->get_logger('chleb');
}

sub _makeConfig {
	my ($self) = @_;

	foreach my $path ('etc/main.conf', '/etc/chleb-bible-search/main.conf') {
		next unless (-e $path);
		return Religion::Bible::Verses::DI::Config->new({ dic => $self, path => $path });
	}

	die('No config available!');
}

sub _makeExclusions {
	my ($self) = @_;
	return Religion::Bible::Verses::Exclusions->new({ dic => $self });
}

1;
