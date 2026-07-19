# Branch summary: `translation/pickthall/1`

This branch was an experiment to add Muhammad Marmaduke Pickthall's English
translation of the Quran to Chleb Bible Search.

## What was added

- A downloader/parser for the Project Gutenberg Pickthall source:
  `bin/import/quran_fetch_pickthall_from_gutenberg.sh`
- A converter from per-surah JSON into Chleb's flat verse format:
  `bin/import/quran_import.sh`
- A helper for detecting empty ayahs:
  `bin/import/quran_show_missing_verse.sh`
- Generated translation data in `data/static/pickthall.txt`.

The generated file contains 6,236 verses covering all 114 surahs. The
fetcher corrects four known Gutenberg verse-number typos, extracts only the
Pickthall sections, requires every surah to be present, and rejects missing
ayahs.

## Later branch work

On 18 July, current `master` was merged into the branch. A follow-up change
added:

```sh
make -C data
```

to the source-checkout path in `bin/core/run.sh`, so generated SQLite data is
available before development-server startup and warmup.

## What remained unfinished

Pickthall was not yet integrated into the normal build or runtime:

- `data/Makefile` still builds only `asv`, `kjv`, and `core`.
- `bin/import/text-to-sqlite.pl` only knows the existing Bible book ordinals
  and translation metadata for `asv` and `kjv`.
- No Pickthall tests, API documentation, translation metadata, or generated
  `pickthall.sqlite.gz`/`pickthall.bin.gz` files were added.

The branch therefore appears to have completed the text acquisition and
validation stage, while leaving backend/build integration for a subsequent
piece of work.

## Pickthall sentiment-analysis strategy

The repository already contains the required source data in
`data/static/pickthall.txt`. Each line identifies a Quranic verse as:

```text
pickthall:Quran:<surah>:<ayah>::<text>
```

The proposed workflow is:

```text
pickthall.txt
  -> keyed Pickthall JSON
  -> GPT-mini batch analysis
  -> validated keyed JSONL
  -> ordinal data/static/emotion/pickthall.json
  -> pickthall.sqlite.gz
```

The existing emotion/tones API should be reused so no frontend or API change
is required. The analyzer should initially continue using `gpt-4.1-mini`, with
the same output shape:

```json
{
  "primary_emotion": "hope",
  "tones": ["encouragement", "trust"]
}
```

The prompt should be translation-neutral and explicitly refer to the
Pickthall translation of the Quran. It should classify only the emotional
character and communicative tone expressed in the supplied text, without
inferring doctrine, historical context, or the reader's beliefs.

The tagging script should be generalized to accept input and output filenames,
translation, model, and batch size. It should retain the existing batch
fallback behavior, while validating that every input verse receives exactly
one result, IDs match, labels are allowed, tones contain at most three items,
and no verses are missing or duplicated.

The final `pickthall.json` may use the existing positional format:

```json
[
  {
    "emotion": "hope",
    "tones": ["trust"]
  }
]
```

Conversion must verify canonical surah/ayah order before assigning positional
ordinals. A metadata file should record the translation, model, analysis date,
prompt version, input hash, and output count so the analysis can be reproduced.

Before this can work, two Bible-specific assumptions must be removed:

- `bin/maint/openai/tone-discern-simplify.sh` assumes exactly 31,102 records.
- `bin/import/text-to-sqlite.pl` rejects emotion files whose length is not
  31,102.

Both should derive the expected count from the translation input. For
Pickthall, validation should use the number of verses in
`data/static/pickthall.txt`. The existing neutral fallback may remain when an
emotion file is absent, but a present `pickthall.json` should be required and
validated normally.
