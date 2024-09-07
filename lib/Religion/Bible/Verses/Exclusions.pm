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

package Religion::Bible::Verses::Exclusions; # TODO: Should it be under Config:: ?  But that's under DI, which is a problem, hmm
use strict;
use warnings;
use Moose;

extends 'Religion::Bible::Verses::Base';

use English qw(-no_match_vars);
use Readonly;

Readonly my $SECTION_NAME => 'votd_exclude';

has refs => (is => 'ro', isa => 'ArrayRef[Religion::Bible::Verses::Verse]', lazy => 1, default => \&__makeRefs);
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
	my $term = '';
	my $length = 0;
	do {
		my $key = sprintf('term%d', ++$i);
		$term = $self->dic->config->get($SECTION_NAME, $key, '');
		if ($length = length($term)) {
			push(@terms, $term);
		}
	} while ($length > 0);

	$self->dic->logger->debug(sprintf('Loaded %d excluded VoTD terms', scalar(@terms)));
	return \@terms;
}

sub __makeRefs {
	my ($self) = @_;

	my @refs;
	my $i = 0;
	my $string = '';
	my $length = 0;
	do {
		my $key = sprintf('ref%d', ++$i);
		$string = $self->dic->config->get($SECTION_NAME, $key, '');
		if ($length = length($string)) {
			my ($bookName, $chapterOrdinal, $verseOrdinalStart, $verseOrdinalEnd);
			if ($string =~ m/^(\w+)\s+(\d+):(\d+)-(\d+)$/) {
				($bookName, $chapterOrdinal, $verseOrdinalStart, $verseOrdinalEnd) = ($1, $2, $3, $4);
				$self->dic->logger->trace("multi-part match: $string");
			} elsif ($string =~ m/^(\w+)\s+(\d+):(\d+)$/) {
				($bookName, $chapterOrdinal, $verseOrdinalStart) = ($1, $2, $3);
				$self->dic->logger->trace("single-part match: $string");
			} else {
				$self->dic->logger->error(sprintf('%s has been ignored because the format was not recognized', $key));
			}

			if ($bookName) {
				my $verse;
				$verseOrdinalEnd = $verseOrdinalStart if (!$verseOrdinalEnd || $verseOrdinalEnd > $verseOrdinalStart);
				$self->dic->logger->trace(sprintf('Loop %d -> %d', $verseOrdinalStart, $verseOrdinalEnd));
				for (my $verseOrdinal = $verseOrdinalStart; $verseOrdinal <= $verseOrdinalEnd; $verseOrdinal++) {
					$self->dic->logger->trace(sprintf('Loop iteration %d', $verseOrdinal));
					eval {
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
	} while ($length > 0);

	$self->dic->logger->debug(sprintf('Loaded %d excluded VoTD references', scalar(@refs)));
	return \@refs;
}

1;
