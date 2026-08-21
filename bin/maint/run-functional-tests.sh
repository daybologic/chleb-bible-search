#!/usr/bin/env bash
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

set -u  # strict on undefined vars, but no `-e`

BASE_DIR="data/tests"
SERVER_HOST='chleb-api.example.org'

failures=()
total=0
passed=0
failed=0
skipped=0
totalIterations=0
passedIterations=0
failedIterations=0
skippedIterations=0

# Ensure directory exists
if [[ ! -d "$BASE_DIR" ]]; then
	echo "⚠️ Directory '$BASE_DIR' does not exist." >&2
	exit 0
fi

# Check if httpie (http command) is installed
REAL_HTTP=$(command -v http || true)
if [[ -n "$REAL_HTTP" ]]; then
	echo "✅ HTTPie detected"
else
	echo "⚠️ HTTPie is not installed or not in the PATH" >&2
	exit 0
fi

if getent hosts "$SERVER_HOST" >/dev/null 2>&1; then
	echo "✅ Host $SERVER_HOST resolves."
else
	echo "⚠️ Host $SERVER_HOST does not resolve."
	exit 0
fi

httpWrapperDir=$(mktemp -d)
trap 'rm -rf "$httpWrapperDir"' EXIT

cat > "$httpWrapperDir/http" <<'EOS'
#!/usr/bin/env bash
sleep "${CHLEB_HTTP_TEST_DELAY:-1.25}"
exec "$CHLEB_REAL_HTTP" "$@"
EOS
chmod +x "$httpWrapperDir/http"

export CHLEB_REAL_HTTP="$REAL_HTTP"
export PATH="$httpWrapperDir:$PATH"

countLabel() {
	local count="$1"
	local singular="$2"
	local plural="$3"

	if (( count == 1 )); then
		printf '%s %s' "$count" "$singular"
	else
		printf '%s %s' "$count" "$plural"
	fi
}

# Find and execute .sh files
runTest() {
	local script="$1"
	local testName="$2"
	local loops
	local loop
	local status
	local scriptFailed=0
	(( total++ ))

	if [[ ${TEST_QUICK+x} && ${TEST_QUICK:-} != 0 ]]; then
		loops=1
	else
		loops=$("$script" --get-loops 2>/dev/null)
		status=$?
		if [[ $status -ne 0 || ! "$loops" =~ ^[1-9][0-9]*$ ]]; then
			(( failed++ ))
			failures+=("$testName (invalid --get-loops result)")
			echo "❌ FAILED: $testName (invalid --get-loops result)"
			return
		fi
	fi
	(( totalIterations += loops ))

	for ((loop = 1; loop <= loops; loop++)); do
		(
			"$script"
		) >/dev/null 2>&1 < /dev/null
		status=$?

		if [[ $status -ne 0 ]]; then
			(( failedIterations++ ))
			scriptFailed=1
			failures+=("$testName (loop $loop/$loops, exit $status)")
			echo "❌ FAILED (loop $loop/$loops, exit $status): $testName"
		else
			(( passedIterations++ ))
		fi
	done

	if [[ $scriptFailed -eq 0 ]]; then
		(( passed++ ))
		echo "✅ PASSED: $testName ($(countLabel "$loops" loop loops))"
	else
		(( failed++ ))
	fi
}

while IFS= read -r -d '' script; do
	testName="${script#$BASE_DIR}"
	if [ -x "$script" ]; then
		runTest "$script" "$testName"
	elif [[ "${script##*/}" == "template.sh" ]]; then
		continue
	else
		(( total++ ))
		(( skipped++ ))
		echo "⚠️ SKIPPED: $testName"
	fi
done < <(find "$BASE_DIR" -type f -name "*.sh" -print0)

echo "================================"
if (( failed > 0 )); then
	echo "Some tests failed:"
	for f in "${failures[@]}"; do
		echo " - $f"
	done
else
	echo "All tests passed successfully 🎉"
fi

# Final summary
echo "================================"
echo "Test Summary:"
echo "  Total  : $total ($(countLabel "$totalIterations" iteration iterations))"
if (( passed > 0 )); then
	echo "✅ Passed : $passed ($(countLabel "$passedIterations" iteration iterations))"
fi
if (( skipped > 0 )); then
	echo "⚠️Skipped : $skipped ($(countLabel "$skippedIterations" iteration iterations))"
fi
if (( failed > 0 )); then
	echo "❌ Failed : $failed ($(countLabel "$failedIterations" iteration iterations))"
fi
echo

if (( failed > 0 )); then
	exit 1
fi

exit 0
