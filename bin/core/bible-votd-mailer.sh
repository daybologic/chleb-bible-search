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

set -xeuo pipefail

nowCoarse=$(date "+%a. %d %b %Y")
now=$(date '+%Y-%m-%dT09:00:00%%2B0100')
siteRoot='https://chleb-api.daybologic.co.uk'

# --- 1. Fetch VoTD as JSON:API ---
#    -H 'Accept: application/vnd.api+json' \
json="$(
  curl -s \
    -H 'Accept: application/json' \
    "${siteRoot}/2/votd?when=${now}"
)"


i=0
bookId=''
bookName=''
htmlVerseTexts=''
plainVerseTexts=''
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
reference=''
while true; do
	bookRelationship=$(echo "$json" | jq -r '.data['$i'].relationships.book.data.id');
	if [ "$bookRelationship" = "$bookId" ]; then
		if [ -z "$reference" ]; then
			reference=$(echo "$json" | jq -r '.data['$i'].attributes | (.chapter|tostring) + ":" + (.ordinal|tostring)');
			reference="${bookName} ${reference}"
		fi
		verseOrdinal=$(echo "$json" | jq -r '.data['$i'].attributes | (.ordinal|tostring)');
		if [ "$i" -gt 0 ]; then
			htmlVerseTexts="${htmlVerseTexts}<sup class=\"versenum\">${verseOrdinal} </sup>"
			plainVerseTexts="${plainVerseTexts}[${verseOrdinal}] "
		fi
		verseText=$(echo "$json" | jq -r '.data['$i'].attributes.text');
		htmlVerseTexts="${htmlVerseTexts}${verseText}"
		plainVerseTexts="${plainVerseTexts}${verseText}"
	else
		break;
	fi

	((++i))
done

translation="$(jq -r '.data[0].attributes.translation // "KJV"' <<< "$json")"

permalink="$(jq -r '.data[0].links.self // .links.self // empty' <<< "$json")"
# permalink="$(jq -r '.links.self // .data[0].links.self // empty' <<< "$json")" # FIXME: 'testament=' appears, which is illegal (should be 'testament=any'), so the link is duff
permalink="${siteRoot}${permalink}"

mailSubject="Verse of the Day - $nowCoarse"
mailUnsubscribe='~m6kvm/chleb-votd+unsubscribe@lists.sr.ht?subject=unsubscribe'

# --- 2. Build HTML body into a variable ---
htmlBody="$(cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$mailSubject</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background: #f5f5f5;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    sup.versenum {
      font-family: system-ui, -apple-system, "Segoe UI", Roboto, Ubuntu,
        Cantarell, "Noto Sans", Arial, sans-serif;
      font-weight: 700;
      font-size: 0.7em;        /* smaller than body text */
      vertical-align: text-top;
      line-height: 1;
      margin-left: 0.15em;     /* small gap from the previous word */
    }
    .wrapper {
      max-width: 640px;
      margin: 0 auto;
      padding: 24px 12px;
    }
    .card {
      background: #ffffff;
      border-radius: 8px;
      padding: 24px;
      border: 1px solid #e0e0e0;
    }
    h1 {
      font-size: 22px;
      margin: 0 0 8px 0;
    }
    .subtitle {
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: #777777;
      margin-bottom: 16px;
    }
    blockquote {
      margin: 0 0 16px 0;
      padding-left: 12px;
      border-left: 3px solid #cccccc;
      font-size: 16px;
      line-height: 1.5;
    }
    .translation {
      font-size: 13px;
      color: #777777;
      margin-bottom: 16px;
    }
    .footer {
      font-size: 11px;
      color: #999999;
      margin-top: 16px;
    }
    a {
      color: #0069c0;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="card">
      <div class="subtitle">Chleb Bible Search · Verse of the Day</div>

      <h1>$reference</h1>
      <div class="translation">$translation</div>

      <blockquote>
        <div>
          $htmlVerseTexts
        </div>
      </blockquote>

      $(if [ -n "$permalink" ]; then
        printf '<div><a href="%s">Open this verse on Chleb</a></div>' "$permalink"
      fi)

      <div class="footer">
        You are receiving this email from the <a href="https://lists.sr.ht/~m6kvm/chleb-votd">chleb-votd</a> mailing list.<br />

        To unsubscribe, email <a href="mailto:${mailUnsubscribe}">${mailUnsubscribe}</a>
      </div>
    </div>
  </div>
</body>
</html>
EOF
)"

boundary="chleb-votd-boundary-$(date +%s)"
mailTo="~m6kvm/chleb-votd-dev@lists.sr.ht"
mailTo="~m6kvm/chleb-votd@lists.sr.ht"
mailFrom="2e0eol@gmail.com"
mailFrom="~m6kvm/chleb-votd@lists.sr.ht"

swaks \
    --server smtp.gmail.com \
    --port 587 \
    --auth LOGIN \
    --auth-user "2e0eol@gmail.com" \
    --auth-password "XXXXXXXXXXXXXXXX" \
    --from "$mailFrom" \
    --to "$mailTo" \
    --tls \
    --data - <<EOF2
Date: $(date -R)
From: Chleb VoTD <$mailFrom>
To: Chleb VoTD Mailing List <$mailTo>
Subject: $mailSubject
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="$boundary"

--$boundary
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: 8bit

CHLEB BIBLE SEARCH - VERSE OF THE DAY
$reference
($translation)

$plainVerseTexts

Open this verse on Chleb: $permalink
You are receiving this email from the chleb-votd mailing list.
To unsubscribe, email ~m6kvm/chleb-votd+unsubscribe@lists.sr.ht?subject=unsubscribe

--$boundary
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: 8bit

$htmlBody

--$boundary--
EOF2
