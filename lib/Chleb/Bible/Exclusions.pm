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

package Chleb::Bible::Exclusions;
use strict;
use warnings;
use Moose;

extends 'Chleb::Bible::Base';

use English qw(-no_match_vars);
use Readonly;

Readonly my $SECTION_NAME => 'votd_exclude';

has refs => (is => 'ro', isa => 'ArrayRef[Chleb::Bible::Verse]', lazy => 1, default => \&__makeRefs);
has terms => (is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, default => \&__makeTerms);

sub BUILD {
	my ($self) = @_;
	$self->refs;
	$self->terms;
	return;
}

sub __makeTerms {
	my ($self) = @_;

	my @terms;
	my $i = 0;
	my $terms = $self->dic->config->get($SECTION_NAME, 'terms', [ ]);

	while (my $term = $terms->[$i++]) {
		push(@terms, $term);
	}

	$self->dic->logger->debug(sprintf('Loaded %d excluded VoTD terms', scalar(@terms)));
	return \@terms;
}

sub __makeRefs {
	my ($self) = @_;

	my @refs;
	my $i = 0;
	my $key = 'refs';
	my $refs = $self->dic->config->get($SECTION_NAME, $key, [ ]);

	while (my $ref = $refs->[$i++]) {
		my ($bookName, $chapterOrdinal, $verseOrdinalStart, $verseOrdinalEnd);
		if ($ref =~ m/^(\w+)\s+(\d+):(\d+)-(\d+)$/) {
			($bookName, $chapterOrdinal, $verseOrdinalStart, $verseOrdinalEnd) = ($1, $2, $3, $4);
		} elsif ($ref =~ m/^(\w+)\s+(\d+):(\d+)$/) {
			($bookName, $chapterOrdinal, $verseOrdinalStart) = ($1, $2, $3);
		} else {
			$self->dic->logger->error(sprintf('%s has been ignored because the format was not recognized', $key));
		}

		if ($bookName) {
			my $verse;
			$verseOrdinalEnd = $verseOrdinalStart if (!$verseOrdinalEnd || $verseOrdinalEnd < $verseOrdinalStart);
			for (my $verseOrdinal = $verseOrdinalStart; $verseOrdinal <= $verseOrdinalEnd; $verseOrdinal++) {
				eval {
					# FIXME: Deprecated!  This is highly unreliable and you need to find a new
					# way to access the library afore it goes away!
					$verse = $self->dic->bible->fetch($bookName, $chapterOrdinal, $verseOrdinal);
				};
				if (my $evalError = $EVAL_ERROR) {
					$self->dic->logger->error(sprintf('%s load failed: %s', $key, $evalError));
				} else {
					push(@refs, $verse);
				}
			}
		}
	}

	$self->dic->logger->debug(sprintf('Loaded %d excluded VoTD references', scalar(@refs)));
	return \@refs;
}

sub isExcluded {
	my ($self, $verse) = @_;
	return 1 if ($self->__isExcludedRef($verse));
	return $self->__isExcludedTerm($verse->text);
}

sub __isExcludedRef {
	my ($self, $verse) = @_;

	my $excluded = 0;
	foreach my $ref (@{ $self->refs }) {
		if ($verse->equals($ref)) {
			$excluded = 1;
			last;
		}
	}

	return $excluded;
}

sub __isExcludedTerm {
	my ($self, $text) = @_;

	my $excluded = 0;
	foreach my $term (@{ $self->terms }) {
		if (index($text, $term) > -1) {
			$excluded = 1;
			last;
		}
	}

	return $excluded;
}

__PACKAGE__->meta->make_immutable;

1;
