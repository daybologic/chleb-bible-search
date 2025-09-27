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

package Chleb::TemplateProcessor;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Generated::Info;
use English qw(-no_match_vars);

has params => (isa => 'Maybe[HashRef]', is => 'rw', required => 0);

sub BUILD {
	my ($self) = @_;

	$self->params($self->__preProcess($self->params));

	return;
}

sub byLine {
	my ($self, $line) = @_;

	$line =~ s/__VERSION__/$Chleb::Generated::Info::VERSION/;
	$line =~ s/__BUILD_CHANGESET__/$Chleb::Generated::Info::BUILD_CHANGESET/;
	$line =~ s/__BUILD_USER__/$Chleb::Generated::Info::BUILD_USER/;
	$line =~ s/__BUILD_HOST__/$Chleb::Generated::Info::BUILD_HOST/;
	$line =~ s/__BUILD_OS__/$Chleb::Generated::Info::BUILD_OS/;
	$line =~ s/__BUILD_ARCH__/$Chleb::Generated::Info::BUILD_ARCH/;
	$line =~ s/__BUILD_PERL_VERSION__/$Chleb::Generated::Info::BUILD_PERL_VERSION/;
	$line =~ s/__BUILD_TIME__/$Chleb::Generated::Info::BUILD_TIME/;

	if ($self->params) {
		foreach my $k (keys(%{ $self->params })) {
			my $v = $self->params->{$k};
			$line =~ s/\Q$k\E/$v/;
		}
	}

	return $line;
}

sub __preProcess {
	my ($self, $params) = @_;

	my %newParams = ( );
	foreach my $oldK (keys(%$params)) {
		my $newK = "__${oldK}__";
		$newParams{$newK} = $params->{$oldK};
	}

	return \%newParams;
}

__PACKAGE__->meta->make_immutable;

1;
