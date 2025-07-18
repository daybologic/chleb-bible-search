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

package Chleb::Bible::Book;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

=head1 NAME

Chleb::Bible::Book - One book within a Chleb::Bible

=head1 DESCRIPTION

Object representing one Book within a translation of The Holy Bible

=cut

use Chleb::Bible::Chapter;
use Chleb::Bible::Verse;
use Chleb::Exception;
use HTTP::Status qw(:constants);
use Chleb::Type::Testament;
use Readonly;
use Scalar::Util qw(blessed);

=head1 ATTRIBUTES

=over

=item C<bible>

L<Chleb::Bible> object to which this C<Book> belongs.
B<required> and set by the creator of the object.  May not be associated with
another bible translation, once created.

=cut

has bible => (is => 'ro', isa => 'Chleb::Bible', required => 1);

=item C<ordinal>

Number in which the book appears in the associated L</bible>.
This cannot be changed.  Note that it is possible this changes between
bible translations.

=cut

has ordinal => (is => 'ro', isa => 'Int');

=item C<shortName>

The short name of this book within the bible, for example: C<gen> for 'Genesis'.
This cannot be changed.  This is normalized and always lower-case.  This should
be used within JSON and for REST/HTTP purposes.  For other display purposes, please
use L</shortNameRaw>.

=item C<shortNameRaw>

The short name of this book within the bible, for example C<Gen> for 'Genesis',
this may be used for display purposes and backend raw lookups.  For JSON, or REST
purposes, please use L</shortName> instead.

=item C<longName>

The long name of this book within the bible, for example: C<Genesis>.
This cannot be changed.

=cut

has [qw(shortNameRaw longName)] => (is => 'ro', isa => 'Str', required => 1);
has shortName => (is => 'ro', isa => 'Str', lazy => 1, init_arg => undef, default => \&__makeShortName);

=item C<chapterCount>

Integer; The number of chapters in the book (cannot be changed).

=item C<verseCount>

Integer; The number of verses in the book (cannot be changed).

=cut

has [qw(chapterCount verseCount)] => (is => 'ro', isa => 'Int', required => 1);

=item C<testament>

L<Chleb::Type::Testament>; which testament the Book belongs to.

May be either of:

=over

=item *

old

=item *

new

=back

This cannot be changed.

=cut

has testament => (is => 'ro', isa => 'Chleb::Type::Testament', required => 1, coerce => 1);

=item C<type>

The type of this object, which is typically used for JSON-generation purposes.
In this case, the type is always C<book>.  This cannot be changed.

=cut

has type => (is => 'ro', isa => 'Str', default => sub { 'book' });

=item C<id>

An opaque and unique identifier which may be used in JSON:API responses,
or in lookups.  This is unique per book but not across translations.

=cut

has id => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeId);

=back

=head1 METHODS

=over

=item C<getVerseByOrdinal($ordinal)>

Fetch a L<Chleb::Bible::Verse> by ordinal relative to the C<Book> which contains it (B<not the Chapter>).

As a special case, C<$ordinal> C<-1> is accepted to mean the last verse within the B<Book>.

If the C<Verse> cannot be found, a fatal error is thrown.

=cut

