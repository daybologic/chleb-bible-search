#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).
#
# Fetch an account resource using a JWT.

set -euo pipefail

CHLEB_URL="${CHLEB_URL:-http://chleb-api.example.org}"

if ! command -v curl >/dev/null 2>&1; then
	printf 'curl is required to fetch an account.\n' >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	printf 'jq is required to fetch an account.\n' >&2
	exit 1
fi

read -r -s -p 'JWT: ' accessToken
printf '\n' >&2
read -r -p 'Account ID or username: ' accountTarget

if [[ -z "$accessToken" || -z "$accountTarget" ]]; then
	printf 'A JWT and account ID or username are required.\n' >&2
	exit 2
fi

if [[ "$accountTarget" =~ ^[1-9][0-9]*$ ]]; then
	request=("$CHLEB_URL/1/accounts/$accountTarget")
else
	request=(--get "$CHLEB_URL/1/accounts" --data-urlencode "username=$accountTarget")
fi

response=$(curl --connect-timeout 2 --silent --show-error \
	--header "Authorization: Bearer $accessToken" \
	--header 'Accept: application/json' \
	--write-out $'\n%{http_code}' \
	"${request[@]}")
status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
	printf '%s\n' "$body" >&2
	exit 1
fi

jq . <<< "$body"
