#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -uo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 1
	exit 0
fi

response=$(http --print=hb --pretty=none --check-status GET \
	chleb-api.example.org/1/lookup/gen/38/10-9 \
	Accept:application/json \
	translations==kjv 2>/dev/null)
httpResult=$?
statusCode=$(head -n 1 <<< "$response" | awk '{print $2}')

[[ "$httpResult" -eq 4 ]]
[[ "$statusCode" == "400" ]]
grep -qi '^Content-Type: application/json' <<< "$response"
grep -q '"status":400' <<< "$response"
