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

package Chleb::Bible;
use strict;
use warnings;
use Moose;

=head1 NAME

Chleb::Bible - The Holy Bible

=head1 DESCRIPTION

Object representing one translation of The Holy Bible

=cut

extends 'Chleb::Bible::Base';

use Digest::CRC qw(crc32);
use HTTP::Status qw(:constants);
use List::Util qw(shuffle);
use Readonly;
use Scalar::Util qw(looks_like_number);
use Text::LevenshteinXS qw(distance);
use Time::HiRes ();

use Chleb::Bible::Backend;
use Chleb::Bible::Search::Query;
use Chleb::Bible::Verse;
use Chleb::Constants;
use Chleb::DI::Container;
use Chleb::Exception;

=head1 ATTRIBUTES

=over

=item C<id>

=cut

has id => (is => 'ro', isa => 'Str', lazy => 1, default => \&__makeId);

=item C<type>

=cut

has type => (is => 'ro', isa => 'Str', default => sub { 'bible' });

=item C<bookCount>

The count (number) of books in the bible.  Whilst most bibles will contain C<66> books,
please do B<not> assume so, because of the Apocrypha, or perhaps the entire translation
is of only one testament.

=cut

has bookCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeBookCount);

=item C<books>

Array of all books in the bible, in the order they appear within it.  Note that
this B<might> vary between translations!  Each entry is a L<Chleb::Bible::Book> object.

=cut

has books => (is => 'ro', isa => 'ArrayRef[Chleb::Bible::Book]', lazy => 1, default => \&__makeBooks);

=item C<verseCount>

The number of verses in this translation of the bible.  nb. that a typical bible contains C<31,102> verses,
but in some translations, this may vary, so please do not assume.

=cut

has verseCount => (is => 'ro', isa => 'Int', default => 31_102); # TODO: Hard-coded 31,102: works for "kjv", "asv" (canonical)

=item C<translation>

A short, lower-case word identifying the translation name.  This may be used in URLs and as an identifier.
For example: 'kjv', represents the King James Bible, aka Authorized Edition.

=cut

has translation => (is => 'ro', isa => 'Str', required => 1);

=back

=head1 PRIVATE ATTRIBUTES

=over

=item C<__backend>

The backend L<Chleb::Bible::Backend> object for this bible translation.  Users of the library should
never touch things within this object because the functionality may change without warning.

=cut

has __backend => (is => 'ro', isa => 'Chleb::Bible::Backend', lazy => 1, default => \&__makeBackend);

=back

=head1 METHODS

=over

=item C<BUILD>

Automatic build hook, called by the L<Moose> framework when this bible translation
is loaded.

=cut

sub BUILD {
	my ($self) = @_;

	# FIXME doesn't make sense now we have multiple bible translations,
	# superficially it works but will probably be highly unreliable.
	$self->dic->bible($self); # self registration

	return;
}

=item C<getBookByShortName($shortName, [$args])>

Return a L<Chleb::Bible::Book> object from L</books> given its C<$shortName>.
A fatal error occurs if the book does not exist or cannot be found.

If you want to avoid a fatal error and merely want a warning, pass a true value
in the key C<nonFatal> within the B<optional> C<$args> C<HASH>.

=cut

sub getBookByShortName {
	my ($self, $shortName, $args) = @_;

	my $closestBook;
	my $lowestDistance = $Chleb::Constants::UINT_MAX; # an impossibly high number, all mismatches will be lower
	my @books = shuffle(@{ $self->books }); # be fair; don't bias against books near the end of the bible
	foreach my $book (@books) {
		my $distance = distance($book->shortName, $shortName);
		if ($distance < $lowestDistance) {
			$lowestDistance = $distance;
			$closestBook = $book;
		}

		next unless ($book->equals($shortName));
		return $book;
	}

	my $errorMsg = "Short book name '$shortName' is not a book in the bible, did you mean "
	    . $closestBook->shortName . '?';

	if ($args->{nonFatal}) {
		$self->dic->logger->warn($errorMsg);
	} else {
		die Chleb::Exception->raise(HTTP_NOT_FOUND, $errorMsg);
	}

	return undef;
}

