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
use Carp qw(croak);

use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

my $runtimeDirectory = 'chleb-bible-search';
my $servicePath = 'etc/chleb-bible-search.service';
my $dirsPath = 'debian/chleb-bible-search-core.dirs';

open(my $fh, '<', $servicePath) or croak("Cannot open $servicePath: $!");
my @lines = <$fh>;
close($fh);

my @runtimeDirectories;
foreach my $line (@lines) {
	chomp($line);
	next unless ($line =~ m/\ARuntimeDirectory=/);
	my ($value) = $line =~ m/\ARuntimeDirectory=(.+)\z/;
	push(@runtimeDirectories, $value);
}

is_deeply(
	\@runtimeDirectories,
	[$runtimeDirectory],
	"systemd creates /run/$runtimeDirectory for the FastCGI socket"
);

open($fh, '<', $dirsPath) or croak("Cannot open $dirsPath: $!");
@lines = <$fh>;
close($fh);

foreach my $line (@lines) {
	chomp($line);
}
my @volatileDirs = grep { m{\A/var/run/} } @lines;
is_deeply(
	\@volatileDirs,
	[],
	'Debian package does not ship volatile /var/run directories'
);

done_testing();
exit(EXIT_SUCCESS);
