# Random and VOTD translation alignment bug

## Symptom

When `/1/random`, `/2/random`, `/1/votd`, or `/2/votd` is requested with
multiple translations, ASV and KJV can display different Bible references.
For example, the ASV card may display `Mat 4:4` while the KJV card displays
`Mat 4:5`.

Those cards represent translations of the same Bible verse and must therefore
have the same book, chapter, and verse reference. The text is expected to
differ; the reference is not.

Pickthall is different. It is a Quran translation with a different canon, so
there is no corresponding `Mat 4:4` reference. Its card may legitimately point
to a different Quranic verse.

## Cause

The defect is in the shared library implementation in `lib/Chleb.pm`, in
`random()` and `votd()`.

Both methods first choose a random or date-derived *global verse ordinal* from
the first selected translation:

```perl
$verseOrdinal = 1 + ($seed % $bible[0]->verseCount);
$verse = $bible[0]->getVerseByOrdinal($verseOrdinal, $args);
```

For version 2 responses, the other translations were then loaded using that
same number independently:

```perl
$bible[$bibleTranslationOrdinal]->getVerseByOrdinal($verseOrdinal, $args)
```

That assumes a translation's global ordinal is a canonical Bible reference.
It is not. The ordinal is an index into that translation's own rows. If ASV
and KJV have different verse-row boundaries or omissions before the selected
point, the same ordinal can resolve to different references.

The existing availability check only compared total verse counts. It could
therefore confirm that ordinal 4 was present in both databases while failing
to confirm that both ordinals referred to the same book/chapter/verse.

## Required behavior

The selection algorithm needs two separate concepts:

1. Select one anchor verse using the existing random or date-derived process.
2. Resolve every other translation relative to that anchor.

When another translation contains the anchor book, it should resolve the
anchor's book, chapter, and verse reference directly. If that exact reference
does not exist, the candidate is unavailable and the algorithm should choose
another anchor, as it already does for unavailable translations.

When another translation does not contain the anchor book, it belongs to a
different canon. It should retain ordinal-based selection so that translations
such as Pickthall can provide their own corresponding-position verse without a
hard-coded Pickthall exception.

This makes the rule structural and translation-neutral:

```text
same book exists in candidate translation?
  yes -> use the anchor's book/chapter/verse reference
  no  -> use the candidate's verse ordinal
```

The same logic must be used by both `random()` and `votd()`, and by their
version 2 multi-translation responses. Version 1 still returns only the anchor
verse, but it must use the same availability decision so that a later request
does not expose an invalid multi-translation selection.

## Regression coverage

Tests should verify both properties independently:

- A random version 2 request for `asv,kjv` returns the same book, chapter, and
  verse ordinal for both cards.
- A VOTD version 2 request for `asv,kjv` does the same for a fixed date.
- A request containing a translation with a different canon, such as
  `kjv,pickthall`, still returns both translations and does not require the
  Pickthall card to use a Bible reference.
- If a candidate contains the anchor book but lacks the exact verse, random
  and VOTD retry with another anchor rather than silently shifting the
  candidate to its next ordinal.
