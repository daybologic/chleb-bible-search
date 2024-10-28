#!/bin/sh

set -u

rootDir=$(git rev-parse --show-toplevel)
set -e

if [ -z "$rootDir" ]; then
	rootDir='.'
fi

find "$rootDir" -name @eaDir -type d -exec rm -rf "{}" \;
