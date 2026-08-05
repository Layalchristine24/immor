## MODIFIED Requirements

### Requirement: Umbrella entry point

The package SHALL expose `immor_fetch(query, portals = NULL, deduplicate = TRUE, max_pages = 5L, cache = TRUE, max_age = 3600)` as the single public entry point for aggregating listings across one or more portals.

#### Scenario: Default invocation fetches every registered portal

- **WHEN** a caller invokes `immor_fetch(immor_query())` with `portals = NULL`
- **THEN** the function SHALL iterate over every portal in `immor_portals()` in registration order
- **AND** SHALL inform the user via `cli::cli_inform()` how many portals will be scraped and their names — **unless** a cache hit short-circuits the fetch (in which case only the cache-hit `cli_alert_info()` fires)

#### Scenario: Explicit portal subset

- **WHEN** the caller passes `portals = c("flatfox")` (or another subset of registered names)
- **THEN** only the requested portals SHALL be fetched
- **AND** portals not in `immor_portals()` SHALL trigger a `cli::cli_abort()` naming the unknown portal(s) and listing the available portals

#### Scenario: Cache flag defaults to TRUE and consults the listings-cache

- **WHEN** the caller does not pass an explicit `cache` argument
- **THEN** `immor_fetch()` SHALL behave as if `cache = TRUE` was passed
- **AND** it SHALL consult [`listings-cache`](/openspec/specs/listings-cache/spec.md) via `immor_cache_read()` before dispatching to any portal
- **AND** SHALL write the deduplicated result back via `immor_cache_write()` on completion, unless the result is empty or the kill switch is engaged

#### Scenario: max_age controls entry freshness

- **WHEN** the caller passes `max_age = N`
- **THEN** `immor_fetch()` SHALL treat any cached entry younger than `N` seconds as fresh
- **AND** entries older than `N` seconds SHALL be ignored and a live scrape SHALL run
- **AND** `max_age = Inf` accepts any cached entry regardless of age
- **AND** `max_age = 0` forces a re-fetch while still writing the fresh result to the cache

## ADDED Requirements

### Requirement: Cache lookup precedes portal dispatch

`immor_fetch()` SHALL consult the [`listings-cache`](/openspec/specs/listings-cache/spec.md) BEFORE dispatching to any portal's `fetch_listings()` method.

#### Scenario: Cache hit skips all portals

- **WHEN** `immor_cache_read(key, max_age)` returns a non-null tibble
- **THEN** `immor_fetch()` SHALL return that tibble immediately
- **AND** SHALL NOT call `fetch_listings()` on any portal
- **AND** SHALL NOT emit the "Fetching from N portals" `cli_inform()` — only the cache-hit `cli_alert_info()` from `immor_cache_read()`

#### Scenario: Cache miss dispatches to portals

- **WHEN** `immor_cache_read(key, max_age)` returns `NULL` (miss, stale, or read error)
- **THEN** `immor_fetch()` SHALL emit the "Fetching from N portals" `cli_inform()` and dispatch to each portal via `fetch_listings()`
- **AND** SHALL write the aggregated deduplicated result back via `immor_cache_write()` on completion (unless the result is empty or `cache = FALSE`)

### Requirement: Cache does not leak below `fetch_listings()`

`fetch_listings()` and its per-portal methods SHALL retain their pre-caching signatures — the `cache` and `max_age` arguments are consumed entirely by `immor_fetch()`.

#### Scenario: Portal methods take no cache argument

- **WHEN** any registered portal method `fetch_listings.immor_portal_<name>(portal, query, max_pages, ...)` is inspected
- **THEN** its signature SHALL NOT include a `cache` or `max_age` parameter
- **AND** the portal SHALL make its HTTP calls via `immor_request()` without any cache-related decorator

#### Scenario: New portal inherits caching without any change

- **WHEN** a new portal is registered under [`portal-registry`](/openspec/specs/portal-registry/spec.md) and implements the standard `fetch_listings.*()` contract
- **THEN** the umbrella cache SHALL apply automatically because caching happens strictly above the S3 dispatch boundary
- **AND** no cache-specific code in the portal SHALL be required
