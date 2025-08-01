#!/usr/bin/perl
# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

system('bin/maint/pkg-info.sh'); # needs to run really early doors
system('bin/maint/synology.sh');
system('bin/maint/git-install-local-hooks.sh');

my $exeFiles = [glob q('data/*.bin.gz')];
push(@$exeFiles, 'bin/core/app.psgi', 'bin/core/run.sh', 'bin/core/yaml2json.pl');

WriteMakefile(
	NAME         => 'Chleb',
	VERSION_FROM => 'lib/Chleb/Generated/Info.pm', # finds $VERSION
	AUTHOR       => 'Rev. Duncan Ross Palmer, 2E0EOL (2e0eol@gmail.com)',
	ABSTRACT     => 'Chleb Bible Search',
	INSTALLVENDORSCRIPT => '/usr/share/chleb-bible-search',
	EXE_FILES    => $exeFiles,

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

clean :: 
	rm -rf cover_db
	cd data/ && make clean
	cd info/ && make clean

    ~;
}

1;
