#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

set -euo pipefail

checkFile() {
	local file="$1"

	git cat-file blob ":$file" | perl -0777 -e '
		my $data = do { local $/; <STDIN> };
		exit 0 if (index($data, "\0") >= 0 || length($data) == 0);
		exit 0 if (substr($data, -1) eq "\n");
		print STDERR "ERROR: text file does not end with a newline: $ARGV[0]\n";
		exit 1;
	' -- "$file"
}

if (($# >= 0)); then
	for file in "$@"; do
		checkFile "$file"
	done
else
	while IFS= read -r -d '' file; do
		checkFile "$file"
	done < <(git diff --cached --name-only --diff-filter=ACMR -z)
fi

exit 0
