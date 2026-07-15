# Sort HTML Translations Lexically

## Fault

When an HTML verse page contained multiple translations, such as `asv` and
`kjv`, the cards were not guaranteed to appear in lexical order.  The HTML
renderer received verse data in an order determined by the request/backend
path and used that order directly when creating the cards.  As a result, the
same multi-translation page could present the cards in different orders,
making it harder to read translations side by side or track them while moving
through verses.

The problem affected the shared HTML verse renderer used by lookup, random
verse, and verse-of-the-day pages.  JSON/API output was not the problem and
does not need to be reordered by this fix.

## Fix

`Chleb::Server::Moose::__verseToHtml` still groups verse data by translation as
before, preserving each translation's complete text and sentiment data.  Just
before rendering the cards, it now sorts the collected translation identifiers
lexically.  This makes the rendered card order deterministic, so `asv` appears
before `kjv` regardless of the input order.

The sort is applied only at the HTML rendering boundary.  Navigation links,
translation selection, and JSON response ordering are unchanged.

## Regression Coverage

`t/Server_lookup.t` exercises HTML lookup with translations supplied in the
reverse order, `kjv` followed by `asv`, and verifies that the rendered cards
are ordered `asv`, then `kjv`.

`lib/Chleb/Server/Moose.pm` passes Perl syntax checking and the repository
pre-commit checks.  The focused lookup test could not run in the affected
checkout because `data/kjv.sqlite.gz` was missing.
