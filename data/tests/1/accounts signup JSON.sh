#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL).

set -euo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 1
	exit 0
fi

result=$(http --check-status --body --pretty=none POST \
	chleb-api.example.org/1/accounts/signup \
	Accept:application/vnd.api+json \
	Content-Type:application/vnd.api+json \
	<<< '{"data":{"type":"account","attributes":{"username":"functional-test","email":"functional-test@example.com","name":"Functional Test"}}}')

jq -e '
	.data.type == "account"
	and (.data.id | test("^[1-9][0-9]*$"))
	and .data.attributes.username == "functional-test"
	and .data.attributes.email == "functional-test@example.com"
	and .data.attributes.name == "Functional Test"
	and .data.attributes.status == "pending"
' <<< "$result" >/dev/null
