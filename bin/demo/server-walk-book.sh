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

# Start at full speed by default.  If the server returns HTTP 429, the script
# backs off and retries the same verse.  Successful requests cut that delay
# down again so the demo keeps probing the live rate limit.
if [ -z "$CHLEB_REQUEST_DELAY" ]; then
	CHLEB_REQUEST_DELAY=0
fi

if [ -z "$CHLEB_BACKOFF_STEP" ]; then
	CHLEB_BACKOFF_STEP=0.1
fi

if [ -z "$CHLEB_RECOVERY_FACTOR" ]; then
	CHLEB_RECOVERY_FACTOR=0.5
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
backoffStep=$CHLEB_BACKOFF_STEP
recoveryFactor=$CHLEB_RECOVERY_FACTOR
base="${scheme}://${host}:${port}"
cookieJar=$(mktemp)
responseHeaders=$(mktemp)
responseBody=$(mktemp)

cleanup() {
	rm -f "$cookieJar" "$responseHeaders" "$responseBody"
}

trap cleanup EXIT HUP INT TERM

# Start at full speed.  Back off on HTTP 429, and speed up again after each
# successful request so the client continues to push the available limit.
while [ -n "$p" ] && [ "$p" != "null" ]; do
	statusCode=$(curl --cookie "$cookieJar" --cookie-jar "$cookieJar" --dump-header "$responseHeaders" --header 'Accept: application/json' -s --output "$responseBody" --write-out '%{http_code}' "${base}${p}");
	if [ "$statusCode" = "429" ]; then
		cat "$responseBody" >&2
		echo >&2
		retryAfter=$(awk 'tolower($1) == "retry-after:" { value = $2; gsub(/\r/, "", value) } END { print value }' "$responseHeaders")
		if [ -n "$retryAfter" ]; then
			requestDelay=$retryAfter
		else
			requestDelay=$(awk -v delay="$requestDelay" -v step="$backoffStep" 'BEGIN { printf("%.3f", delay + step) }')
		fi
		echo "Rate limited; retrying in ${requestDelay}s" >&2
		sleep "$requestDelay"
		continue
	fi
	if [ "$statusCode" -lt 200 ] || [ "$statusCode" -ge 300 ]; then
		echo "Unexpected HTTP status: $statusCode" >&2
		cat "$responseBody" >&2
		exit 1
	fi
	json=$(cat "$responseBody")
	p=$(echo "$json" | jq -r ".links.${linkName}");
	text=$(echo "$json" | jq -r .data[0].attributes.text);
	echo "$text"
	requestDelay=$(awk -v delay="$requestDelay" -v factor="$recoveryFactor" 'BEGIN { delay *= factor; if (delay < 0.001) delay = 0; printf("%.3f", delay) }')
	if [ -n "$p" ] && [ "$p" != "null" ] && awk -v delay="$requestDelay" 'BEGIN { exit !(delay > 0) }'; then
		sleep "$requestDelay"
	fi
done

exit 0
