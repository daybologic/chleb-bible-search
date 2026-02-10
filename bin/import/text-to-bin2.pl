#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (2E0EOL),
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

use Data::Dumper;
use English qw(-no_match_vars);
use IO::File;
use JSON;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Readonly;
use Storable qw(nstore);
use YAML::XS;

Readonly my $SPINE_FILE => './data/static/spine.yaml';
Readonly my $TRANSLATION => 'asv';

sub main {
	my $spine = loadSpine();
	return EXIT_FAILURE unless ($spine);

	my @books = ( );
	foreach my $book (@{ $spine->{books} }) {
		my $id = $book->{book_id};
		my $translation = $book->{translations}->{$TRANSLATION};
		if ($translation->{absent}) {
			printf(STDERR "book $id is absent in translation $TRANSLATION\n");
		} else {
			if ($translation->{ordinal}) {
				$books[ $translation->{ordinal} ] = $book;

				my $appendix = '';
				$appendix = ' (appendix)' if ($translation->{appendix});

				my $testament = '';
				if (my $t = $book->{testament}) {
					if ($t eq 'old') {
						$testament = ' (OT)';
					} elsif ($t eq 'new') {
						$testament = ' (NT)';
					} else {
						printf(STDERR "ERROR: Invalid testament '$t'\n");
						return EXIT_FAILURE;
					}
				}

				printf(STDERR "book $id found in translation $TRANSLATION with ordinal $translation->{ordinal}${testament}${appendix}\n");
			} else {
				printf(STDERR "ERROR: No ordinal for book $id\n");
				return EXIT_FAILURE;
			}
		}
	}

	return EXIT_SUCCESS;
}

sub loadSpine {
	my $yaml;
	my $fh = IO::File->new($SPINE_FILE, 'r');
	if (defined($fh)) {
		local $INPUT_RECORD_SEPARATOR = undef;  # slurp mode
		$fh->binmode(':encoding(UTF-8)');
		$yaml = $fh->getline();
		$fh->close();
	} else {
		print STDERR "Cannot open $SPINE_FILE: $ERRNO\n";
		return;
	}

	return if (length($yaml) == 0);
	return Load($yaml);
}

exit(main());
