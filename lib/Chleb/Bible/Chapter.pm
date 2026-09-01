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

package Chleb::Bible::Chapter;
use strict;
use warnings;
use Moose;

use Carp qw(croak);
use Chleb::Exception;
use HTTP::Status qw(:constants);

has bible => (is => 'ro', isa => 'Chleb::Bible', required => 1);

has book => (is => 'ro', isa => 'Chleb::Bible::Book', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

has verseCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeVerseCount);

has type => (is => 'ro', isa => 'Str', default => sub { 'chapter' });

has id => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeId);

sub BUILD {
}

sub getVerseByOrdinal {
	my ($self, $ordinal, $args) = @_;

	if ($ordinal < 0) {
		$ordinal = $self->verseCount + $ordinal + 1;
	}

	my $verseKey = join(':', $self->bible->translation, $self->book->canonicalCode, $self->ordinal, $ordinal);
	if (my $text = $self->bible->getVerseDataByKey($verseKey)) {
		return Chleb::Bible::Verse->new({
			book           => $self->book,
			chapter        => $self,
			ordinal        => $ordinal,
			text           => $text,
			__queryContext => $args || {},
		});
	}

	return if ($args->{nonFatal});
	croak(Chleb::Exception->raise(HTTP_NOT_FOUND, sprintf('Verse %d not found in %s', $ordinal, $self->toString())));
}

sub getVerses {
	my ($self, $args) = @_;
	my $verses = $self->bible->getChapterVerseDataByKey($self->book->canonicalCode, $self->ordinal);
	return [ map {
		Chleb::Bible::Verse->new({
			book           => $self->book,
			chapter        => $self,
			ordinal        => $_->{verse_ordinal} + 0,
			text           => $_->{text},
			__queryContext => $args || {},
		});
	} @{ $verses // [ ] } ];
}

=head1 METHODS

=over

=item C<getFirstVerse([$args])>

Return the first verse present in this chapter, preserving gaps in a
translation's versification.

=item C<getLastVerse([$args])>

Return the last verse present in this chapter, preserving gaps in a
translation's versification.

=back

=cut

sub getFirstVerse {
	my ($self, $args) = @_;
	return $self->getVerses($args)->[0];
}

sub getLastVerse {
	my ($self, $args) = @_;
	my $verses = $self->getVerses($args);
	return $verses->[-1];
}

sub getNext {
	my ($self) = @_;

	my $nextChapter = $self->book->getChapterByOrdinal($self->ordinal + 1, { nonFatal => 1 });
	unless ($nextChapter) {
		if (my $book = $self->book->getNext()) {
			$nextChapter = $book->getChapterByOrdinal(1);
		}
	}

	return $nextChapter;
}

sub getPrev {
	my ($self) = @_;

	if ($self->ordinal == 1) {
		if (my $book = $self->book->getPrev()) {
			return $book->getChapterByOrdinal(-1);
		}
	} else {
		return $self->book->getChapterByOrdinal($self->ordinal - 1, { nonFatal => 1 });
	}

	return;
}

sub getPath {
	my ($self) = @_;
	return join('/', $self->book->shortName, $self->ordinal);
}

sub toString {
	my ($self) = @_;
	return sprintf('%s %d', $self->book->shortNameRaw, $self->ordinal);
}

sub TO_JSON {
	my ($self) = @_;

	return {
		book        => $self->book->shortName,
		ordinal     => $self->ordinal+0,
		translation => $self->book->bible->translation,
		verse_count => $self->verseCount+0,
	};
}

sub __makeVerseCount {
	my ($self) = @_;
	my $bookInfo = $self->bible->getBookInfoByShortName($self->book->canonicalCode);
	croak('FIXME: ' . $self->book->shortNameRaw) unless ($bookInfo);
	my $count = $bookInfo->{v}->{ $self->ordinal };
	croak(sprintf('Missing verse count for %s:%s chapter %d (available: %s)',
		$self->bible->translation, $self->book->canonicalCode, $self->ordinal,
		join(',', sort keys %{ $bookInfo->{v} // {} })))
	    unless (defined($count));
	return $count;
}

sub __makeId {
	my ($self) = @_;
	return join('/', $self->book->id, $self->ordinal);
}

__PACKAGE__->meta->make_immutable;

1;
