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

package DITimeTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::DI::Time;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;
	$self->sut(Chleb::DI::Time->new());
	return EXIT_SUCCESS;
}

sub testGetDefaultsToRealTime {
	my ($self) = @_;
	plan tests => 2;

	my $before = CORE::time();
	my $actual = $self->sut->get();
	my $after = CORE::time();

	cmp_ok($actual, '>=', $before, 'default time is not before call');
	cmp_ok($actual, '<=', $after, 'default time is not after call');

	return EXIT_SUCCESS;
}

sub testSetPinsTime {
	my ($self) = @_;
	plan tests => 2;

	is($self->sut->setMockedTime(1234), 1234, 'setMockedTime returns mocked time');
	is($self->sut->get(), 1234, 'get returns mocked time');

	return EXIT_SUCCESS;
}

sub testSleepAdvancesMockedTime {
	my ($self) = @_;
	plan tests => 2;

	$self->sut->setMockedTime(1234);
	is($self->sut->sleep(5), 1239, 'sleep returns advanced mocked time');
	is($self->sut->get(), 1239, 'sleep updates mocked time');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

exit(DITimeTests->new->run());
