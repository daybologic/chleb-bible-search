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
my $data = decode_json(<$fh>);
close $fh or die "close($infile): $OS_ERROR";

my @expected = (
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

my %have = map { $_ => 1 } keys %{$data};
my @missing = grep { !$have{$_} } @expected;

if (@missing) {
	print "MISSING:\n";
	print "$_\n" for @missing;
} else {
	print "All expected books present by these names.\n";
}

# Also show any unexpected keys
my %exp = map { $_ => 1 } @expected;
my @extra = grep { !$exp{$_} } sort keys %{$data};
if (@extra) {
	print "EXTRA KEYS:\n";
	print "$_\n" for @extra;
}
