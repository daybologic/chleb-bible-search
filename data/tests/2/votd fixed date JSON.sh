#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

result=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/2/votd \
	Accept:application/json when=='2024-10-30T00:00:00+0000' translations==asv,kjv)

jq -e '
	(.data | length) == 2
	and [.data[].attributes.translation] == ["asv", "kjv"]
	and all(.data[]; .attributes.book == "psa" and .attributes.chapter == 122 and .attributes.ordinal == 8)
	and (.data[0].attributes.book == .data[1].attributes.book)
	and (.data[0].attributes.chapter == .data[1].attributes.chapter)
	and (.data[0].attributes.ordinal == .data[1].attributes.ordinal)
	and any(.included[]; .type == "stats")
' <<< "$result" >/dev/null
