#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).
#
# Verify account credentials through the HTTP API.

set -euo pipefail

CHLEB_URL="${CHLEB_URL:-http://127.0.0.1:5000}"

if ! command -v curl >/dev/null 2>&1; then
	printf 'curl is required to verify an account password.\n' >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	printf 'jq is required to verify an account password.\n' >&2
	exit 1
fi

read -r -p 'Account ID: ' accountId
read -r -s -p 'Password: ' password
printf '\n' >&2

if [[ ! "$accountId" =~ ^[1-9][0-9]*$ ]]; then
	printf 'Account ID must be a positive integer.\n' >&2
	exit 2
fi

payload=$(jq -cn --argjson account_id "$accountId" --arg password "$password" \
	'{account_id:$account_id,password:$password}')
unset password

response=$(curl --connect-timeout 2 --silent --show-error \
	--data-binary "$payload" \
	--header 'Accept: application/json' \
	--header 'Content-Type: application/json' \
	--write-out $'\n%{http_code}' \
	"$CHLEB_URL/1/accounts/verify-password")
status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
	printf '%s\n' "$body" >&2
	exit 1
fi

jq -r '.valid' <<< "$body"
