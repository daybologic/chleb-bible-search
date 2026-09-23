#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).
#
# Log into an account through the HTTP API and fetch its account resource.

set -euo pipefail

CHLEB_URL="${CHLEB_URL:-http://chleb-api.example.org}"

if ! command -v curl >/dev/null 2>&1; then
	printf 'curl is required to log into an account.\n' >&2
	exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
	printf 'jq is required to log into an account.\n' >&2
	exit 1
fi

read -r -p 'Username: ' username
read -r -s -p 'Password: ' password
printf '\n' >&2

if [[ -z "$username" || -z "$password" ]]; then
	printf 'Username and password are required.\n' >&2
	exit 2
fi

challengeResponse=$(curl --connect-timeout 2 --silent --show-error \
	--data-binary "$(jq -cn --arg username "$username" '{username:$username}')" \
	--header 'Accept: application/json' \
	--header 'Content-Type: application/json' \
	--write-out $'\n%{http_code}' \
	"$CHLEB_URL/1/accounts/login/challenge")
challengeStatus="${challengeResponse##*$'\n'}"
challengeBody="${challengeResponse%$'\n'*}"

if [[ "$challengeStatus" -lt 200 || "$challengeStatus" -ge 300 ]]; then
	printf '%s\n' "$challengeBody" >&2
	exit 1
fi

challenge=$(jq -er '.challenge' <<< "$challengeBody")
loginPayload=$(jq -cn \
	--arg username "$username" \
	--arg password "$password" \
	--arg challenge "$challenge" \
	'{username:$username,password:$password,challenge:$challenge}')
unset password

loginResponse=$(curl --connect-timeout 2 --silent --show-error \
	--data-binary "$loginPayload" \
	--header 'Accept: application/json' \
	--header 'Content-Type: application/json' \
	--write-out $'\n%{http_code}' \
	"$CHLEB_URL/1/accounts/login")
loginStatus="${loginResponse##*$'\n'}"
loginBody="${loginResponse%$'\n'*}"

if [[ "$loginStatus" -lt 200 || "$loginStatus" -ge 300 ]]; then
	printf '%s\n' "$loginBody" >&2
	exit 1
fi

accessToken=$(jq -er '.access_token' <<< "$loginBody")
accountId=$(jq -er '.account.id | select(test("^[1-9][0-9]*$"))' <<< "$loginBody")
accountResponse=$(curl --connect-timeout 2 --silent --show-error \
	--header "Authorization: Bearer $accessToken" \
	--header 'Accept: application/json' \
	--write-out $'\n%{http_code}' \
	"$CHLEB_URL/1/accounts/$accountId")
accountStatus="${accountResponse##*$'\n'}"
accountBody="${accountResponse%$'\n'*}"

if [[ "$accountStatus" -lt 200 || "$accountStatus" -ge 300 ]]; then
	printf '%s\n' "$accountBody" >&2
	exit 1
fi

printf 'JWT: %s\n' "$accessToken"
jq . <<< "$accountBody"
