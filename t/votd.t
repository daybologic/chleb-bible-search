#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

package VotdTests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use POSIX qw(EXIT_SUCCESS);
use Religion::Bible::Verses;
use Religion::Bible::Verses::DI::MockLogger;
use Test::Deep qw(all cmp_deeply isa methods re ignore);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Religion::Bible::Verses->new());
	$self->__mockLogger();

	return EXIT_SUCCESS;
}

sub test {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->votd();
	cmp_deeply($verse, all(
		isa('Religion::Bible::Verses::Verse'),
		methods(
			book    => isa('Religion::Bible::Verses::Book'),
			chapter => isa('Religion::Bible::Verses::Chapter'),
			ordinal => re(qr/^\d+$/),
			text    => ignore(),
		),
	), 'verse inspection') or diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub testV2 {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->votd({ version => 2, when => '2024-08-19T12:00:00+0100' });
	cmp_deeply($verse, [
		all(
			isa('Religion::Bible::Verses::Verse'),
			methods(
				book    => isa('Religion::Bible::Verses::Book'),
				chapter => isa('Religion::Bible::Verses::Chapter'),
				ordinal => 11,
				text    => 'For the grace of God that bringeth salvation hath appeared to all men,',
			),
		),
		all(
			isa('Religion::Bible::Verses::Verse'),
			methods(
				book    => isa('Religion::Bible::Verses::Book'),
				chapter => isa('Religion::Bible::Verses::Chapter'),
				ordinal => 12,
				text    => 'Teaching us that, denying ungodliness and worldly lusts, we should live soberly, righteously, and godly, in this present world;',
			),
		),
		all(
			isa('Religion::Bible::Verses::Verse'),
			methods(
				book    => isa('Religion::Bible::Verses::Book'),
				chapter => isa('Religion::Bible::Verses::Chapter'),
				ordinal => 13,
				text    => 'Looking for that blessed hope, and the glorious appearing of the great God and our Saviour Jesus Christ;',
			),
		),
		all(
			isa('Religion::Bible::Verses::Verse'),
			methods(
				book    => isa('Religion::Bible::Verses::Book'),
				chapter => isa('Religion::Bible::Verses::Chapter'),
				ordinal => 14,
				text    => 'Who gave himself for us, that he might redeem us from all iniquity, and purify unto himself a peculiar people, zealous of good works.',
			),
		)
	], 'specific verses inspection');

	return EXIT_SUCCESS;
}

sub testParental {
	my ($self) = @_;
	plan tests => 1;

	my $verse = $self->sut->votd({ version => 1, when => '1973-01-12T12:00:00+0100', parental => 1 });
	cmp_deeply($verse, all(
		isa('Religion::Bible::Verses::Verse'),
		methods(
			book    => all(
				isa('Religion::Bible::Verses::Book'),
				methods(shortName => 'Jonah'),
			),
			chapter => all(
				isa('Religion::Bible::Verses::Chapter'),
				methods(ordinal => 4),
			),
			ordinal => 10,
			text    => ignore(),
		),
	), 'verse inspection') or diag(explain($verse->toString()));

	return EXIT_SUCCESS;
}

sub __mockLogger {
	my ($self) = @_;
	$self->sut->dic->logger(Religion::Bible::Verses::DI::MockLogger->new());
	return;
}

package main;
use strict;
use warnings;

exit(VotdTests->new->run());
