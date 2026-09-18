#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

scriptDirectory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [[ -f "$scriptDirectory/../../lib/Chleb/Admin/SetPassword.pm" ]]; then
	perlLibrary="$scriptDirectory/../../lib"
else
	perlLibrary='/usr/share/chleb-bible-search/perl5'
fi

exec perl -I "$perlLibrary" -MChleb::Admin::SetPassword -e 'exit(Chleb::Admin::SetPassword::run(@ARGV));' "$@"
