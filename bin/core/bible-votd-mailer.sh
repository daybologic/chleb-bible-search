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

# Directory of this script (absolute, no matter where it's run from)
scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

yaml2json="${scriptDir}/yaml2json.pl"
if [ ! -x "$yaml2json" ]; then
	yaml2json='/usr/share/chleb-bible-search/yaml2json.pl'
fi

config="${scriptDir}/../../etc/votd-mailer.yaml"
if [ ! -f "$config" ]; then
	config="/etc/chleb-bible-search/votd-mailer.yaml"
fi

echo "command: $yaml2json"

nowCoarse=$(date "+%a. %d %b %Y")
now=$(date '+%Y-%m-%dT09:00:00%%2B0100')

configJson=$("$yaml2json" < "$config")

smtpAuthUser=$(jq -r .mailing_list.smtp.username <<< "$configJson")
smtpAuthPass=$(jq -r .mailing_list.smtp.password <<< "$configJson")
smtpServerHost=$(jq -r .mailing_list.smtp.server <<< "$configJson")
smtpServerPort=$(jq -r .mailing_list.smtp.port <<< "$configJson")
smtpServerTls=$(jq -r .mailing_list.smtp.use_tls <<< "$configJson")

url=$(jq -r .mailing_list.list_info.url <<< "$configJson")
listName=$(jq -r .mailing_list.list_info.name <<< "$configJson")
#listSubscribe=$(jq -r .mailing_list.list_info.subscribe <<< "$configJson")
listUnsubscribe=$(jq -r .mailing_list.list_info.unsubscribe <<< "$configJson")
mailTo=$(jq -r .mailing_list.list_info.to <<< "$configJson")
mailToName=$(jq -r .mailing_list.list_info.to_name <<< "$configJson")
mailFrom=$(jq -r .mailing_list.list_info.from <<< "$configJson")
mailFromName=$(jq -r .mailing_list.list_info.from_name <<< "$configJson")

siteRoot=$(jq -r .mailing_list.site_info.root_url <<< "$configJson")

# --- 1. Fetch VoTD as JSON:API ---
#    -H 'Accept: application/vnd.api+json' \
jsonFile=$(mktemp)
httpStatus=$(curl -s -o >(cat > "$jsonFile") -w "%{http_code}" \
	-H 'Accept: application/json' \
	"${siteRoot}/2/votd?when=${now}")

if [ "$httpStatus" != "200" ]; then
	echo "Error: Failed. Status $httpStatus"
	exit 1
fi

json=$(cat "$jsonFile")
rm -f "$jsonFile"

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

i=0
emotion=''
while true; do
	if [ -z "$emotion" ]; then
		emotion=$(echo "$json" | jq -r '.data['$i'].attributes.emotion');
		break;
	fi
	((++i))
done

i=0
declare -A toneSeen
tones=()
while true; do
	ordinal=$(echo "$json" | jq -r '.data['$i'].attributes.ordinal');
	if [ "$ordinal" = 'null' ]; then
		break
	fi

	toneI=0
	while true; do
		tone=$(echo "$json" | jq -r '.data['$i'].attributes.tones['$toneI']');
		if [ "$tone" = 'null' ]; then
			break;
		fi

		if [[ ! -v "toneSeen[$tone]" ]]; then
			tones+=("$tone")
			toneSeen[$tone]=1
		fi

		((++toneI))
	done

	((++i))
done

