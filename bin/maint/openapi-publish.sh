#!/bin/sh
# Chleb Bible Search
# Copyright (c) 2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
source="$root/swagger.yaml"
public="$root/data/static/public"

mkdir -p "$public"
cp "$source" "$public/openapi.yaml"
"$root/bin/core/yaml2json.pl" "$source" > "$public/openapi.json"

exit 0
