#!/usr/bin/env bash

set -xeuo pipefail

bookNameShort="$1"
bookNameLong="$2"
chapter="$3"
verse="$4"
text="$5"

TRANSLATION='kjv'
ref="${TRANSLATION}:${bookNameShort}:${chapter}:${verse}"
outputInterim="data/${TRANSLATION}-verses.txt"

if false; then
	text=$(echo -n "$text" | jq -Rsa .)
	aws --profile palmer dynamodb put-item --table-name bible --item \
	   "{
	       \"ref\": {
		   \"S\": \"$ref\"
	       },
	       \"translation\": {
		   \"S\": \"$TRANSLATION\"
	       },
	       \"bookNameShort\": {
		   \"S\": \"$bookNameShort\"
	       },
	       \"bookNameLong\": {
		   \"S\": \"$bookNameLong\"
	       },
	       \"chapter\": {
		   \"S\": \"$chapter\"
	       },
	       \"verse\": {
		   \"S\": \"$verse\"
	       },
	       \"text\": {
		   \"S\": $text
	       }
	   }"
else
	verseFile=$(mktemp bible-master-book.XXXXXX.tmp --tmpdir)
	echo "${ref}::${text}" | tee "$verseFile"
	cat "$verseFile" >> "$outputInterim"
	rm -vf "$verseFile"
fi

exit 0
