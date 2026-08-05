## MODIFIED Requirements

### Requirement: Umbrella entry point

The package SHALL expose `immor_fetch(query, portals = NULL, deduplicate = TRUE, max_pages = 5L, cache = TRUE)` as the single public entry point for aggregating listings across one or more portals.

#### Scenario: Default invocation fetches every registered portal

- **WHEN** a caller invokes `immor_fetch(immor_query())` with `portals = NULL`
- **THEN** the function SHALL iterate over every portal in `immor_portals()` in registration order
- **AND** SHALL inform the user via `cli::cli_inform()` how many portals will be scraped and their names

#### Scenario: Explicit portal subset

- **WHEN** the caller passes `portals = c("flatfox")` (or another subset of registered names)
- **THEN** only the requested portals SHALL be fetched
- **AND** portals not in `immor_portals()` SHALL trigger a `cli::cli_abort()` naming the unknown portal(s) and listing the available portals

#### Scenario: Cache flag defaults to TRUE

- **WHEN** the caller does not pass an explicit `cache` argument
- **THEN** `immor_fetch()` SHALL behave as if `cache = TRUE` was passed
- **AND** the choice SHALL be documented at the `?immor_fetch` help page along with `cache = FALSE` and the `IMMOR_NO_CACHE` env-var opt-out

## ADDED Requirements

### Requirement: Cache forwarding is portal-agnostic

`immor_fetch()` SHALL forward its `cache` argument to every portal's `fetch_listings()` method via the S3 generic signature, with no per-portal branching inside `immor_fetch()`.

#### Scenario: Cache argument reaches every portal method

- **WHEN** `immor_fetch(query, cache = TRUE)` is called
- **THEN** each dispatched `fetch_listings.immor_portal_<name>(portal, query, max_pages, cache)` call SHALL receive `cache = TRUE`
- **AND** each dispatched call SHALL receive `cache = FALSE` when the umbrella call passes `cache = FALSE`

#### Scenario: Adding a new portal requires no fetch-layer changes

- **WHEN** a new portal is registered under [`portal-registry`](/openspec/specs/portal-registry/spec.md)
- **AND** its `fetch_listings.immor_portal_<name>()` method accepts the `cache` argument per the [`http-layer`](/openspec/specs/http-layer/spec.md) contract
- **THEN** no changes to `immor_fetch()`'s signature, dispatch loop, or error handling SHALL be required for caching to work for that portal

### Requirement: Cache flag interacts correctly with per-portal error isolation

`immor_fetch()`'s `tryCatch()`-based isolation SHALL treat cache errors like any other portal error — failing that portal, substituting an empty schema tibble, and continuing with the next portal.

#### Scenario: Cache-related portal failure is isolated

- **WHEN** one portal's `fetch_listings()` raises an error whose root cause is the cache layer (already degraded to fail-open per [`http-layer`](/openspec/specs/http-layer/spec.md), so this is an exceptional case)
- **THEN** `immor_fetch()` SHALL catch the error via `tryCatch()` and emit `cli::cli_warn()` naming the failing portal
- **AND** SHALL substitute an empty [`immor_schema()`](/R/schema.R) tibble for that portal and continue with the next portal
