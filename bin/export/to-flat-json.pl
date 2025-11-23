#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the project nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

package main;
use strict;
use warnings;
use lib 'lib';

use Chleb::Bible;
use English qw(-no_match_vars);
use Getopt::Std;
use JSON;
use POSIX qw(EXIT_SUCCESS);
use Readonly;

sub main {
	my (%opts);

	getopts('t:', \%opts) or die "Usage: $0 -t translation\n";

	die "Specify translation with -t\n" unless $opts{t};

	my $bible = Chleb::Bible->new({ translation => $opts{t} });
	my $verse = $bible->books->[0]->getVerseByOrdinal(1);

	my @versesForDump;
	my $count = 1;
	do {
		push(@versesForDump, {
			id => join('.', uc($verse->book->shortName), $verse->chapter->ordinal, $verse->ordinal),
			book => $verse->book->longName,
			chapter => $verse->chapter->ordinal,
			verse => $verse->ordinal,
			reference => sprintf('%s %d:%d', $verse->book->longName, $verse->chapter->ordinal, $verse->ordinal),
			text => $verse->text,
		});
		if ($verse = $verse->getNext()) {
			$count++;
		}
	} while ($verse);

	my $json = JSON->new->allow_nonref;
	my $json_text = $json->pretty->encode(\@versesForDump);
	print "$json_text\n";

	return EXIT_SUCCESS;

}

exit(main()) unless (caller());
