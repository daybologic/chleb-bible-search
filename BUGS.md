# Known concerns

## Sentiment warnings when using the multi-translation SQLite bundle

The service logs warnings such as:

```text
No sentiment entry for verse at ordinal 55174
```

This does not necessarily mean that the sentiment data is absent. The packaged
`free.sqlite.gz` contains ASV, KJV, and DR, giving it 97,948 verses in total,
while each translation has its own translation-local sentiment entries. The backend currently
calculates an absolute ordinal with a window function over all verses in the
bundle. It then uses that ordinal to index the sentiment array for one
translation.

Consequently, an ordinal can refer to the combined dataset while the sentiment
array is translation-local. For example, `Acts 19:1` has ordinal 27,587 in a
standalone KJV database but a different absolute ordinal in the combined bundle.
Looking up that combined ordinal in the KJV sentiment array can fall outside its
translation-local entries, so the backend logs a warning and returns its neutral
fallback.

The burst of warnings for `/1/lookup/acts/19` is explained by that endpoint
returning the whole chapter and attempting to render sentiment for each verse.
Pickthall remains separate because it is an optional translation package.

The ordinal calculation must be made translation-local when reading a
multi-translation SQLite file. Filtering the translation before applying
`ROW_NUMBER()`, or partitioning the window function by translation, would make
the ordinal suitable for sentiment lookup. The reverse ordinal lookup should
be reviewed for the same defect.

## Suspicious automated clients and changing User-Agent values

The log also shows a client whose session User-Agent changes from an empty value
to a Chrome User-Agent. That is suspicious and may indicate a bot, a crawler,
or several clients sharing session-related state. It should be investigated as
a service-abuse or session-integrity concern.

However, it is separate from the sentiment warning. The warnings shown in the
example come from different IP addresses, and the shortened JWT prefix in the
log is not sufficient to establish that they share one token: JWTs with the
same signing format commonly share the same encoded header prefix.

The User-Agent change should therefore not be treated as the cause of the
missing-sentiment messages. Useful follow-up work would be to log a safe token
identifier, retain the full request path and query parameters in diagnostic
logs, and determine whether User-Agent changes should invalidate or merely
update a session token.
