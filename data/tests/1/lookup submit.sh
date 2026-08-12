#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -uo pipefail

headers=$(http --print=h --pretty=none --check-status GET \
	chleb-api.example.org/1/lookup \
	Accept:text/html book==prov chapter==16 verse==18 submit==lookup 2>/dev/null)
exitCode=$?

statusCode=$(awk 'NR == 1 { print $2 }' <<< "$headers")
location=$(sed -n 's/^Location: //Ip' <<< "$headers" | tr -d '\r')

[[ "$exitCode" -eq 3 ]]
[[ "$statusCode" == 307 ]]
[[ "$location" == /1/lookup/prov/16/18* ]]
