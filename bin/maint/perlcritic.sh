#!/bin/sh
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

set -eu

# perlcritic wrapper
# - Accepts multiple file arguments (works with: find ... -exec ... {} +)
# - Calls the real perlcritic
# - Preserves perlcritic output to stdout/stderr.

# Locate perlcritic
PERLCRITIC_BIN="${PERLCRITIC_BIN:-perlcritic}"

# Locate the repository profile independently of the caller's working directory.
scriptDir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repoRoot=$(CDPATH= cd -- "$scriptDir/../.." && pwd)

# Default options (override by setting PERLCRITIC_OPTS in environment if you want)
DEFAULT_OPTS="--profile $repoRoot/.perlcriticrc --nocolor --profile-strictness quiet --quiet"

# If you want to pass extra flags, do:
#   PERLCRITIC_OPTS="--severity 3" bin/maint/perlcritic.sh lib/Foo.pm
PERLCRITIC_OPTS="${PERLCRITIC_OPTS:-}"

# Nothing to do
if [ "$#" -eq 0 ]; then
	exit 0
fi

# Run perlcritic over each file. Test scripts conventionally end by switching
# back to package main for the runnable harness, so allow multiple package
# declarations only for top-level t/*.t files.
status=0
for file in "$@"; do
	case "$file" in
		t/*.t|*/t/*.t)
			if ! "$PERLCRITIC_BIN" $DEFAULT_OPTS $PERLCRITIC_OPTS --exclude Modules::ProhibitMultiplePackages "$file"; then
				status=1
			fi
			;;
		*)
			if ! "$PERLCRITIC_BIN" $DEFAULT_OPTS $PERLCRITIC_OPTS "$file"; then
				status=1
			fi
			;;
	esac
done

exit "$status"
