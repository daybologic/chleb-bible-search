#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).
#
# Create an account through the local HTTP server.

set -euo pipefail

CHLEB_URL="${CHLEB_URL:-http://127.0.0.1:5000}"

if ! command -v curl >/dev/null 2>&1; then
	printf 'curl is required to create an account through the HTTP server.\n' >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	printf 'jq is required to create an account request.\n' >&2
	exit 1
fi

read -r -p 'Username: ' username
read -r -p 'Email address: ' email
read -r -p 'Name: ' name

if [[ -z "$username" || -z "$email" || -z "$name" ]]; then
	printf 'Username, email address, and name are all required.\n' >&2
	exit 1
fi

payload=$(jq -cn \
	--arg username "$username" \
	--arg email "$email" \
	--arg name "$name" \
	'{data:{type:"account",attributes:{username:$username,email:$email,name:$name}}}')

response=$(curl --connect-timeout 2 --silent --show-error \
	--data-binary "$payload" \
	--header 'Accept: application/vnd.api+json' \
	--header 'Content-Type: application/vnd.api+json' \
	--write-out $'\n%{http_code}' \
	"$CHLEB_URL/1/accounts/signup")
status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
	printf '%s\n' "$body" >&2
	exit 1
fi

jq . <<< "$body"
