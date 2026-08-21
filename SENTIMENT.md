# Regenerating DR sentiment data

Run these commands from the repository root. The OpenAI client requires
`OPENAI_API_KEY` to be configured.

Set up the Python dependency once in an isolated environment:

```bash
python3 -m venv .venv-openai
. .venv-openai/bin/activate
python -m pip install --upgrade pip openai
```

If `venv` is unavailable, install the distribution package providing it (for
example, `python3-venv` on Debian) and retry.

```bash
dr_sentiment_tmp=$(mktemp -d /var/tmp/chleb-dr-sentiment.XXXXXX)

python3 bin/maint/openai/tone-discern.py \
  --input data/static/dr.txt \
  --translation dr \
  --output "$dr_sentiment_tmp/dr.jsonl" \
  --batch-size 25

bin/maint/openai/tone-discern-simplify.sh \
  -i "$dr_sentiment_tmp/dr.jsonl" \
  -o "$dr_sentiment_tmp/dr.json"

jq -e 'length == 35744 and all(.[]; has("emotion") and has("tones"))' \
  "$dr_sentiment_tmp/dr.json"

cp "$dr_sentiment_tmp/dr.json" data/static/emotion/dr.json
```

The validation must report success with 35,744 sentiment entries. Rebuild the
core SQLite database after replacing the JSON file:

```bash
bin/import/text-to-core.sh
```

The tagging step makes thousands of API requests and may incur substantial
runtime and API cost.
