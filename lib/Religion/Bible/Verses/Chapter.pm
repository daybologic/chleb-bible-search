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

package Religion::Bible::Verses::Chapter;
use strict;
use warnings;
use Moose;

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has book => (is => 'ro', isa => 'Religion::Bible::Verses::Book', required => 1);

has ordinal => (is => 'ro', isa => 'Int', required => 1);

has verseCount => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeVerseCount);

sub BUILD {
}

sub getVerseByOrdinal {
	my ($self, $ordinal) = @_;

	my $verseKey = $self->book->__makeVerseKey($self->ordinal, $ordinal);
	# TODO: You shouldn't access __backend here
	# but you need some more methods in the library to avoid it
	# Perhaps have a getVerseByKey in _library?
	if (my $text = $self->_library->__backend->getVerseDataByKey($verseKey)) {
		return Religion::Bible::Verses::Verse->new({
			book    => $self->book,
			chapter => $self,
			ordinal => $ordinal,
			text    => $text,
		});
	}

	die(sprintf('Verse %d not found in %s', $ordinal, $self->toString()));
}

sub toString {
	my ($self) = @_;
	return sprintf('%s %d', $self->book->shortName, $self->ordinal);
}

sub __makeVerseCount {
	my ($self) = @_;
	my $bookInfo = $self->_library->__backend->getBookInfoByShortName($self->book->shortName);
	die 'FIXME' unless ($bookInfo);
	my $count = $bookInfo->{v}->{ $self->ordinal };
	die("FIXME: $count") unless ($count);
	return $count;
}

1;
