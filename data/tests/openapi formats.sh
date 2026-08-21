#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

set -uo pipefail

if [[ "${1:-}" == "--get-loops" ]]; then
	printf "%s\n" 1
	exit 0
fi


request() {
	local path="$1"
	local accept="$2"
	http --print=hb --pretty=none --check-status GET "chleb-api.example.org${path}" "Accept:${accept}" 2>/dev/null
}

html=$(request /docs text/html)
htmlResult=$?
if [ "$htmlResult" -ne 0 ] \
	|| ! grep -q '^HTTP/[^ ]* 200 ' <<< "$html" \
	|| ! grep -qi '^Content-Type: text/html' <<< "$html" \
	|| ! grep -q 'SwaggerUIBundle' <<< "$html"; then
	exit 1
fi

json=$(request /docs application/json)
jsonResult=$?
if [ "$jsonResult" -ne 0 ] \
	|| ! grep -q '^HTTP/[^ ]* 200 ' <<< "$json" \
	|| ! grep -qi '^Content-Type: application/json' <<< "$json" \
	|| ! grep -Eq '"openapi"[[:space:]]*:[[:space:]]*"3\.0\.0"' <<< "$json"; then
	exit 1
fi

yaml=$(request /docs application/yaml)
yamlResult=$?
if [ "$yamlResult" -ne 0 ] \
	|| ! grep -q '^HTTP/[^ ]* 200 ' <<< "$yaml" \
	|| ! grep -qi '^Content-Type: application/yaml' <<< "$yaml" \
	|| ! grep -q '^openapi: 3.0.0$' <<< "$yaml"; then
	exit 1
fi

exit 0