sub getVerseByOrdinal {
	my ($self, $ordinal) = @_;

	$ordinal = $self->verseCount if ($ordinal == -1);

	my $bookVerseKey = join(':', $self->bible->translation, $self->shortNameRaw, $ordinal);
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

=item C<getNext()>

Returns the next book in the series, relative to this one.
If there are no more books, a false value is returned.

=cut

sub getNext {
	my ($self) = @_;
	return $self->bible->getBookByOrdinal($self->ordinal + 1, { nonFatal => 1 });
}

=item C<getPrev()>

Returns the previous book in the series, relative to this one.
If there are no previous books, a false value is returned.

=cut

sub getPrev {
	my ($self) = @_;

	return $self->bible->getBookByOrdinal($self->ordinal - 1, { nonFatal => 1 })
	    if ($self->ordinal > 1);

	return undef;
}

=item C<search($query)>

Given C<$query> (L<Chleb::Bible::Search::Query>), run a search on B<this book only>.
Return an C<ARRAY> of matching L<Chleb::Bible::Verse> objects.  This array may be empty,
if nothing has matched.

=cut

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

=item C<randomVerse()>

Returns a random verse as a L<Chleb::Bible::Verse> object, from this Book.
Call this method as many times as desired.  No specific promises are made.

=cut

sub randomVerse {
	my ($self) = @_;
	return $self->getVerseByOrdinal(1 + int(rand($self->verseCount)));
}

=item C<toString()>

Return an opaque, loggable version of this book's name.
This name may not even be in the speaker's preferred language,
if this is a world-bible translation.  It B<must NOT> be used in most
places where L</shortName> is accepted.

=cut

sub toString {
	my ($self) = @_;
	return $self->shortNameRaw;
}

=item C<TO_JSON()>

Returns the JSON:API C<attributes> associated with this Book.

=cut

sub TO_JSON {
	my ($self) = @_;

	my $sampleVerse = $self->randomVerse();

	return {
		chapter_count  => $self->chapterCount+0,
		long_name      => $self->longName,
		ordinal        => $self->ordinal+0,
		sample_verse_text => $sampleVerse->text,
		sample_verse_chapter_ordinal => $sampleVerse->chapter->ordinal,
		sample_verse_ordinal_in_chapter => $sampleVerse->ordinal,
		short_name     => $self->shortName,
		short_name_raw => $self->shortNameRaw,
		testament      => $self->testament->value,
		translation    => $self->bible->translation,
		verse_count    => $self->verseCount+0,
	};
}

=item C<getChapterByOrdinal($ordinal, $args)>

TODO

=cut

sub getChapterByOrdinal {
	my ($self, $ordinal, $args) = @_;

	$ordinal = $self->chapterCount if ($ordinal == -1);

	if ($ordinal > $self->chapterCount) {
		if ($args->{nonFatal}) {
			return undef;
		} else {
			die Chleb::Exception->raise(HTTP_NOT_FOUND, sprintf('Chapter %d not found in %s', $ordinal, $self->toString()));
		}
	}

	return Chleb::Bible::Chapter->new({
		bible    => $self->bible,
		book     => $self,
		ordinal  => $ordinal,
	});
}

=item C<equals($otherBook)>

Given another book, which may be a L</shortName>, L</shortNameRaw> or a L<Chleb::Bible::Book>,
we determine if it is the same book as this one, regardless of translation, and return a true
or false value.

=cut

sub equals {
	my ($self, $otherBook) = @_;

	my $notABook = sub {
		die Chleb::Exception->raise(HTTP_INTERNAL_SERVER_ERROR, 'Not a book, in Book/equals()');
	};

	$notABook->() unless (defined($otherBook));

	if (my $otherBookObject = blessed($otherBook)) {
		if ($otherBookObject->isa('Chleb::Bible::Book')) {
			return 1 if ($self->_cmpAddress($self, $otherBook));
			return ($self->equals($otherBook->shortNameRaw));
		}

		$notABook->();
	}

	my $shortName = $otherBook; # otherBook is *NOT* an object, rename for simplicity, so we're not confused

	return 1 if ($self->shortNameRaw eq $shortName);

	if ($shortName =~ m/^(\d)(\w+)$/) {
		$shortName = "$1\u$2";
	} else {
		$shortName = "\u$shortName";
	}

	return ($self->shortNameRaw eq $shortName);
}

=back

=head1 PRIVATE METHODS

=over

=item C<__makeVerseKey($chapterOrdinal, $verseOrdinal)>

Helper which makes a key suitable for fetching verses from the backend.
TODO: Does this belong here?  I wonder.
Perhaps this would be better within the Backend, or as a Utils?

=cut

sub __makeVerseKey {
	my ($self, $chapterOrdinal, $verseOrdinal) = @_;
	return join(':', $self->bible->translation, $self->shortNameRaw, $chapterOrdinal, $verseOrdinal);
}

=item C<__makeId()>

Lazy-initializer for L</id>.

=cut

sub __makeId {
       my ($self) = @_;
       return join('/', $self->bible->translation, lc($self->shortName));
}

=item C<__makeShortName>

This sanity-checker inspects values as they are set in L</shortName>,
and forced them to be lower-case.

=cut

sub __makeShortName {
	my ($self) = @_;
	return lc($self->shortNameRaw);
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
