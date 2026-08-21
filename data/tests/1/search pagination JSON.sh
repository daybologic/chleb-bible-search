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
	Accept:application/json term==fire wholeword==true limit==12 per_page==3 page==2)

jq -e '
	any(.included[]; .type == "results_summary" and
		.attributes.page == 2 and
		.attributes.per_page == 3 and
		.attributes.total_count <= 12)
	and (.links.self | contains("page=2"))
	and ((.data | length) <= 3)
' <<< "$result" >/dev/null
