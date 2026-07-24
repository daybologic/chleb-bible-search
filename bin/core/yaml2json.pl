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
use JSON;
use YAML::XS qw(Load LoadFile);

=head1 NAME

yaml2json.pl - convert Chleb YAML configuration to JSON

=head1 DESCRIPTION

Reads one YAML document from standard input, or one or more YAML files from the
command line, and writes the merged data structure as JSON.  File arguments are
merged in the order supplied so later files can override earlier files.

=head1 FUNCTIONS

=over

=item C<mergeHashRef($target, $source)>

Recursively merge C<$source> into C<$target>.  Nested hash references are merged
key-by-key; all other values from C<$source> replace the value in C<$target>.

=cut

sub mergeHashRef {
	my ($target, $source) = @_;

	foreach my $key (keys(%$source)) {
		if (
			exists($target->{$key})
			&& ref($target->{$key}) eq 'HASH'
			&& ref($source->{$key}) eq 'HASH'
		) {
			mergeHashRef($target->{$key}, $source->{$key});
			next;
		}

		$target->{$key} = $source->{$key};
	}

	return $target;
}

=item C<readStdin()>

Read a single YAML document from standard input and return it as a hash
reference.  Empty input is treated as an empty hash.

=cut

sub readStdin {
	my $yaml = '';
	while (my $input = <>) {
		$yaml .= $input;
	}

	return Load($yaml) || { };
}

=item C<readFiles()>

Read every YAML file named in C<@ARGV>, skipping paths that do not exist, and
return a recursively merged hash reference.

=cut

sub readFiles {
	my $data = { };

	foreach my $path (@ARGV) {
		next unless (-e $path);
		mergeHashRef($data, LoadFile($path) || { });
	}

	return $data;
}

=back

=cut

my $data = @ARGV ? readFiles() : readStdin();
print encode_json $data;
print "\n";

exit 0;
