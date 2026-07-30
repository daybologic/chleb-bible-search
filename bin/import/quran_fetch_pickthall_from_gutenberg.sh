#!/usr/bin/env bash
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (2E0EOL),
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

set -euo pipefail

URL="https://www.gutenberg.org/files/16955/16955.txt"
OUTDIR="${1:-quran_pickthall_json}"
UA="ChlebBibleSearch/experiment (Pickthall import)"

mkdir -p "$OUTDIR"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "Downloading Gutenberg source…"
curl -fsS -A "$UA" "$URL" -o "$tmp"

# Fix 4 known Gutenberg verse-label typos that break strict parsers
# (These are known in Gutenberg #16955: mis-numbered verse tags.)
perl -pi -e '
	s/^0\.033(\s)/017.033$1/;
	s/^039\.04(\s)/039.046$1/;
	s/^04\.032(\s)/045.032$1/;
	s/^05\.026(\s)/056.026$1/;
' "$tmp"

# Assert that the corrected tags now exist and the broken ones do not
grep -qE '^017\.033[[:space:]]' "$tmp"
grep -qE '^039\.046[[:space:]]' "$tmp"
grep -qE '^045\.032[[:space:]]' "$tmp"
grep -qE '^056\.026[[:space:]]' "$tmp"
! grep -qE '^(0\.033|039\.04|04\.032|05\.026)[[:space:]]' "$tmp"

echo "Parsing Pickthall verses and writing chapter_*.json…"

python3 - "$OUTDIR" "$tmp" <<'PY'
import json, re, sys
from pathlib import Path

outdir = Path(sys.argv[1])
src = Path(sys.argv[2])
text = src.read_text(encoding="utf-8", errors="replace")

# Verse tags anywhere.
tag_re = re.compile(r'(\d{3})\.(\d{3})\s+')
matches = list(tag_re.finditer(text))
if not matches:
	raise SystemExit("No verse tags like 001.001 found (unexpected source format).")

# Robust markers: not preceded by a word char
p_mark = re.compile(r'(?<!\w)P\s*[:.]\s*', re.DOTALL)
other_mark = re.compile(r'(?<!\w)[SR]\s*[:.]\s*', re.DOTALL)  # Sale / Rodwell

data = {s: {} for s in range(1, 115)}

for i, m in enumerate(matches):
	surah = int(m.group(1))
	ayah = int(m.group(2))
	if not (1 <= surah <= 114):
		continue

	start = m.end()
	end = matches[i+1].start() if i+1 < len(matches) else len(text)
	chunk = text[start:end]

	pm = p_mark.search(chunk)
	if not pm:
		continue

	p_start = pm.end()

	# Find the next non-P marker after Pickthall starts
	nm = other_mark.search(chunk, p_start)
	p_end = nm.start() if nm else len(chunk)

	p_text = chunk[p_start:p_end]
	p_text = " ".join(p_text.replace("\r", " ").replace("\n", " ").split()).strip()
	if p_text:
		data[surah][ayah] = p_text

# Write JSON arrays per surah and FAIL if there are any gaps
for surah in range(1, 115):
	verses = data[surah]
	if not verses:
		raise SystemExit(f"Missing surah {surah}: parsed 0 Pickthall verses")

	max_ayah = max(verses.keys())
	missing = [i for i in range(1, max_ayah+1) if i not in verses]
	if missing:
		raise SystemExit(f"Surah {surah} has {len(missing)} missing ayahs (first few: {missing[:20]})")

	arr = [verses[i] for i in range(1, max_ayah+1)]
	(outdir / f"chapter_{surah}.json").write_text(
		json.dumps(arr, ensure_ascii=False, indent=2) + "\n",
		encoding="utf-8"
	)

print("OK: wrote chapter_1.json … chapter_114.json with no gaps")
PY

echo "Done: $OUTDIR/chapter_1.json … chapter_114.json"
