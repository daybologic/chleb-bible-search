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

if ! command -v dialog >/dev/null 2>&1; then
	printf 'dialog is required to select an account title.\n' >&2
	exit 1
fi

if ! docs=$(curl --connect-timeout 2 --fail --silent --show-error \
	--header 'Accept: application/json' \
	"$CHLEB_URL/docs"); then
	printf 'Unable to load account titles from %s/docs.\n' "$CHLEB_URL" >&2
	exit 1
fi

if ! title_list=$(jq -er \
	'.components.schemas.AccountAttributes.properties.title.enum[] | select(type == "string" and length > 0)' \
	<<< "$docs"); then
	printf 'The server documentation does not contain the account title list.\n' >&2
	exit 1
fi

mapfile -t titles <<< "$title_list"
menu=()
for title_option in "${titles[@]}"; do
	menu+=("$title_option" '')
done

if ! title=$(dialog --stdout --clear \
	--backtitle 'Chleb Bible Search' \
	--title 'Account title' \
	--menu 'Choose an account title:' 0 0 12 "${menu[@]}"); then
	printf 'Account creation cancelled.\n' >&2
	exit 1
fi

read -r -p 'Username: ' username
read -r -p 'Email address: ' email
read -r -p 'Name: ' name

if [[ -z "$title" || -z "$username" || -z "$email" || -z "$name" ]]; then
	printf 'Title, username, email address, and name are all required.\n' >&2
	exit 1
fi

	payload=$(jq -cn \
	--arg title "$title" \
	--arg username "$username" \
	--arg email "$email" \
	--arg name "$name" \
	'{data:{type:"account",attributes:{title:$title,username:$username,email:$email,name:$name}}}')

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
