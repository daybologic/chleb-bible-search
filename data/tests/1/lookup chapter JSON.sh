#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 1
	exit 0
fi


result=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/lookup/prov/16 \
	Accept:application/json)

jq -e '
	(type == "array")
	and (length > 0)
	and all(.[].data[]; .type == "verse" and .attributes.chapter == 16)
	and any(.[].included[]; .type == "stats")
' <<< "$result" >/dev/null
