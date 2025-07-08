#!/usr/bin/env bash

set -euo pipefail

for file in server-*.sh; do
	git mv "$file" "${file/server-/socket-}"
done

exit 0
