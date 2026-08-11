#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

package UtilsHtmlEscapeTests;
## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Utils;
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testEscapesHtmlCharacters {
	my ($self) = @_;
	plan tests => 2;

	is(Chleb::Utils::htmlEscape(q{<&>"'}), '&lt;&amp;&gt;&quot;&#39;', 'HTML special characters are escaped');
	is(Chleb::Utils::htmlEscape(undef), q{}, 'undefined values become empty strings');

	return EXIT_SUCCESS;
}

__PACKAGE__->meta->make_immutable;

package main;
use strict;
use warnings;

exit(UtilsHtmlEscapeTests->new->run());
