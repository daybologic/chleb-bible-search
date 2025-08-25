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

set -uo pipefail

# Fetch headers once
headers=$(http --print=h --pretty=none --check-status GET chleb-api.example.org/1/random Accept:text/html redirect==true 2>/dev/null)
exitCode=$?

# Extract status code
statusCode=$(echo "$headers" | head -n 1 | awk '{print $2}')

# === Define expectations ===
expectedExitCode=3
expectedStatus="307"
declare -A expectedHeaders=(
	["Content-Type"]="text/html; charset=utf-8"
	["Connection"]="keep-alive"
	["Server"]="Perl Dancer2 0.400001"
	["Location"]="^/1/lookup/[a-z]+/[0-9]+/[0-9]+$"
)

# Exit code test
if [[ "$exitCode" -eq "$expectedExitCode" ]]; then
	echo "✅ Exit code: $exitCode"
else
	echo "❌ Exit code: got $exitCode, expected $expectedExitCode"
	exit 1
fi

# Status code test
if [[ "$statusCode" == "$expectedStatus" ]]; then
	echo "✅ Status: $statusCode"
else
	echo "❌ Status: got $statusCode, expected $expectedStatus"
	exit 1
fi

# === Run tests ===
# Header tests
for header in "${!expectedHeaders[@]}"; do
	# Extract header value, strip leading/trailing spaces and CR
	actual=$(echo "$headers" | grep -i "^$header:" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]\r]*$//')
	expected="${expectedHeaders[$header]}"

	# If expected looks like regex (starts with ^ or ends with $), use regex match
	if [[ "$expected" =~ ^\^.*\$?$ ]]; then
		if [[ "$actual" =~ $expected ]]; then
			echo "✅ $header matches pattern: $expected"
		else
			echo "❌ $header: got '$actual', expected pattern '$expected'"
			exit 1
		fi
	else
		# Exact match
		if [[ "$actual" == "$expected" ]]; then
			echo "✅ $header: $actual"
		else
			echo "❌ $header: got '$actual', expected '$expected'"
			exit 1
		fi
	fi
done

echo "🎉 All tests passed!"
exit 0
