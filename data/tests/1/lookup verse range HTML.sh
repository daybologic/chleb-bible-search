#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 1
	exit 0
fi

page=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/lookup/gen/38/9-10 \
	Accept:text/html \
	translations==kjv)

grep -Fq '<div class="translation">kjv (1611)</div>' <<< "$page"
grep -Fq '<h1>' <<< "$page"
grep -Fq '>9</a>' <<< "$page"
grep -Fq 'class="versenum"' <<< "$page"
grep -Fq '>10 </a></sup>' <<< "$page"
