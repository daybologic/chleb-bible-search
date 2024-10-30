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

package Chleb::Bible::Verse;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

has book => (is => 'ro', isa => 'Chleb::Bible::Book', required => 1);

has chapter => (is => 'ro', isa => 'Chleb::Bible::Chapter', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

has text => (is => 'ro', isa => 'Str', required => 1);

has type => (is => 'ro', isa => 'Str', default => sub { 'verse' });

has msec => (is => 'rw', isa => 'Int', default => 0);

has id => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeId);

has continues => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeContinues);

has parental => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeParental);

sub BUILD {
}

sub getNext {
	my ($self) = @_;
	my $nextVerse = $self->chapter->getVerseByOrdinal($self->ordinal + 1, { nonFatal => 1 });
	unless ($nextVerse) { # Must have reached the end of the Chapter
		if (my $chapter = $self->chapter->getNext()) {
			$nextVerse = $chapter->getVerseByOrdinal(1);
		}
	}

	return $nextVerse;
}

sub getPrev {
	my ($self) = @_;

	if ($self->ordinal == 1) {
		if (my $chapter = $self->chapter->getPrev()) {
			return $chapter->getVerseByOrdinal(-1);
		}
	} else {
		return $self->chapter->getVerseByOrdinal($self->ordinal - 1, { nonFatal => 1 });
	}

	return undef;
}

sub equals {
	my ($self, $other) = @_;
	return ($self->id eq $other->id);
}

sub toString {
	my ($self, $verbose) = @_;
	my $str = sprintf('%s:%d', $self->chapter->toString(), $self->ordinal);
	$str = sprintf('%s - %s', $str, $self->text) if ($verbose);
	return $str;
}

sub TO_JSON {
	my ($self) = @_;

	return {
		book        => $self->book->shortName,
		chapter     => $self->chapter->ordinal,
		ordinal     => $self->ordinal,
		text        => $self->text,
		translation => $self->book->bible->translation,
	};
}

sub __makeId {
	my ($self) = @_;
	return join('/', $self->chapter->id, $self->ordinal);
}

sub __makeContinues {
	my ($self) = @_;
	my $lastChar = substr($self->text, -1);
	my @continuing = (',', ':', ';');
	for (my $i = 0; $i < scalar(@continuing); $i++) {
		if ($lastChar eq $continuing[$i]) {
			return 1;
		}
	}

	return 0;
}

sub __makeParental {
	my ($self) = @_;
	return $self->dic->exclusions->isExcluded($self);
}

1;