=item C<getBookByLongName($longName, [$args])>

Return a L<Chleb::Bible::Book> object from L</books> given its C<$shortName>.
A fatal error occurs if the book does not exist or cannot be found.

If you want to avoid a fatal error and merely want a warning, pass a true value
in the key C<nonFatal> within the B<optional> C<$args> C<HASH>.

=cut

sub getBookByLongName {
	my ($self, $longName, $args) = @_;

	$longName ||= '';
	my $closestBook;
	my $lowestDistance = $Chleb::Constants::UINT_MAX; # an impossibly high number, all mismatches will be lower
	foreach my $book (@{ $self->books }) {
		my $distance = distance($book->longName, $longName);
		if ($distance < $lowestDistance) {
			$lowestDistance = $distance;
			$closestBook = $book;
		}

		next if ($book->longName ne $longName);
		return $book;
	}

	my $errorMsg = "Long book name '$longName' is not a book in the bible, did you mean "
	    . $closestBook->longName . "?";

	if ($args->{nonFatal}) {
		$self->dic->logger->warn($errorMsg);
	} else {
		die Chleb::Exception->raise(HTTP_NOT_FOUND, $errorMsg);
	}

	return undef;
}

=item C<getBookByOrdinal($ordinal, [$args])>

Given a numeric C<$ordinal>, return that L<Chleb::Bible::Book> from
this translation of the bible.  Always make sure that it is less than
or equal to L</bookCount>.  nb. an ordinal to us always starts at C<1>,
not C<0>.  A special value, C<-1> indicates the last book in this translation
of the bible.

If the book is out of range, a fatal error occurs, unless the C<$args> C<HASH>
contains a true key by the name C<nonFatal>.

B<Don't assume> there are C<66> books in any translation of the bible!

=cut

sub getBookByOrdinal {
	my ($self, $ordinal, $args) = @_;

	$ordinal = $self->bookCount if ($ordinal == -1);

	if ($ordinal > $self->bookCount) {
		if ($args->{nonFatal}) {
			return undef;
		} else {
			die Chleb::Exception->raise(HTTP_NOT_FOUND, sprintf('Book ordinal %d out of range, there are %d books in the bible',
			    $ordinal, $self->bookCount));
		}
	}

	return $self->books->[$ordinal - 1];
}

=item C<getVerseByOrdinal($ordinal, [$args])>

Return the requested L<Chleb::Bible::Verse> object given a numeric C<$ordinal> relative to the
start of this translation of the bible, rather than the chapter, which is more commonplace.
This value is usually used for traversing the entire bible, rather than the normal chapter:verse
references.

C<$args> is passed through unmodified to L</getBookByShortName($shortName, [$args])> and
L<Chleb::Bible::Book/getChapterByOrdinal($ordinal, [$args])>.  It is otherwise not checked here.

Asking for a verse which is out of range causes a fatal error, therefore check L</verseCount>
before access.  Please note that ordinals start at C<1>, not C<0>.

=cut

sub getVerseByOrdinal {
	my ($self, $ordinal, $args) = @_;

	if (my $verseKey = $self->__backend->getVerseKeyByOrdinal($ordinal)) {
		my ($translation, $bookShortName, $chapterNumber, $verseNumber) = split(m/:/, $verseKey, 4);
		if (my $text = $self->__backend->getVerseDataByKey($verseKey)) {
			if (my $book = $self->getBookByShortName($bookShortName, $args)) {
				my $chapter = $book->getChapterByOrdinal($chapterNumber, $args);
				return Chleb::Bible::Verse->new({
					book    => $book,
					chapter => $chapter,
					ordinal => $verseNumber,
					text    => $text,
				});
			}
		} else {
			die "I don't think you can reach this";
		}
	}

	die Chleb::Exception->raise(HTTP_NOT_FOUND, sprintf("Verse %d not found in '%s'", $ordinal, $self->translation));
}

