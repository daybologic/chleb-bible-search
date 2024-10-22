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

package Chleb::Bible::Book;
use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints qw(enum);
use Readonly;
use Chleb::Bible::Chapter;
use Chleb::Bible::Verse;

has bible => (is => 'ro', isa => 'Chleb::Bible', required => 1);

has ordinal => (is => 'ro', isa => 'Int');

has [qw(shortName longName)] => (is => 'ro', isa => 'Str');

has [qw(chapterCount verseCount)] => (is => 'ro', isa => 'Int');

has testament => (is => 'ro', isa => enum(['old', 'new']));

has type => (is => 'ro', isa => 'Str', default => sub { 'book' });

has id => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeId);

sub BUILD {
}

sub getVerseByOrdinal {
	my ($self, $ordinal) = @_;

	$ordinal = $self->verseCount if ($ordinal == -1);

	my $bookVerseKey = join(':', $self->bible->translation, $self->shortName, $ordinal);
	if (my $verseKey = $self->bible->__backend->getVerseKeyByBookVerseKey($bookVerseKey)) {
		my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m/:/, $verseKey, 4);
		if (my $text = $self->bible->__backend->getVerseDataByKey($verseKey)) {
			my $chapter = $self->getChapterByOrdinal($chapterNumber);
			return Chleb::Bible::Verse->new({
				book    => $self,
				chapter => $chapter,
				ordinal => $verseNumber,
				text    => $text,
			});
		} else {
			die "I don't think you can reach this";
		}
	}

	die(sprintf('Verse %d not found in %s', $ordinal, $self->toString()));
}

sub getNext {
	my ($self) = @_;
	return $self->bible->getBookByOrdinal($self->ordinal + 1, { nonFatal => 1 });
}

sub getPrev {
	my ($self) = @_;

	return $self->bible->getBookByOrdinal($self->ordinal - 1, { nonFatal => 1 })
	    if ($self->ordinal > 1);

	return undef;
}

sub search {
	my ($self, $query) = @_;
	my @verses;

	my $critereonText = $query->text;
	CHAPTER: for (my $chapterOrdinal = 1; $chapterOrdinal <= $self->chapterCount; $chapterOrdinal++) {
		my $chapter = $self->getChapterByOrdinal($chapterOrdinal);

		for (my $verseOrdinal = 1; $verseOrdinal <= $chapter->verseCount; $verseOrdinal++) {
			my $verseKey = $self->__makeVerseKey($chapterOrdinal, $verseOrdinal);
			# TODO: You shouldn't access __backend here
			# but you need some more methods in the library to avoid it
			# Perhaps have a getVerseByKey in _library?
			my $text = $self->bible->__backend->getVerseDataByKey($verseKey);
			my $found = 0;

			if ($query->wholeword) {
				$found = 1 if ($text =~ m/\s+$critereonText,/i);
				$found = 1 if ($text =~ m/\s+$critereonText:/i);
				$found = 1 if ($text =~ m/\s+$critereonText;/i);
				$found = 1 if ($text =~ m/^$critereonText\s+/i);
				$found = 1 if ($text =~ m/\s+$critereonText\s+/i);
			} else {
				$found = 1 if ($text =~ m/$critereonText/i);
			}

			push(@verses, Chleb::Bible::Verse->new({
				book    => $self,
				chapter => $chapter,
				ordinal => $verseOrdinal,
				text    => $text,
			})) if ($found);

			last CHAPTER if (scalar(@verses) == $query->limit);
		}
	}

	return \@verses;
}

sub toString {
	my ($self) = @_;
	return $self->shortName;
}

sub TO_JSON {
	my ($self) = @_;

	return {
		testament => $self->testament,
		ordinal   => $self->ordinal,
	};
}

sub getChapterByOrdinal {
	my ($self, $ordinal, $args) = @_;

	$ordinal = $self->chapterCount if ($ordinal == -1);

	if ($ordinal > $self->chapterCount) {
		if ($args->{nonFatal}) {
			return undef;
		} else {
			die(sprintf('Chapter %d not found in %s', $ordinal, $self->toString()));
		}
	}

	return Chleb::Bible::Chapter->new({
		bible    => $self->bible,
		book     => $self,
		ordinal  => $ordinal,
	});
}

sub __makeVerseKey {
	my ($self, $chapterOrdinal, $verseOrdinal) = @_;
	return join(':', $self->bible->translation, $self->shortName, $chapterOrdinal, $verseOrdinal);
}

sub __makeId {
       my ($self) = @_;
       return lc($self->shortName);
}

1;
