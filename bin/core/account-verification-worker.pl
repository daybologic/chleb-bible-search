#!/usr/bin/env perl
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

use strict;
use warnings;

use Chleb::Workers::Signup;

exit(Chleb::Workers::Signup->run());