=item C<$newSearchQuery(@args)>

Create a new L<Chleb::Bible::Seach::Query> object.  See docs for this object to see
what attributes are available.  If C<@args> is not a C<HASH>, it will be assumed
to be text critereon only.

Special case, if C<bible> is not specified within the attributes, it will be assumed to
be this bible object.

=cut

sub newSearchQuery {
	my ($self, @args) = @_;

	return Chleb::Bible::Search::Query->new({ bible => $self, text => $args[0] })
	    if (scalar(@args) == 1);

	my %params = @args;
	$params{bible} = $self unless ($params{bible});
	return $self->_library->newSearchQuery(%params);
}

=item C<resolveBook($book)>

Resolve and return a L<Chleb::Bible::Book> object given any of the following C<$book> contents:

=over

=item *

An existing L<Chleb::Bible::Book> object, which will be returned unmodified

=item *

A numeric ordinal relative to the bible, B<not the Chapter>

=item *

a short book name, for example C<1Ki> or C<gen>.

=item *

A long book name, for example C<1 Kings> or C<Genesis>.

=back

A fatal error is thrown if the Book cannot be found.

=cut

sub resolveBook {
	my ($self, $book) = @_;

	unless (blessed($book)) {
		if (looks_like_number($book)) {
			$book = $self->getBookByOrdinal($book);
		} else {
			if (my $shortBook = $self->getBookByShortName($book, { nonFatal => 1 })) {
				return $shortBook;
			} else {
				$book = $self->getBookByLongName($book);
			}
		}
	}

	return $book;
}

=item C<fetch($book, $chapterOrdinal, $verseOrdinal)>

Fetch a L<Chleb::Bible::Verse>, given C<book>, which may be in any format accepted by L</resolveBook($book)>,
and a numeric C<$chapterOrdinal> and a numeric C<$verseOrdinal>.  If this does not exist, a fatal error will
be thrown.

nb. the verse ordinal is relative to the chapter.  Both ordinals start at C<1>, not C<0>.

=cut

sub fetch {
	my ($self, $book, $chapterOrdinal, $verseOrdinal) = @_;
	my $startTiming = Time::HiRes::time();

	$book = $self->resolveBook($book);
	my $chapter = $book->getChapterByOrdinal($chapterOrdinal);
	my $verse = $chapter->getVerseByOrdinal($verseOrdinal);

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));

	$self->dic->logger->debug(sprintf('%s sought in %dms', $verse->toString(), $msec));
	$verse->msec($msec);

	return $verse;
}

=item C<TO_JSON()>

Returns the JSON:API C<attributes> associated with this Book.

=cut

sub TO_JSON {
	my ($self) = @_;

	return {
		book_count           => $self->bookCount+0,
		book_names_long      => [ map { $_->longName } @{ $self->books } ],
		book_names_short     => [ map { $_->shortName } @{ $self->books } ],
		book_names_short_raw => [ map { $_->shortNameRaw } @{ $self->books } ],
		translation          => $self->translation,
		verse_count          => $self->verseCount+0,
	};
}

=back

=head1 PRIVATE METHODS

=over

=item C<__makeBackend()>

Lazy-initializer for L</__backend>, which creates the object
with a back-reference to ourselves (this object).

=cut

sub __makeBackend {
	my ($self) = @_;

	return Chleb::Bible::Backend->new({
		bible => $self,
	});
}

=item C<__makeBookCount()>

Lazy-initializer for L</bookCount>, which merely checks L</books> under the hood.

=cut

sub __makeBookCount {
	my ($self) = @_;
	return scalar(@{ $self->books });
}

=item C<__makeBooks>

Lazy-initializer for L</books>.

=cut

sub __makeBooks {
	my ($self) = @_;
	return $self->__backend->getBooks();
}

=item C<__makeId>

=cut

sub __makeId {
	my ($self) = @_;
	return join('/', $self->type, $self->translation);
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
