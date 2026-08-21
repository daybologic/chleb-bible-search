#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 10
	exit 0
fi


result=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/2/random \
	Accept:application/json testament==old translations==asv)

jq -e '
	(.data | length) == 1
	and .data[0].attributes.translation == "asv"
	and .data[0].attributes.book != null
	and any(.included[]; .type == "book" and .attributes.testament == "old")
	and any(.included[]; .type == "stats")
' <<< "$result" >/dev/null
