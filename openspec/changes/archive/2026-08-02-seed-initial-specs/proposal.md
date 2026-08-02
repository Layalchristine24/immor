## Why

immor has grown to a working two-portal scraper (flatfox.ch + weck-aeby.ch) with a 28-column canonical schema, type-safe validation, deduplication, and rate-limited HTTP — but none of its behavioural contracts are yet captured under [`openspec/specs/`](/openspec/specs/). Every future change would have to reverse-engineer the current shape from source before it could describe a delta. This seed change captures the current architecture as ADDED requirements in nine capability specs so that all future work has a stable baseline to diff against.

This is a docs-only change: no R code, no schema, no dependency, and no runtime behaviour changes. It captures what already exists.

## What Changes

- Add nine new capability specs under `openspec/specs/` covering the current public API and internal contracts.
- Each capability's `spec.md` documents the CURRENT observable behaviour of the code in [`R/`](/R/), citing the exact function that owns each requirement.
- No R/, tests/, DESCRIPTION, NAMESPACE, or NEWS.md changes. No behaviour changes.

## Capabilities

### New Capabilities

- `multi-portal-fetch`: Umbrella orchestration — `immor_fetch(query, portals, deduplicate, max_pages)` iterates registered portals, catches per-portal errors, aggregates into a single tibble, and optionally deduplicates.
- `query-construction`: `immor_query()` — the no-argument S3 constructor consumed by every portal `fetch_listings` method. `print.immor_query()` companion.
- `listing-schema`: `immor_schema()` — the 28-column canonical zero-row tibble. Common-denominator approach; missing portal fields become `NA`.
- `type-enforcement`: `ensure_type()` + `try_ensure_type()` (a `vctrs::vec_cast()` wrapper) and `validate_listings()`, invoked by every portal's `fetch_listings` method at its exit point.
- `http-layer`: `immor_request()` — the shared `httr2` builder that adds user-agent identification, per-host rate throttling, and 3-attempt exponential backoff retry.
- `portal-registry`: `new_portal()` constructor + `immor_portals()` registry + `immor_portal()` lookup, plus the `fetch_listings()` / `parse_listing()` S3 generics with their default-method errors.
- `portal-flatfox`: `portal_flatfox()` — the flatfox.ch REST-API scraper (`/api/v1/public-listing/`) with offset/limit pagination, `-published` ordering, and the flatfox-specific offer/property-type normalisation.
- `portal-weckaeby`: `portal_weckaeby()` — the weck-aeby.ch HTML scraper (CasaWP WordPress plugin) with two-stage archive→detail fetch, 10-second crawl delay, and CasaWP-specific parsers (`weckaeby_parse_price`, `weckaeby_parse_address`, `weckaeby_parse_details_block`, `weckaeby_extract_pk`).
- `deduplication`: `immor_deduplicate(listings, method = "exact")` — exact matching on `(address_zip, address_street, rooms, price)`, first-occurrence-by-portal wins.

### Modified Capabilities

None. There are no pre-existing capability specs to modify.

## Impact

- **Code**: none. Purely additive to `openspec/specs/`.
- **APIs**: no public API change.
- **Dependencies**: none.
- **Systems affected**: OpenSpec — future changes now have a diff baseline. AI agents (Claude Code, Cursor, Copilot) can cite specs when asked "how does X work" per the guidance in [`/CLAUDE.md`](/CLAUDE.md).
- **Docs**: [`/doc/design.md`](/doc/design.md) and [`/doc/portals.md`](/doc/portals.md) remain the human-reading map; the new specs are the machine-readable contract.
