#!/usr/bin/env bash

set -xeuo pipefail

rm -f data/kjv-verses.txt
find data/static/kjv/ -mindepth 1 -maxdepth 1 -type d -exec bin/book.sh "{}" \;