if [ ! -z "$emotion" ] && [ "$emotion" != 'null' ]; then
	sentiments="$emotion"
	if [ "${#tones[@]}" -gt 0 ]; then
		IFS=, printf -v joined '%s' "${tones[*]}"
		joined=${joined// /, }
		sentiments="${sentiments}, ${joined}"
	fi
fi

sentimentTagsHtml=""
i=0
for word in $(echo "$sentiments" | tr ',' '\n' | sed 's/^ *//; s/ *$//'); do
	hash=$(printf "%s" "$word" | cksum | cut -d ' ' -f1)
	colorIndex=$(( hash % 64 ))
	sentimentTagsHtml+="<span class=\"tag tag-color-${colorIndex}\">$word</span> "
done

translation="$(jq -r '.data[0].attributes.translation // "KJV"' <<< "$json")"

permalink="$(jq -r '.data[0].links.self // .links.self // empty' <<< "$json")"
# permalink="$(jq -r '.links.self // .data[0].links.self // empty' <<< "$json")" # FIXME: 'testament=' appears, which is illegal (should be 'testament=any'), so the link is duff
permalink="${siteRoot}${permalink}"

mailSubject="Verse of the Day - $nowCoarse"

# --- 2. Build HTML body into a variable ---
htmlBody="$(cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$mailSubject</title>
  <style>
    .tag {
      padding: 2px 6px;
      margin: 2px;
      border-radius: 4px;
      font-size: 13px;
      color: #fff;
      display: inline-block;
    }
    .tag-color-0  { background-color: hsl(0, 65%, 40%); }
    .tag-color-1  { background-color: hsl(5, 65%, 40%); }
    .tag-color-2  { background-color: hsl(11, 65%, 40%); }
    .tag-color-3  { background-color: hsl(16, 65%, 40%); }
    .tag-color-4  { background-color: hsl(22, 65%, 40%); }
    .tag-color-5  { background-color: hsl(28, 65%, 40%); }
    .tag-color-6  { background-color: hsl(33, 65%, 40%); }
    .tag-color-7  { background-color: hsl(39, 65%, 40%); }
    .tag-color-8  { background-color: hsl(45, 65%, 40%); }
    .tag-color-9  { background-color: hsl(50, 65%, 40%); }
    .tag-color-10 { background-color: hsl(56, 65%, 40%); }
    .tag-color-11 { background-color: hsl(62, 65%, 40%); }
    .tag-color-12 { background-color: hsl(67, 65%, 40%); }
    .tag-color-13 { background-color: hsl(73, 65%, 40%); }
    .tag-color-14 { background-color: hsl(79, 65%, 40%); }
    .tag-color-15 { background-color: hsl(84, 65%, 40%); }
    .tag-color-16 { background-color: hsl(90, 65%, 40%); }
    .tag-color-17 { background-color: hsl(96, 65%, 40%); }
    .tag-color-18 { background-color: hsl(101, 65%, 40%); }
    .tag-color-19 { background-color: hsl(107, 65%, 40%); }
    .tag-color-20 { background-color: hsl(113, 65%, 40%); }
    .tag-color-21 { background-color: hsl(118, 65%, 40%); }
    .tag-color-22 { background-color: hsl(124, 65%, 40%); }
    .tag-color-23 { background-color: hsl(130, 65%, 40%); }
    .tag-color-24 { background-color: hsl(135, 65%, 40%); }
    .tag-color-25 { background-color: hsl(141, 65%, 40%); }
    .tag-color-26 { background-color: hsl(147, 65%, 40%); }
    .tag-color-27 { background-color: hsl(152, 65%, 40%); }
    .tag-color-28 { background-color: hsl(158, 65%, 40%); }
    .tag-color-29 { background-color: hsl(164, 65%, 40%); }
    .tag-color-30 { background-color: hsl(169, 65%, 40%); }
    .tag-color-31 { background-color: hsl(175, 65%, 40%); }
    .tag-color-32 { background-color: hsl(180, 65%, 40%); }
    .tag-color-33 { background-color: hsl(186, 65%, 40%); }
    .tag-color-34 { background-color: hsl(192, 65%, 40%); }
    .tag-color-35 { background-color: hsl(197, 65%, 40%); }
    .tag-color-36 { background-color: hsl(203, 65%, 40%); }
    .tag-color-37 { background-color: hsl(209, 65%, 40%); }
    .tag-color-38 { background-color: hsl(214, 65%, 40%); }
    .tag-color-39 { background-color: hsl(220, 65%, 40%); }
    .tag-color-40 { background-color: hsl(226, 65%, 40%); }
    .tag-color-41 { background-color: hsl(231, 65%, 40%); }
    .tag-color-42 { background-color: hsl(237, 65%, 40%); }
    .tag-color-43 { background-color: hsl(243, 65%, 40%); }
    .tag-color-44 { background-color: hsl(248, 65%, 40%); }
    .tag-color-45 { background-color: hsl(254, 65%, 40%); }
    .tag-color-46 { background-color: hsl(260, 65%, 40%); }
    .tag-color-47 { background-color: hsl(265, 65%, 40%); }
    .tag-color-48 { background-color: hsl(271, 65%, 40%); }
    .tag-color-49 { background-color: hsl(277, 65%, 40%); }
    .tag-color-50 { background-color: hsl(281, 65%, 40%); }
    .tag-color-51 { background-color: hsl(286, 65%, 40%); }
    .tag-color-52 { background-color: hsl(292, 65%, 40%); }
    .tag-color-53 { background-color: hsl(298, 65%, 40%); }
    .tag-color-54 { background-color: hsl(303, 65%, 40%); }
    .tag-color-55 { background-color: hsl(309, 65%, 40%); }
    .tag-color-56 { background-color: hsl(315, 65%, 40%); }
    .tag-color-57 { background-color: hsl(320, 65%, 40%); }
    .tag-color-58 { background-color: hsl(326, 65%, 40%); }
    .tag-color-59 { background-color: hsl(332, 65%, 40%); }
    .tag-color-60 { background-color: hsl(337, 65%, 40%); }
    .tag-color-61 { background-color: hsl(343, 65%, 40%); }
    .tag-color-62 { background-color: hsl(349, 65%, 40%); }
    .tag-color-63 { background-color: hsl(354, 65%, 40%); }
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

      <blockquote>
        <div>
          Sentiments: $sentimentTagsHtml
        </div>
      </blockquote>

      $(if [ -n "$permalink" ]; then
        printf '<div><a href="%s">Open this verse on Chleb</a></div>' "$permalink"
      fi)

      <div class="footer">
        You are receiving this email from the <a href="${url}">${listName}</a> mailing list.<br />

        To unsubscribe, email <a href="mailto:${listUnsubscribe}?subject=unsubscribe">${listUnsubscribe}</a>
      </div>
    </div>
  </div>
</body>
</html>
EOF
)"

boundary="chleb-votd-boundary-$(date +%s)"

case "$smtpServerTls" in
	1|true|yes|on|True|TRUE)
		tlsFlag="--tls"
		;;
	*)
		tlsFlag=""
		;;
esac

swaks \
    --server "$smtpServerHost" \
    --port "$smtpServerPort" \
    --auth LOGIN \
    --auth-user "$smtpAuthUser" \
    --auth-password "$smtpAuthPass" \
    --from "$mailFrom" \
    --to "$mailTo" \
    "$tlsFlag" \
    --data - <<EOF2
Date: $(date -R)
From: $mailFromName <$mailFrom>
To: $mailToName <$mailTo>
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

Sentiments: $sentiments

Open this verse on Chleb: $permalink
You are receiving this email from the $listName mailing list.
To unsubscribe, email $listUnsubscribe with a subject of "unsubscribe".

--$boundary
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: 8bit

$htmlBody

--$boundary--
EOF2
