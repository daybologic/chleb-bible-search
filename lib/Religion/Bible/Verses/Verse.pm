# Bible Query Verses Framework
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

package Religion::Bible::Verses::Verse;
use strict;
use warnings;
use Moose;

has book => (is => 'ro', isa => 'Religion::Bible::Verses::Book', required => 1);

has chapter => (is => 'ro', isa => 'Religion::Bible::Verses::Chapter', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

has text => (is => 'ro', isa => 'Str', required => 1);

has type => (is => 'ro', isa => 'Str', default => sub { 'verse' });

has id => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeId);

sub BUILD {
}

sub toString {
	my ($self) = @_;
	return sprintf('%s:%d - %s', $self->chapter->toString(), $self->ordinal, $self->text);
}

sub TO_JSON {
	my ($self) = @_;

	return {
		book    => $self->book->shortName,
		chapter => $self->chapter->ordinal,
		ordinal => $self->ordinal,
		text    => $self->text,
	};
}

sub __makeId {
	my ($self) = @_;
	return join('/', $self->book->ordinal, $self->chapter->ordinal, $self->ordinal);
}

1;
