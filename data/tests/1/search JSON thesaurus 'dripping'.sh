#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 1
	exit 0
fi


result=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/search \
	Accept:application/json \
	translations==asv \
	term==dripping)

jq -e '
	any(.data[];
		.id == "asv/prov/27/15"
		and (.attributes.text | test("dropping"; "i"))
	)
' <<< "$result" >/dev/null
