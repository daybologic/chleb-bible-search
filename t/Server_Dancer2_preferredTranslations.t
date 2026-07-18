## no critic (Modules::RequireEndWithOne)
## no critic (Modules::RequireFilenameMatchesPackage)
## no critic (Modules::ProhibitMultiplePackages)
## no critic (Subroutines::ProtectPrivateSubs)
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

package Server_Dancer2_preferredTranslationsTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Server::Dancer2;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testCookiePreference {
	my ($self) = @_;
	plan tests => 8;

	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'asv'), [ 'asv' ], 'ASV cookie is used');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'kjv'), [ 'kjv' ], 'KJV cookie is used');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'asv,kjv'), [ 'asv', 'kjv' ], 'combined cookie is used');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'asv,kjv,asv'), [ 'asv', 'kjv' ], 'duplicate cookie values are ignored');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'all'), [ 'all' ], 'all cookie is used');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'default'), [], 'default cookie uses normal lookup');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'all,kjv'), [ 'all' ], 'all cookie overrides other translations');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(0, undef, 'invalid'), [], 'invalid cookie is ignored');

	return EXIT_SUCCESS;
}

sub testExplicitPreference {
	my ($self) = @_;
	plan tests => 3;

	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(1, 'kjv', 'asv'), [ 'kjv' ], 'explicit translation overrides cookie');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(1, 'asv,kjv', 'kjv'), [ 'asv', 'kjv' ], 'explicit translation list is preserved');
	is_deeply(Chleb::Server::Dancer2::__preferredTranslations(1, '', 'asv'), [], 'explicit empty translation suppresses cookie');

	return EXIT_SUCCESS;
}

package main;
use strict;
use warnings;
exit(Server_Dancer2_preferredTranslationsTests->new->run);
