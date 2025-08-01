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

package Chleb::DI::MockLogger;
use Moose;
use strict;
use warnings;

use Test::More;

has __messages => (isa => 'ArrayRef[Str]', is => 'ro', lazy => 1, default => sub { [] });

sub BUILD {
	return;
}

sub log {
	my ($self, $msg) = @_;
	push(@{ $self->__messages }, $msg);
	return unless ($ENV{TEST_VERBOSE});
	diag($msg);
	return;
}

sub isLogged {
	my ($self, $regEx) = @_;

	my $result = 0;
	foreach my $msg (@{ $self->__messages }) {
		if ($msg =~ m/$regEx/) {
			$result++;
			last;
		}
	}

	ok($result, "LOGGED: $regEx");
	return $result;
}

sub info {
	my ($self, $msg) = @_;
	return $self->log($msg);
}

sub error {
	my ($self, $msg) = @_;
	return $self->log($msg);
}

sub warn {
	my ($self, $msg) = @_;
	return $self->log($msg);
}

sub debug {
	my ($self, $msg) = @_;
	return $self->log($msg);
}

sub trace {
	my ($self, $msg) = @_;
	return $self->log($msg);
}

__PACKAGE__->meta->make_immutable;

1;
