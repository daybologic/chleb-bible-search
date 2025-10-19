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

package Chleb::Bible::Search::Query;
use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints;

extends 'Chleb::Bible::Base';

use Data::Dumper;
use Moose::Util::TypeConstraints qw(enum);
use Chleb::Bible::Search::Results;
use Chleb::Utils::SecureString;
use Readonly;
use Time::HiRes ();

Readonly our $SEARCH_RESULTS_LIMIT => 50;

subtype 'MooseTrimmedStr', as 'Str';
coerce 'MooseTrimmedStr', from 'Chleb::Utils::SecureString', via {
	__detaint($_)
};

has bible => (is => 'ro', isa => 'Chleb::Bible', required => 1);

has limit => (is => 'rw', isa => 'Int', default => $SEARCH_RESULTS_LIMIT);

has testament => (is => 'ro', isa => enum(['old', 'new']), required => 0);

has bookShortName => (is => 'ro', isa => 'Str', required => 0);

has text => (is => 'ro', isa => 'MooseTrimmedStr', required => 1, coerce => 1);

has wholeword => (is => 'rw', isa => 'Bool', default => 0);

sub BUILD {
}

sub setLimit {
	my ($self, $limit) = @_;
	$self->limit($limit);
	return $self;
}

sub setWholeword {
	my ($self, $wholeword) = @_;
	$self->wholeword($wholeword);
	return $self;
}

sub run {
	my ($self) = @_;
	my $startTiming = Time::HiRes::time();

	my @booksToQuery = ( );
	if ($self->bookShortName) {
		$booksToQuery[0] = $self->bible->getBookByShortName($self->bookShortName);
	} else {
		@booksToQuery = @{ $self->bible->books };
	}

	my @verses = ( );
	foreach my $book (@booksToQuery) {
		next if ($self->testament && $self->testament ne $book->testament);
		my $bookVerses = $book->search($self);
		push(@verses, @$bookVerses);
	}

	splice(@verses, $self->limit);

	my $results = Chleb::Bible::Search::Results->new({
		count  => scalar(@verses),
		query  => $self,
		verses => \@verses,
	});

	my $endTiming = Time::HiRes::time();
	my $msec = int(1000 * ($endTiming - $startTiming));
	$results->msec($msec);
	$self->dic->logger->debug(sprintf("Ran search %s and received %s in %dms", $self->toString(), $results->toString(), $msec));

	return $results;
}

sub translation {
	my ($self) = @_;
	return $self->bible->translation;
}

sub toString {
	my ($self) = @_;
	return sprintf("%s text '%s'", 'Query', $self->text);
}

sub __detaint {
	my ($value) = @_;
	my $mode = $Chleb::Utils::SecureString::MODE_TRAP
	    | $Chleb::Utils::SecureString::MODE_COERCE
	    | $Chleb::Utils::SecureString::MODE_STRIP_QUOTES
	    | $Chleb::Utils::SecureString::MODE_TRIM;

	my $secureString = Chleb::Utils::SecureString::detaint($value, $mode);
	return $secureString->value;
}

__PACKAGE__->meta->make_immutable;

1;
