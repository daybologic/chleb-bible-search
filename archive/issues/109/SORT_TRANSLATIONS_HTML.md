# Sort HTML Translations Lexically

## Fault

When an HTML verse page requested all translations, such as `asv` and `kjv`,
the cards were not guaranteed to appear in lexical order.  The random-verse
path shuffled the selected Bible objects before creating its multi-translation
verse, and the HTML renderer used that order directly when creating cards.  As
a result, the same page could present the cards in different orders, making it
harder to read translations side by side or track them while moving through
verses.

The problem affected the shared HTML verse renderer used by lookup, random
verse, and verse-of-the-day pages.  JSON/API output was not the problem and
does not need to be reordered by this fix.

## Fix

Translation normalization now removes duplicates while preserving explicit
request order.  The reserved `all` value expands to the canonical lexical
list, `asv` followed by `kjv`.  The random path no longer shuffles translation
objects, so the normalized order reaches the shared HTML renderer unchanged.
`Chleb::Server::Moose::__verseToHtml` groups and renders cards in that order.

Consequently, `translations=all` renders `asv` before `kjv`, while an explicit
request such as `translations=kjv,asv` renders `kjv` before `asv`.

The ordering policy applies consistently to HTML and JSON response data.
Navigation links and translation selection remain unchanged.

## Regression Coverage

`t/Server_lookup.t` exercises HTML lookup with translations supplied in the
reverse order, `kjv` followed by `asv`, and verifies that the rendered cards
are ordered `asv`, then `kjv`.

`lib/Chleb/Server/Moose.pm` passes Perl syntax checking and the focused lookup
test passes all 4 subtests.  The shared test base now runs `make -C data` when
generated Bible artifacts are missing, so direct targeted test invocations no
longer fail merely because ignored build outputs have not been generated.
