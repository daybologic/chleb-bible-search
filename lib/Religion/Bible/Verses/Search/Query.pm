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

package Religion::Bible::Verses::Search::Query;
use strict;
use warnings;
use Moose;

extends 'Religion::Bible::Verses::Base';

use Data::Dumper;
use Moose::Util::TypeConstraints qw(enum);
use Religion::Bible::Verses::Search::Results;

has _library => (is => 'ro', isa => 'Religion::Bible::Verses', required => 1);

has limit => (is => 'rw', isa => 'Int', default => 25);

has testament => (is => 'ro', isa => enum(['old', 'new']), required => 0);

has bookShortName => (is => 'ro', isa => 'Str', required => 0);

has text => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
}

sub setLimit {
	my ($self, $limit) = @_;
	$self->limit($limit);
	return $self;
}

sub run {
	my ($self) = @_;

	my @booksToQuery = ( );
	if ($self->bookShortName) {
		$booksToQuery[0] = $self->_library->getBookByShortName($self->bookShortName);
	} else {
		@booksToQuery = @{ $self->_library->books };
	}

	my @verses = ( );
	foreach my $book (@booksToQuery) {
		next if ($self->testament && $self->testament ne $book->testament);
		my $bookVerses = $book->search($self);
		push(@verses, @$bookVerses);
	}

	splice(@verses, $self->limit);

	my $results = Religion::Bible::Verses::Search::Results->new({
		count  => scalar(@verses),
		query  => $self,
		verses => \@verses,
	});

	$self->dic->logger->debug(sprintf("Ran search %s and received %s", $self->toString(), $results->toString()));

	return $results;
}

sub toString {
	my ($self) = @_;
	return sprintf("%s text '%s'", 'Query', $self->text);
}

1;
