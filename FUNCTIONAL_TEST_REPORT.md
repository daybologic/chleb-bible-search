# Functional Test Coverage Report

This report compares the operations and parameters documented in `swagger.yaml`
with the functional tests under `data/tests/**/*.sh`.

The suite has broad endpoint smoke coverage, but many tests only assert HTTP
success rather than response semantics.

| Priority | Area | Untested or weakly tested scenario | Current coverage |
|---|---|---|---|
| High | Lookup | Direct chapter route `/1/lookup/{book}/{chapter}` | No functional test appears to request a chapter path without a verse. |
| High | Lookup | Direct verse route in HTML mode | Existing HTML lookup tests exercise the query/form route, not `/1/lookup/{book}/{chapter}/{verse}` with `Accept: text/html`. |
| High | Lookup | Query compatibility route with `submit=lookup` | `/1/lookup` is tested as a form and redirect, but not the documented form-submit action. |
| High | Lookup | `navigation=true` behavior | Swagger documents it, but no functional test explicitly exercises it. |
| High | Lookup | Invalid/missing book, chapter, and verse values | There is a generic invalid-book test, but no systematic 400/404 coverage for malformed ordinals, nonexistent chapters, or nonexistent verses. |
| High | Lookup | Multi-translation chapter/verse responses | Tests mostly use the default translation or a preferred translation. There is no strong functional assertion for ordered `translations=asv,kjv,pickthall` lookup output. |
| High | Search | Pagination semantics | Cookie/default limits are tested, but explicit `page`, `per_page`, `limit`, next/previous links, last page, empty page, and maximum `per_page=2000` are not comprehensively tested. |
| High | Search | Search result semantics in JSON | Several scripts only check that HTTPie succeeds. They do not assert returned verses, translation ordering, summary counts, links, or stats. |
| High | Search | No-result HTML suggestions | JSON suggestions are tested, but the HTML “Did you mean” line and its links are not functionally tested. |
| High | Search | Thesaurus behavior across translations | Thesaurus is tested for ASV, but not KJV, Pickthall, all translations, translation ordering, or exclusion when `wholeword=true`. |
| High | Search | Search form with invalid combinations | No test covers `form=true` with JSON, missing `term` without form, invalid booleans, invalid pagination values, or unsupported content types. |
| High | Search | Translation-specific result ordering | Search tests do not strongly assert `translations=asv,kjv`, reversed order, or Pickthall result ordering. |
| High | Random | Testament filtering | Swagger exposes `testament=old|new|any`; no functional test explicitly verifies each value. |
| High | Random | Parental filtering | `parental=true` is documented but not functionally tested. |
| High | Random | Translation selection/order | HTML tests cover ASV/KJV ordering, but not Pickthall, `all`, JSON ordering, or stable verse identity across translations. |
| High | Random | JSON response contents | Random JSON tests generally assert only that the request succeeds; they do not validate `data`, `included`, translation, links, or stats. |
| High | VoTD | Testament filtering | No functional test explicitly covers `testament=old`, `new`, or `any`. |
| High | VoTD | Parental filtering | `parental=true` is documented but untested. |
| High | VoTD | Translation selection with Pickthall/all | Current tests cover ASV/KJV ordering, but not Pickthall or all-translation output and stable same-date verse identity. |
| High | VoTD | JSON response semantics for a fixed date | The HTML form test uses a fixed date, but JSON does not assert the returned verse/book/date or cross-translation alignment. |
| High | VoTD | `date` versus `when` precedence | Both parameters are documented, but their interaction is not tested. |
| High | VoTD | Invalid date/time values | No functional tests cover malformed ISO-8601 values, invalid calendar dates, or unsupported timezone forms. |
| High | HTTP errors | All error codes with full body/header semantics | The error loops exercise all registered codes in HTML and JSON, but assertions are generic (`<main>` or `"status"`). They do not verify each error page’s title, image, diagnostic text, or required headers. |
| Medium | HTTP errors | Content negotiation failures | No test requests an unsupported `Accept` value, missing `Accept`, or conflicting media types and verifies `406` behavior. |
| Medium | HTTP errors | Error response `Content-Type` charset/body contract | Tests check a prefix, but not exact content type, JSON shape, error title/detail, or escaped diagnostic content. |
| Medium | Info | JSON response structure | `/1/info` JSON is only a successful smoke request; no assertions cover translation/book/chapter counts, stats, or links. |
| Medium | Info | Rate limiting | Swagger declares `429`, but no functional test intentionally reaches or verifies rate limiting for `/1/info`. |
| Medium | Uptime | JSON/HTML semantic content | Tests only check successful responses; uptime shape and numeric value are not asserted. |
| Medium | Ping | JSON/HTML body contract | Tests do not assert `pong` content, JSON structure, or low-overhead response shape. |
| Medium | Version | Forbidden configuration | Swagger documents `403`, but no functional test verifies behavior when version exposure is disabled. |
| Medium | Version | Version payload semantics | The JSON test obtains a response but does not assert version format or consistency with package metadata. |
| Medium | Random/VoTD | Declared upstream failure responses | Swagger lists `500`, `502`, `503`, and `504`, but there are no functional tests for those endpoint-specific failure responses. |
| Medium | All endpoints | Rate limiting | Every major endpoint documents `429`, but there is no functional rate-limit scenario. |
| Medium | All endpoints | Unsupported methods | No tests verify `POST`, `PUT`, or `DELETE` behavior on GET-only routes. |
| Medium | All endpoints | Query encoding and special characters | No tests cover URL-encoded book names, terms, apostrophes, Unicode, or duplicate query parameters. |
| Medium | All endpoints | Translation validation | No functional tests cover unknown translations, empty translation lists, duplicate translations, or malformed comma-separated values. |
| Medium | All endpoints | Default `Accept` behavior | Some default-accept tests exist, but the suite does not systematically verify the documented/default media type for every route. |
| Medium | HTML | Timing display | The HTML timing line was recently added, but the functional suite does not assert `Sought in ... seconds` on lookup, random, VoTD, search, or info pages. |
| Medium | HTML | Navigation links | HTML tests check selected page fragments, but not previous/next verse, chapter, book, VoTD date, or translation-preserving links. |
| Low | Test endpoint | Unsupported status code | The Swagger enum is exhaustive, but there is no test for a non-enum status such as `418` or `599` to verify rejection behavior. |
| Low | Static/UI | Settings/template/index interactions | These are tested as pages, but not their generated API requests or behavior after selecting translations/preferences. |
| Low | Session | JWT round trip | The session test exists, but Swagger has no corresponding route documentation; its relationship to the public API is not represented in the route matrix. |

