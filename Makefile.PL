#!/usr/bin/perl
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

use ExtUtils::MakeMaker;
#use ExtUtils::MakeMaker::Coverage;
use strict;
use warnings;

sub invoke {
	my ($command) = @_;

	my $rc = system($command);

	if ($rc == -1) {
		die("failed to execute: $!\n");
	} elsif ($rc & 127) {
		die(sprintf("child died with signal %d, %s coredump\n",
		    ($rc & 127), ($rc & 128) ? 'with' : 'without'));
	} else {
		my $exit_code = $rc >> 8;
		if ($exit_code != 0) {
			die("command exited with code $exit_code\n");
		} else {
			return 0;
		}
	}
}

invoke('bin/maint/pkg-info.sh'); # needs to run really early doors
invoke('bin/maint/synology.sh');
invoke('bin/maint/git-install-local-hooks.sh');
invoke('bin/maint/make-legal-notices.sh');

my @exeFiles = glob q('data/*.bin.gz');
push @exeFiles, glob q('bin/core/*.psgi');
push @exeFiles, glob q('bin/core/*.sh');
push @exeFiles, glob q('bin/core/*.pl');

WriteMakefile(
	NAME         => 'Chleb',
	VERSION_FROM => 'lib/Chleb/Generated/Info.pm', # finds $VERSION
	AUTHOR       => 'Rev. Duncan Ross Palmer, 2E0EOL (2e0eol@gmail.com)',
	ABSTRACT     => 'Chleb Bible Search',
	INSTALLVENDORSCRIPT => '/usr/share/chleb-bible-search',
	EXE_FILES    => \@exeFiles,

	clean => {
		FILES => [glob q('data/*.bin.gz')],
	},
	PREREQ_PM => {
		'Moose'            => 0,
		'Test::MockModule' => 0,
		'Test::More'       => 0,
		'UUID::Tiny'       => 0,
	}, BUILD_REQUIRES => {
		'DateTime::Format::Strptime' => 0,
		'Devel::Cover'    => 0,
		'Moose'           => 0,
		'Test::More'      => 0,
		'Readonly'        => 0,
		'Redis'           => 0,
		'Test::Deep'      => 0,
		'Test::Exception' => 0,
	},
);

package MY;

sub MY::postamble {
    return q~
deb :: pure_all
	sbuild -A

cover :: pure_all
	TEST_QUICK=1 HARNESS_PERL_SWITCHES=-MDevel::Cover make test && cover

http-test :: pure_all
	@bin/maint/run-functional-tests.sh

clean :: 
	rm -rf cover_db
	rm -f cache/*.bin
	cd data/ && make clean
	cd info/ && make clean

# Extend test target
test :: http-test

    ~;
}

1;
