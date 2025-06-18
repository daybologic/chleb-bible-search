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

package UptimeServerTests;
use strict;
use warnings;
use lib 't/lib';
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable::Local';

use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Chleb::DI::Container;
use Chleb::DI::MockLogger;
use Chleb::Server;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self, %params) = @_;

	if (EXIT_SUCCESS != $self->SUPER::setUp(%params)) {
		return EXIT_FAILURE;
	}

	$self->sut(Chleb::Server->new());

	return EXIT_SUCCESS;
}

sub testUptimeStatic {
	my ($self) = @_;

	my $uptime = 3661;
	$self->mock(ref($self->sut), '__getUptime', [$uptime]);

	my $json = $self->sut->__uptime();
	cmp_deeply($json, {
		data => [{
			attributes => {
				text => '1 hour, 1 minute, and 1 second',
				uptime => 3661,
			},
			id => ignore(),
			type => 'uptime',
		}],
		included => [ ],
		links => { },
	}, '__uptime: ' . $json->{data}->[0]->{attributes}->{text}) or diag(explain($json));

	return EXIT_SUCCESS;
}

sub testUptimeDynamic {
	my ($self) = @_;

	local $ENV{TEST_UNIQUE} = int(rand(1000));
	my $uptime = $self->unique % 60; # under one minute
	$self->mock(ref($self->sut), '__getUptime', [$uptime]);
	my $plural = ($uptime == 1) ? '' : 's';

	my $json = $self->sut->__uptime();
	cmp_deeply($json, {
		data => [{
			attributes => {
				text => sprintf('%s second%s', $uptime, $plural),
				uptime => $uptime,
			},
			id => ignore(),
			type => 'uptime',
		}],
		included => [ ],
		links => { },
	}, '__uptime: ' . $json->{data}->[0]->{attributes}->{text}) or diag(explain($json));

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(UptimeServerTests->new->run(n => ($ENV{TEST_QUICK} ? 1 : 250)));
