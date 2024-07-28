#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2024, Rev. Duncan Ross Palmer (2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the project nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

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
