#!/bin/sh
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

set -u

if [ "$#" -eq 0 ]; then
	printf 'Usage: %s FILE...\n' "$0" >&2
	exit 2
fi

status=0
for path in "$@"; do
	if [ ! -f "$path" ]; then
		printf 'ERROR: file not found: %s\n' "$path" >&2
		status=1
		continue
	fi

	description=$(file -b -- "$path") || {
		printf 'ERROR: cannot identify file: %s\n' "$path" >&2
		status=1
		continue
	}
	case "$description" in
		*'shell script'*)
			printf 'Checking shell syntax: %s\n' "$path"
			if bash -n -- "$path"; then
				printf 'OK: %s\n' "$path"
			else
				printf 'ERROR: invalid shell syntax: %s\n' "$path" >&2
				status=1
			fi
			;;
		*)
			printf 'Skipping non-shell script: %s\n' "$path"
			;;
	esac
done

exit "$status"
