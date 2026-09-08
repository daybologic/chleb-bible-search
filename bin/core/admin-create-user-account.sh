#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).
#
# Create an account through the local FastCGI socket.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
SOCKET="${SOCKET:-/var/run/chleb-bible-search/sock}"
CHLEB_URL="${CHLEB_URL:-http://127.0.0.1:5000}"

transport=''
if [[ -S "$SOCKET" ]]; then
	transport='socket'
elif [[ -f "$PROJECT_ROOT/bin/core/app.psgi" && -d "$PROJECT_ROOT/.git" ]]; then
	if ! command -v curl >/dev/null 2>&1; then
		printf 'curl is required for a checkout-based development server.\n' >&2
		exit 1
	fi
	transport='http'
fi

if [[ -z "$transport" ]]; then
	printf 'Chleb Bible Search socket is not available: %s\n' "$SOCKET" >&2
	exit 1
fi

if [[ "$transport" == 'socket' && ! -x /usr/bin/cgi-fcgi ]]; then
	printf 'cgi-fcgi is required to create an account through the socket.\n' >&2
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

export CONTENT_LENGTH="$(printf '%s' "$payload" | wc -c | tr -d ' ')"
export CONTENT_TYPE='application/vnd.api+json'
export HTTP_ACCEPT='application/vnd.api+json'
export HTTP_USER_AGENT='Chleb admin account utility'
export PATH_INFO='/1/accounts/signup'
export QUERY_STRING=''
export REQUEST_METHOD='POST'
export REQUEST_URI="$PATH_INFO"
export SERVER_PROTOCOL='HTTP/1.1'

if [[ "$transport" == 'socket' ]]; then
	response=$(printf '%s' "$payload" | cgi-fcgi -connect "$SOCKET" /)
	status=$(awk -F '[ :]+' '/^Status:/{print $2; exit} /^HTTP\//{print $2; exit}' <<< "$response")
	status="${status:-200}"
	body=$(sed '1,/^[[:space:]]*$/d' <<< "$response")
else
	response=$(curl --connect-timeout 2 --silent --show-error \
		--data-binary "$payload" \
		--header 'Accept: application/vnd.api+json' \
		--header 'Content-Type: application/vnd.api+json' \
		--write-out $'\n%{http_code}' \
		"$CHLEB_URL/1/accounts/signup")
	status="${response##*$'\n'}"
	body="${response%$'\n'*}"
fi

if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
	printf '%s\n' "$body" >&2
	exit 1
fi

jq . <<< "$body"
