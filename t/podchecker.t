## no critic (RegularExpressions::RequireExtendedFormatting)
## no critic (Modules::RequireEndWithOne)
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

package main;
use strict;
use warnings;

use File::Find;
use File::Temp qw(tempfile);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

my @files;
find(
	{
		no_chdir => 1,
		wanted => sub {
			return unless (-f $File::Find::name);
			return unless ($File::Find::name =~ m/[.]pm\z/);
			push(@files, $File::Find::name);
		},
	},
	'lib',
);

@files = sort(@files);

plan tests => scalar(@files) + 2;

sub __runPodcheckerQuietly {
	my ($file) = @_;

	return system('/bin/sh', '-c', 'bin/maint/podchecker.sh "$1" >/dev/null 2>&1', 'sh', $file);
}

foreach my $file (@files) {
	is(system('bin/maint/podchecker.sh', $file), EXIT_SUCCESS, "podchecker $file");
}

{
	my ($fh, $file) = tempfile();
	print($fh "=head1 NAME\n\nvalid\n\n=cut\n");
	close($fh);
	is(__runPodcheckerQuietly($file), EXIT_SUCCESS, 'podchecker accepts =head1');
}

{
	my ($fh, $file) = tempfile();
	print($fh "=head2 NAME\n\ninvalid\n\n=cut\n");
	close($fh);
	isnt(__runPodcheckerQuietly($file), EXIT_SUCCESS, 'podchecker rejects lower-level headings');
}

exit(EXIT_SUCCESS);
