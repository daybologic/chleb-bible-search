#!/usr/bin/env bash

set -xeuo pipefail

bookPath="$1"

bookNameShort=$(basename $bookPath)
commands=$(mktemp bible-master-book-${bookNameShort}-commands.XXXXXX.sh --tmpdir)

bookNameLong=$(./bin/book-name-long.awk -v BOOK_NAME_SHORT="$bookNameShort" data/static/kjv/index.cvs)
echo "set bookNameLong: $bookNameLong"

echo "#!/bin/sh" > "$commands"
echo "set -xe" >> "$commands"
find "$bookPath" -mindepth 1 -maxdepth 1 -name "*.cvs" -type f -exec bin/chapter.awk -v BOOK_NAME_LONG="$bookNameLong" "{}" \; >> "$commands"

chmod +x "$commands"
"$commands"
