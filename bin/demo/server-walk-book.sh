#!/bin/sh
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
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

set -e

reverse=0

usage() {
	echo "Usage: $0 [-r]" >&2
}

while getopts 'r' opt; do
	case "$opt" in
	r)
		reverse=1
		;;
	*)
		usage
		exit 2
		;;
	esac
done

shift $((OPTIND - 1))

if [ "$#" -ne 0 ]; then
	usage
	exit 2
fi

if [ -z "$CHLEB_SCHEME" ]; then
	CHLEB_SCHEME=https
fi

if [ -z "$CHLEB_HOSTNAME" ]; then
	CHLEB_HOSTNAME=chleb-api.daybologic.co.uk
fi

if [ -z "$CHLEB_PORT" ]; then
	CHLEB_PORT=443
fi

# Keep the default below the session rate limit.  Walking all 31,102 Bible
# verses with this delay takes a little over six hours.
if [ -z "$CHLEB_REQUEST_DELAY" ]; then
	CHLEB_REQUEST_DELAY=0.7
fi

set -u

if [ "$reverse" -eq 1 ]; then
	p="/1/lookup/rev/22/21"
	linkName=prev
else
	p="/1/lookup/gen/1/1"
	linkName=next
fi

scheme=$CHLEB_SCHEME
host=$CHLEB_HOSTNAME
port=$CHLEB_PORT
requestDelay=$CHLEB_REQUEST_DELAY
base="${scheme}://${host}:${port}"
cookieJar=$(mktemp)

cleanup() {
	rm -f "$cookieJar"
}

trap cleanup EXIT HUP INT TERM

while [ -n "$p" ] && [ "$p" != "null" ]; do
	json=$(curl --cookie "$cookieJar" --cookie-jar "$cookieJar" --header 'Accept: application/json' -s "${base}${p}");
	p=$(echo "$json" | jq -r ".links.${linkName}");
	text=$(echo "$json" | jq -r .data[0].attributes.text);
	echo "$text"
	if [ -n "$p" ] && [ "$p" != "null" ]; then
		sleep "$requestDelay"
	fi
done

exit 0
