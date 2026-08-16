#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

page=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/lookup/prov/16/18 \
	Accept:text/html \
	translations==asv)

grep -q '<div class="translation">asv (1901)</div>' <<< "$page"
grep -q '<h1>' <<< "$page"
grep -q '>Prov</a>' <<< "$page"
grep -q '>16</a>:' <<< "$page"
grep -q '>18</a>' <<< "$page"