## Most significant gaps

The most significant concrete gap is the chapter lookup route. Current lookup
coverage includes:

- query/form `/1/lookup`;
- direct verse JSON/default `/1/lookup/prov/16/18`;
- redirect behavior for query lookup.

It does not appear to exercise `/1/lookup/prov/16` as a chapter response, despite
that being a separately documented Swagger operation.

The next most important gaps are:

1. The documented `testament` and `parental` parameters on `/2/random` and
   `/2/votd`.
2. Pickthall and all-translation behavior.
3. Search pagination and page-link semantics.
4. HTML no-result suggestions and suggestion links.
5. JSON response-content assertions rather than success-only smoke checks.

## Scope of completing the high-priority gaps

Covering all high-priority gaps is reasonable as one coordinated coverage
effort, but it is larger than a mechanical test-writing pass. The gaps span
lookup route/form/error semantics; search pagination, suggestions, thesaurus,
and translation behavior; random filtering and response contents; VoTD date,
filter, and translation stability; and HTTP error/content-negotiation details.

Some tests can be added immediately. Others may expose implementation or
Swagger inconsistencies, especially:

- `/1/lookup/{book}/{chapter}`;
- `testament` and `parental` filtering;
- Pickthall and all-translation behavior;
- `date` versus `when` precedence;
- pagination edge cases;
- HTML suggestion links.

A practical execution sequence is:

1. Add tests for behavior already supported by the implementation.
2. Run the functional suite and classify failures.
3. Fix implementation or documentation mismatches.
4. Add the remaining assertions and edge cases.
5. Commit the completed coverage as one focused change, or split it if fixes
   become materially independent.

The expected scope is approximately 15–25 functional scenarios, with several
iterations likely because some tests may reveal real implementation defects or
out-of-date Swagger descriptions.
