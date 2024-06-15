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

package Religion::Bible::Verses::Book;
use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Readonly;
use Religion::Bible::Verses::Chapter;
use Religion::Bible::Verses::Verse;

Readonly my $TRANSLATION => 'kjv';

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has ordinal => (is => 'ro', isa => 'Int');

has [qw(shortName longName)] => (is => 'ro', isa => 'Str');

has [qw(chapterCount verseCount)] => (is => 'ro', isa => 'Int');

has testament => (is => 'ro', isa => enum(['old', 'new']));

sub BUILD {
}

sub getVerseByOrdinal {
}

sub searchText {
	my ($self, $critereonText) = @_;
	my @verses;

	for (my $chapterOrdinal = 1; $chapterOrdinal <= $self->chapterCount; $chapterOrdinal++) {
		my $chapter = $self->getChapterByOrdinal($chapterOrdinal);

		for (my $verseOrdinal = 1; $verseOrdinal <= $chapter->verseCount; $verseOrdinal++) {
			my $verseKey = $self->__makeVerseKey($chapterOrdinal, $verseOrdinal);
			# TODO: You shouldn't access __backend here
			# but you need some more methods in the library to avoid it
			# Perhaps have a getVerseByKey in _library?
			my $text = $self->_library->__backend->getVerseDataByKey($verseKey);
			if ($text =~ m/$critereonText/i) {
				push(@verses, Religion::Bible::Verses::Verse->new({
					book    => $self,
					chapter => $chapter,
					ordinal => $verseOrdinal,
					text    => $text,
				}));
			}
		}
	}

	return \@verses;
}

sub toString {
	my ($self) = @_;
	return 'Book ' . $self->shortName;
}

sub getChapterByOrdinal {
	my ($self, $ordinal) = @_;
	my $chapter = Religion::Bible::Verses::Chapter->new({
		_library => $self->_library,
		book     => $self,
		ordinal  => $ordinal,
	});
}

sub __makeVerseKey {
	my ($self, $chapterOrdinal, $verseOrdinal) = @_;
	return join(':', $TRANSLATION, $self->shortName, $chapterOrdinal, $verseOrdinal);
}

1;
