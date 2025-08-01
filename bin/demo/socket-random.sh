#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2024-2025, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the Daybo Logic nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

set -eu

export QUERY_STRING="testament=new"
export SERVER_PROTOCOL='HTTP/1.1'
export PATH_INFO='/2/random'
export REQUEST_METHOD='GET'
export REQUEST_URI="$PATH_INFO"
export HTTP_USER_AGENT='Chleb demo script'
export HTTP_ACCEPT='application/json'
export SOCKET='/var/run/chleb-bible-search/sock'

if [ -x /usr/bin/cgi-fcgi ]; then
	if [ -x /usr/bin/jq ] || [ -x /usr/local/bin/jq ]; then
		json=$(cgi-fcgi -connect "$SOCKET" / | sed '1,/^\r*$/d')
		i=0
		bookId=''
		bookName=''
		while true; do
			includedType=$(echo "$json" | jq -r '.included['$i'].type');

			if [ "${includedType}" = "null" ]; then
				break;
			fi

			if [ "${includedType}" = "book" ]; then
				bookId=$(echo "$json" | jq -r '.included['$i'].id');
				bookName=$(echo "$json" | jq -r '.included['$i'].attributes.short_name_raw');
				break;
			fi

			((++i))
		done

		i=0
		while true; do
			bookRelationship=$(echo "$json" | jq -r '.data['$i'].relationships.book.data.id');
			if [ "$bookRelationship" = "$bookId" ]; then
				line1=$(echo "$json" | jq -r '.data['$i'].attributes | (.chapter|tostring) + ":" + (.ordinal|tostring) + " " + .text');
				if [ "${line1}" = "null:null " ]; then
					break;
				fi
				line="$bookName $line1"
				echo "$line"
			else
				break;
			fi

			((++i))
		done
	else
		export HTTP_ACCEPT='text/html'
		cgi-fcgi -connect "$SOCKET" /
	fi
fi
