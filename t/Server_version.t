## no critic (RegularExpressions::RequireExtendedFormatting)
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

package VersionServerTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Generated::Info;
use Chleb::Server::MediaType;
use Chleb::Server::Moose;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server::Moose->new());

	return EXIT_SUCCESS;
}

sub testDefaults {
	my ($self) = @_;

	my $json = $self->sut->__version();
	cmp_deeply($json, {
		data => [{
			attributes => {
				admin_email => 'example@example.org',
				admin_name => 'Unknown',
				build_arch => $Chleb::Generated::Info::BUILD_ARCH,
				build_host => $Chleb::Generated::Info::BUILD_HOST,
				build_os => $Chleb::Generated::Info::BUILD_OS,
				build_time => $Chleb::Generated::Info::BUILD_TIME,
				build_user => $Chleb::Generated::Info::BUILD_USER,
				changeset => $Chleb::Generated::Info::BUILD_CHANGESET,
				perl_version => $Chleb::Generated::Info::BUILD_PERL_VERSION,
				server_host => 'localhost',
				version => '2.5.1',
			},
			id => ignore(),
			type => 'version',
		}],
		included => [ ],
		links => { },
	}, '__version') or diag(explain($json));

	return EXIT_SUCCESS;
}

sub testHtml {
	my ($self) = @_;

	my $html = $self->sut->__version({
		accept => Chleb::Server::MediaType->parseAcceptHeader('text/html'),
	});
	like($html, qr{<a class="vn-link vn-home" href="/">home</a>}, '__version HTML has home link');
	like($html, qr{<table class="info-table">}, '__version HTML has info table');
	like($html, qr{<th>Version</th>}, '__version HTML has version header');
	like($html, qr{<td>2\.5\.1</td>}, '__version HTML has version value');
	like($html, qr{<th>Git changeset</th>}, '__version HTML has changeset header');
	like($html, qr{<td>\Q$Chleb::Generated::Info::BUILD_CHANGESET\E</td>}, '__version HTML has changeset value');
	like($html, qr{<th>Build time</th>}, '__version HTML has build time header');
	like($html, qr{<td>\Q$Chleb::Generated::Info::BUILD_TIME\E</td>}, '__version HTML has build time value');
	like($html, qr{<th>Build host</th>}, '__version HTML has build host header');
	like($html, qr{<td>\Q$Chleb::Generated::Info::BUILD_HOST\E</td>}, '__version HTML has build host value');
	like($html, qr{<th>Build OS</th>}, '__version HTML has build OS header');
	like($html, qr{<td>\Q$Chleb::Generated::Info::BUILD_OS\E</td>}, '__version HTML has build OS value');
	like($html, qr{<th>Build architecture</th>}, '__version HTML has build architecture header');
	like($html, qr{<td>\Q$Chleb::Generated::Info::BUILD_ARCH\E</td>}, '__version HTML has build architecture value');
	like($html, qr{<th>Build user</th>}, '__version HTML has build user header');
	like($html, qr{<td>\Q$Chleb::Generated::Info::BUILD_USER\E</td>}, '__version HTML has build user value');
	like($html, qr{<th>Perl version</th>}, '__version HTML has Perl version header');
	like($html, qr{<td>\Q$Chleb::Generated::Info::BUILD_PERL_VERSION\E</td>}, '__version HTML has Perl version value');
	like($html, qr{<th>Administrator</th>}, '__version HTML has administrator header');
	like($html, qr{<td>Unknown</td>}, '__version HTML has administrator value');
	like($html, qr{<th>Admin email</th>}, '__version HTML has admin email header');
	like($html, qr{<td>example\@example\.org</td>}, '__version HTML has admin email value');
	like($html, qr{<th>Server host</th>}, '__version HTML has server host header');
	like($html, qr{<td>localhost</td>}, '__version HTML has server host value');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(VersionServerTests->new->run());
