#!/usr/bin/env perl
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

package MediaTypeAcceptToContentTypeTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use POSIX qw(EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server;
use English qw(-no_match_vars);
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub testJsonAndHtml {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->new({
		items => [
			Chleb::Server::MediaType::Item->new({
				major => 'application',
				minor => 'json',
			}),
			Chleb::Server::MediaType::Item->new({
				major => 'text',
				minor => 'html',
			}),
		],
		original => '', # required but unused
	});

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, 'application/json');

	return EXIT_SUCCESS;
}

sub testHtmlAndJson {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->new({
		items => [
			Chleb::Server::MediaType::Item->new({
				major => 'text',
				minor => 'html',
			}),
			Chleb::Server::MediaType::Item->new({
				major => 'application',
				minor => 'json',
			}),
		],
		original => '', # required but unused
	});

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, 'text/html');

	return EXIT_SUCCESS;
}

sub testAcceptAnythingOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('*/*');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, $default);

	return EXIT_SUCCESS;
}

sub testAcceptJsonOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, 'application/json');

	return EXIT_SUCCESS;
}

sub testAcceptHtmlOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/html');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, 'text/html');

	return EXIT_SUCCESS;
}

sub testAcceptTextPlainOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/plain');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, '');

	return EXIT_SUCCESS;
}

sub testAcceptDefault {
	my ($self) = @_;
	plan tests => 1;

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType(undef, $default);
	is($contentType, $default);

	return EXIT_SUCCESS;
}

sub testAcceptTextAnythingOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('text/*');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, 'text/html');

	return EXIT_SUCCESS;
}

sub testAcceptApplicationAnythingOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/*');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, 'application/json');

	return EXIT_SUCCESS;
}

sub testAcceptApplicationJsonOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/json');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, 'application/json');

	return EXIT_SUCCESS;
}

sub testAcceptApplicationTypoOnly {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('application/jsom');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, '');

	return EXIT_SUCCESS;
}

sub testOnlyUnhandled {
	my ($self) = @_;
	plan tests => 1;

	my $mediaType = Chleb::Server::MediaType->parseAcceptHeader('audio/basic');

	my $default = $self->uniqueStr();
	my $contentType = Chleb::Server::MediaType::acceptToContentType($mediaType, $default);
	is($contentType, '');

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;

	my $dic = Chleb::DI::Container->instance;
	$dic->logger(Chleb::DI::MockLogger->new());

	return;
}

package main;
use strict;
use warnings;

exit(MediaTypeAcceptToContentTypeTests->new->run());
