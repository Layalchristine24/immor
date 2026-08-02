# multi-portal-fetch Specification

## Purpose
TBD - created by archiving change seed-initial-specs. Update Purpose after archive.
## Requirements
### Requirement: Umbrella entry point

The package SHALL expose `immor_fetch(query, portals = NULL, deduplicate = TRUE, max_pages = 5L)` as the single public entry point for aggregating listings across one or more portals.

#### Scenario: Default invocation fetches every registered portal

- **WHEN** a caller invokes `immor_fetch(immor_query())` with `portals = NULL`
- **THEN** the function SHALL iterate over every portal in `immor_portals()` in registration order
- **AND** SHALL inform the user via `cli::cli_inform()` how many portals will be scraped and their names

#### Scenario: Explicit portal subset

- **WHEN** the caller passes `portals = c("flatfox")` (or another subset of registered names)
- **THEN** only the requested portals SHALL be fetched
- **AND** portals not in `immor_portals()` SHALL trigger a `cli::cli_abort()` naming the unknown portal(s) and listing the available portals

### Requirement: Per-portal error isolation

`immor_fetch()` SHALL NOT abort when a single portal fails.

#### Scenario: A portal scraper raises an error

- **WHEN** `fetch_listings(portal, query, max_pages)` throws for one portal
- **THEN** `immor_fetch()` SHALL catch the error via `tryCatch()`, emit `cli::cli_warn()` with the failing portal name and error message
- **AND** SHALL substitute an empty [`immor_schema()`](/R/schema.R) tibble for that portal and continue with the next portal

#### Scenario: Every portal fails

- **WHEN** all portals fail
- **THEN** `immor_fetch()` SHALL return a zero-row tibble conforming to [`immor_schema()`](/R/schema.R)
- **AND** SHALL emit exactly one warning per failing portal

### Requirement: Row aggregation

`immor_fetch()` SHALL combine per-portal results using `dplyr::bind_rows()` and inform the caller of the total.

#### Scenario: Two portals return rows

- **WHEN** flatfox returns N rows and weckaeby returns M rows
- **THEN** the aggregated tibble SHALL have exactly `N + M` rows before deduplication
- **AND** `cli::cli_inform("Found {nrow(result)} listing{?s} total.")` SHALL be called

### Requirement: Optional deduplication

`immor_fetch()` SHALL invoke [`immor_deduplicate()`](/openspec/specs/deduplication/spec.md) exactly when `deduplicate = TRUE` and the aggregate is non-empty.

#### Scenario: Deduplication enabled and rows present

- **WHEN** `deduplicate = TRUE` and the aggregated tibble has `nrow > 0`
- **THEN** the return value SHALL be `immor_deduplicate(aggregate)`

#### Scenario: Deduplication disabled

- **WHEN** the caller passes `deduplicate = FALSE`
- **THEN** the aggregate SHALL be returned unchanged even if duplicates exist across portals

### Requirement: Pagination cap

`immor_fetch()` SHALL forward `max_pages` to every portal's `fetch_listings()` method to bound network work.

#### Scenario: Default cap

- **WHEN** the caller does not override `max_pages`
- **THEN** each portal SHALL receive `max_pages = 5L`

