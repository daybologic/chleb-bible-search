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

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

use English qw(-no_match_vars);
use JSON::PP ();
use IO::File ();

# Usage:
#	./quran_json_to_chleb.pl quran_pickthall_json > quran_pickthall.chleb
# Defaults to ./quran_pickthall_json if not supplied
my $dir = $ARGV[0] // 'quran_pickthall_json';

my $translation = 'pickthall';
my $book        = 'Quran';

my $json = JSON::PP->new->utf8->relaxed;

for (my $surah = 1; $surah <= 114; $surah++) {
	my $fn = "${dir}/chapter_${surah}.json";

	my $fh = IO::File->new($fn, 'r');
	die('Cannot open chapter JSON file for reading: ' . $fn . ': ' . $OS_ERROR . "\n")
	    unless ($fh);

	local $/ = undef;
	my $raw = <$fh>;
	$fh->close();

	my $aRef = $json->decode($raw);
	die("$fn: expected a JSON array\n") if (ref($aRef) ne 'ARRAY');

	my $verseCount = scalar(@$aRef);
	for (my $i = 0; $i < $verseCount; $i++) {
		my $ayah = $i + 1;
		my $verseText = $aRef->[$i];

		# Validation
		die("$fn: undefined text at ayah $ayah\n") unless (defined($verseText));
		die("$fn: empty text at ayah $ayah\n") if ($verseText eq '');

		# Normalization
		$verseText =~ s/\r\n/\n/g;
		$verseText =~ s/\r/\n/g;

		# Strip control chars (except whitespace we normalize next)
		$verseText =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g;

		# Collapse whitespace
		$verseText =~ s/\s+/ /g;
		$verseText =~ s/^\s+//;
		$verseText =~ s/\s+$//;

		print(join(':', $translation, $book, $surah, $ayah) . '::' . $verseText . "\n");
	}
}
