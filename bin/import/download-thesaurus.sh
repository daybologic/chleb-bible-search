#!/usr/bin/env bash
set -eu

if [[ $# != 3 ]]; then
	printf 'Usage: %s OUTPUT CHECKSUM_FILE URL\n' "$0" >&2
	exit 2
fi

output=$1
checksumFile=$2
url=$3

expected=$(awk 'NR == 1 { print $1 }' "$checksumFile")
if [[ -z "$expected" ]]; then
	printf 'Checksum file is empty: %s\n' "$checksumFile" >&2
	exit 1
fi

if [[ -f "$output" ]] && printf '%s  %s\n' "$expected" "$output" | sha256sum -c - >/dev/null 2>&1; then
	exit 0
fi

mkdir -p "$(dirname "$output")"
temporary=$(mktemp "${output}.tmp.XXXXXX")
trap 'rm -f "$temporary"' EXIT

curl --fail --location --silent --show-error "$url" --output "$temporary"
printf '%s  %s\n' "$expected" "$temporary" | sha256sum -c -
mv "$temporary" "$output"
trap - EXIT
