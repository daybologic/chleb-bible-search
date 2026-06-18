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

page=$(http --check-status --body --pretty=none GET chleb-api.example.org/1/info Accept:text/html)
style=$(http --check-status --body --pretty=none GET chleb-api.example.org/style.css)

grep -q '<link href="/style.css?v=' <<< "$page"
grep -q '<img class="info-bible-image" src="/images/bible.png" alt="Bible" width="273" height="214" />' <<< "$page"
grep -q '<table class="info-table">' <<< "$page"
grep -q '<th>Book</th>' <<< "$page"
grep -q '<a href="/1/lookup/gen/1/1">Genesis</a>' <<< "$page"
(( "$(grep -o '<a href="/1/lookup/gen/1/1">Genesis</a>' <<< "$page" | wc -l)" > 1 ))
grep -q 'table.info-table {' <<< "$style"
grep -q 'background-color: #e8d4f2;' <<< "$style"
grep -q 'border: 2px solid #8a6a99;' <<< "$style"
grep -q 'border-spacing: 2px;' <<< "$style"
