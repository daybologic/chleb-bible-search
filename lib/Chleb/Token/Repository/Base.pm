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

package Chleb::Token::Repository::Base;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use Chleb::Exception;
use Chleb::Token;
use Chleb::Token::Repository;
use HTTP::Status qw(:constants);

has repo => (is => 'ro', isa => 'Chleb::Token::Repository', required => 1, lazy => 1, default => \&__makeRepo);

has _ttl => (is => 'ro', isa => 'Int', required => 1, lazy => 1, default => \&__makeTtl);

sub create {
	die('create must be overridden');
}

sub load {
	die('load must be overridden');
}

sub save {
	die('save must be overridden');
}

sub toString {
	my ($self) = @_;
	my @part = split(m/::/, ref($self));
	return $part[-1];
}

sub _valueValidate {
	my ($self, $value) = @_;
	return 1 if ($value =~ m/^[0-9a-f]{64}$/);

	die Chleb::Exception->raise(HTTP_UNAUTHORIZED, 'The sessionToken format must be SHA-256');
}

sub __makeRepo {
	my ($self) = @_;
	return Chleb::Token::Repository->new();
}

sub __makeTtl {
	my ($self) = @_;
	return $self->dic->config->get('session_tokens', 'ttl', $Chleb::Token::DEFAULT_TTL);
}

1;
