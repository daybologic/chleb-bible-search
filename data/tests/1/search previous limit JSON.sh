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

set -euo pipefail

cookieResult=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/search \
	Accept:application/json \
	Cookie:'previousSearchLimit=7; previousSearchPerPage=3' \
	term==fire)

jq -e '.links.self == "/1/search?term=fire&wholeword=0&limit=7&page=1&per_page=3"' \
	<<< "$cookieResult" >/dev/null

explicitResult=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/search \
	Accept:application/json \
	Cookie:'previousSearchLimit=7; previousSearchPerPage=3' \
	term==fire \
	limit==3)

jq -e '.links.self == "/1/search?term=fire&wholeword=0&limit=3&page=1&per_page=3"' \
	<<< "$explicitResult" >/dev/null

searchPage=$(http --check-status --body --pretty=none GET \
	chleb-api.example.org/1/search \
	Accept:text/html \
	Cookie:'previousSearchLimit=7; previousSearchPerPage=3')

grep -q 'id="limit" name="limit".* value="7"' <<< "$searchPage"
grep -q '<label for="per_page">Per page</label>' <<< "$searchPage"
grep -q 'id="per_page" name="per_page".* value="3"' <<< "$searchPage"
grep -q "var previousSearchLimitCookieName = 'previousSearchLimit';" <<< "$searchPage"
grep -q "var previousSearchPerPageCookieName = 'previousSearchPerPage';" <<< "$searchPage"
grep -q "writeCookie(previousSearchLimitCookieName, limit.value);" <<< "$searchPage"
grep -q "writeCookie(previousSearchPerPageCookieName, perPage.value);" <<< "$searchPage"

exit 0
