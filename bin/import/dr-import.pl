#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

use strict;
use warnings;
use English qw(-no_match_vars);
use JSON::PP qw(decode_json);

my $infile = shift @ARGV // 'EntireBible-DR.json';

open my $fh, '<:raw', $infile or die "open($infile): $OS_ERROR";
local $INPUT_RECORD_SEPARATOR;
my $json_text = <$fh>;
close $fh or die "close($infile): $OS_ERROR";

my $data = decode_json($json_text);

# Canonical 73-book Catholic order (Douay-Rheims)
my @book_order = (
	'Genesis','Exodus','Leviticus','Numbers','Deuteronomy',
	'Josue','Judges','Ruth','1 Kings','2 Kings','3 Kings','4 Kings',
	'1 Paralipomenon','2 Paralipomenon','1 Esdras','2 Esdras',
	'Tobias','Judith','Esther','Job','Psalms','Proverbs','Ecclesiastes','Canticles',
	'Wisdom','Ecclesiasticus',
	'Isaias','Jeremias','Lamentations','Baruch','Ezechiel','Daniel',
	'Osee','Joel','Amos','Abdias','Jonas','Micheas','Nahum','Habacuc','Sophonias','Aggeus','Zacharias','Malachias',
	'1 Machabees','2 Machabees',
	'Matthew','Mark','Luke','John','Acts',
	'Romans','1 Corinthians','2 Corinthians','Galatians','Ephesians','Philippians','Colossians',
	'1 Thessalonians','2 Thessalonians','1 Timothy','2 Timothy','Titus','Philemon',
	'Hebrews','James','1 Peter','2 Peter','1 John','2 John','3 John','Jude',
	'Apocalypse',
);

my %book_alias = (
	'Canticles' => 'Canticle of Canticles',
	'Canticle of Canticles' => 'Canticles',
	'Apocalypse' => 'Revelation',
	'Revelation' => 'Apocalypse',
);

# Normalise: if one alias exists and the other doesn't, copy it over
for my $a (keys %book_alias) {
	my $b = $book_alias{$a};
	if (exists $data->{$a} && !exists $data->{$b}) {
		$data->{$b} = $data->{$a};
	}
}

# Map DR book names to your abbreviations
my %abbr = (
	'Genesis' => 'Gen',
	'Exodus' => 'Exo',
	'Leviticus' => 'Lev',
	'Numbers' => 'Num',
	'Deuteronomy' => 'Deu',
	'Josue' => 'Josh',
	'Judges' => 'Judg',
	'Ruth' => 'Ruth',
	'1 Kings' => '1Ki',
	'2 Kings' => '2Ki',
	'3 Kings' => '3Ki',
	'4 Kings' => '4Ki',
	'1 Paralipomenon' => '1Ch',
	'2 Paralipomenon' => '2Ch',
	'1 Esdras' => 'Ezr',
	'2 Esdras' => 'Neh',
	'Tobias' => 'Tob',
	'Judith' => 'Jdt',
	'Esther' => 'Est',
	'Job' => 'Job',
	'Psalms' => 'Psa',
	'Proverbs' => 'Pro',
	'Ecclesiastes' => 'Ecc',
	'Canticle of Canticles' => 'Song',
	'Canticles' => 'Song',
	'Wisdom' => 'Wis',
	'Ecclesiasticus' => 'Sir',
	'Isaias' => 'Isa',
	'Jeremias' => 'Jer',
	'Lamentations' => 'Lam',
	'Baruch' => 'Bar',
	'Ezechiel' => 'Eze',
	'Daniel' => 'Dan',
	'Osee' => 'Hos',
	'Joel' => 'Joe',
	'Amos' => 'Amo',
	'Abdias' => 'Oba',
	'Jonas' => 'Jon',
	'Micheas' => 'Mic',
	'Nahum' => 'Nah',
	'Habacuc' => 'Hab',
	'Sophonias' => 'Zep',
	'Aggeus' => 'Hag',
	'Zacharias' => 'Zec',
	'Malachias' => 'Mal',
	'1 Machabees' => '1Ma',
	'2 Machabees' => '2Ma',
	'Matthew' => 'Mat',
	'Mark' => 'Mark',
	'Luke' => 'Luke',
	'John' => 'John',
	'Acts' => 'Acts',
	'Romans' => 'Rom',
	'1 Corinthians' => '1Co',
	'2 Corinthians' => '2Co',
	'Galatians' => 'Gal',
	'Ephesians' => 'Eph',
	'Philippians' => 'Phi',
	'Colossians' => 'Col',
	'1 Thessalonians' => '1Th',
	'2 Thessalonians' => '2Th',
	'1 Timothy' => '1Ti',
	'2 Timothy' => '2Ti',
	'Titus' => 'Tit',
	'Philemon' => 'Phile',
	'Hebrews' => 'Heb',
	'James' => 'Jam',
	'1 Peter' => '1Pe',
	'2 Peter' => '2Pe',
	'1 John' => '1Jo',
	'2 John' => '2Jo',
	'3 John' => '3Jo',
	'Jude' => 'Jud',
	'Apocalypse' => 'Rev',
);

# If the JSON uses Revelation instead of Apocalypse (or vice-versa), handle both.
if (!exists $data->{'Apocalypse'} && exists $data->{'Revelation'}) {
	$book_order[-1] = 'Revelation';
}

BOOK:
for my $book (@book_order) {
	next BOOK if !exists $data->{$book}; # skip if absent
	my $book_abbr = $abbr{$book} // die "No abbreviation mapping for book: $book";

	my $chapters = $data->{$book};
	for my $ch (sort { $a <=> $b } keys %{$chapters}) {
		my $verses = $chapters->{$ch};
		for my $vs (sort { $a <=> $b } keys %{$verses}) {
			my $text = $verses->{$vs};

			# Clean up: ensure it's a single line (just in case)
			$text =~ s/\R/ /g;

			print "dr:${book_abbr}:${ch}:${vs}::${text}\n";
		}
	}
}
