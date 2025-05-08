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

package Chleb::Cache::Key::Value;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

has value => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeValue, init_arg => undef);

has __url => (is => 'rw', isa => 'Str', init_arg => undef);

has __contentType => (is => 'rw', isa => 'Str', init_arg => undef);

has __finalized => (is => 'rw', isa => 'Bool', default => 0, init_arg => undef);

use overload
	'""' => \&__getValue,
	'cmp' => sub {
		my ($a, $b) = @_;
		return 0; # FIXME: How do I do this?  In any case, I don't need to compare keys right now
	};

sub finalize {
	my ($self) = @_;

	die('cache key value has already been finalized') if ($self->__finalized);
	die('cannot finalize before URL is set') unless ($self->__url);
	die('cannot finalize before Content-Type is set') unless ($self->__contentType);

	$self->__finalized(1);

	return $self;
}

sub setUrl {
	my ($self, $url) = @_;

	die('url already set in cache key value') if ($self->__url);
	$self->__url($url);

	return $self;
}

sub setContentType {
	my ($self, $contentType) = @_;

	die('Content-Type already set in cache key value') if ($self->__contentType);
	$self->__contentType($contentType);

	return $self;
}

sub __getValue {
	my ($self) = @_;

	die('Access to unfinalized cache key value') unless ($self->__finalized);

	return $self->value;
}

sub __makeValue {
	my ($self) = @_;
	return $self->__url . '//' . $self->__contentType; # FIXME; better hashing
}

1;
