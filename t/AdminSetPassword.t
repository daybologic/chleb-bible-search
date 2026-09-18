#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

package AdminSetPasswordTests;
## no critic (Modules::RequireFilenameMatchesPackage)
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Chleb::Admin::SetPassword;
use Test::More 0.96;

sub testRunRejectsMissingAccountId {
	plan tests => 1;

	is(Chleb::Admin::SetPassword::run(), 2, 'missing account ID returns usage status');

	return 0;
}

sub testRunRejectsInvalidAccountId {
	plan tests => 3;

	is(Chleb::Admin::SetPassword::run('0'), 2, 'zero account ID is rejected');
	is(Chleb::Admin::SetPassword::run('-1'), 2, 'negative account ID is rejected');
	is(Chleb::Admin::SetPassword::run('abc'), 2, 'non-numeric account ID is rejected');

	return 0;
}

__PACKAGE__->meta->make_immutable;

exit(AdminSetPasswordTests->new->run());
