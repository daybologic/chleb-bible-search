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
