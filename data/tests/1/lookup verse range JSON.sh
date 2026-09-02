#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 1
	exit 0
fi

result=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/lookup/gen/38/9-10 \
	Accept:application/json \
	translations==kjv)

jq -e '
	.data as $verses
	| ($verses | length == 2)
	and (($verses | map(.attributes.ordinal) | sort) == [9, 10])
	and all($verses[]; .attributes.translation == "kjv")
' <<< "$result" >/dev/null
