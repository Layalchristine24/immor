# listings-cache Specification

## Purpose
TBD - created by archiving change http-response-caching. Update Purpose after archive.
## Requirements
### Requirement: Cache directory contract

The package SHALL expose an `immor_cache_dir()` helper that returns the on-disk root used to store the DuckDB cache database.

#### Scenario: Default cache root follows R user-dir convention

- **WHEN** `immor_cache_dir()` is called with no environment override
- **THEN** it SHALL return `tools::R_user_dir("immor", "cache")` as a length-1 character vector
- **AND** it SHALL create the directory lazily on first use via `dir.create(..., recursive = TRUE, showWarnings = FALSE)`

#### Scenario: Cache directory is exported and documented

- **WHEN** a user calls `immor::immor_cache_dir()`
- **THEN** the function SHALL be an exported function with roxygen `@return` and `@examples` tags

### Requirement: DuckDB file location

The package SHALL expose an `immor_cache_db_path()` helper that returns the full path to the DuckDB file inside `immor_cache_dir()`.

#### Scenario: File name is deterministic

- **WHEN** `immor_cache_db_path()` is called
- **THEN** it SHALL return `file.path(immor_cache_dir(), "immor.duckdb")` as a length-1 character vector

### Requirement: Programmatic cache purge

The package SHALL expose an `immor_cache_clear()` helper for purging the cache without requiring the user to know the on-disk path.

#### Scenario: Successful purge

- **WHEN** `immor_cache_clear()` is called and the DuckDB file exists
- **THEN** the function SHALL delete the DuckDB file (and any `.wal` sidecar left by DuckDB)
- **AND** it SHALL emit `cli::cli_alert_success()` naming the removed files
- **AND** it SHALL return the DuckDB path invisibly

#### Scenario: Missing cache is a no-op

- **WHEN** `immor_cache_clear()` is called before any cache has been written
- **THEN** the function SHALL return the path invisibly without raising an error
- **AND** it SHALL emit `cli::cli_alert_info()` stating that the cache is already empty

### Requirement: Cache schema

The DuckDB cache SHALL persist each fetch result in a single table `immor_listings` whose columns are the 28 columns of [`listing-schema`](/openspec/specs/listing-schema/spec.md) prefixed with two cache-metadata columns.

#### Scenario: Table columns

- **WHEN** the first cache write executes
- **THEN** the table `immor_listings` SHALL be created with columns `(cache_key VARCHAR, cached_at TIMESTAMPTZ, ...)`
- **AND** the remaining columns SHALL match [`listing-schema`](/openspec/specs/listing-schema/spec.md) types verbatim, including `images VARCHAR[]` for the list-of-character image URL column
- **AND** date columns SHALL round-trip as `Date`, timestamp columns as `POSIXct`, and logical columns as `logical` on read

### Requirement: Cache-key construction

The package SHALL compute the cache key as `rlang::hash(list(sort(portals), as.integer(max_pages), unclass(query)))`.

#### Scenario: Key is order-independent for portals

- **WHEN** `immor_cache_key(c("flatfox", "weckaeby"), 5L, immor_query())` and `immor_cache_key(c("weckaeby", "flatfox"), 5L, immor_query())` are compared
- **THEN** the two keys SHALL be identical

#### Scenario: Key differs on max_pages

- **WHEN** `immor_cache_key(c("flatfox"), 5L, immor_query())` and `immor_cache_key(c("flatfox"), 10L, immor_query())` are compared
- **THEN** the two keys SHALL differ

### Requirement: Global kill switch via `IMMOR_NO_CACHE`

The package SHALL honour an `IMMOR_NO_CACHE` environment variable that, when truthy, disables cache reads and writes globally regardless of per-call arguments.

#### Scenario: Truthy value disables caching

- **WHEN** `IMMOR_NO_CACHE` is set to `"1"`, `"true"`, `"TRUE"`, `"yes"`, or `"YES"` (case-insensitive)
- **AND** the caller invokes `immor_fetch()` with `cache = TRUE`
- **THEN** `immor_fetch()` SHALL neither read from nor write to the DuckDB cache
- **AND** it SHALL emit exactly one `cli::cli_inform()` per session naming `IMMOR_NO_CACHE`

#### Scenario: Unset or falsy value leaves caching under caller control

- **WHEN** `IMMOR_NO_CACHE` is unset, empty, `"0"`, `"false"`, or `"no"`
- **THEN** the `cache` argument to `immor_fetch()` SHALL determine whether the cache is consulted and populated

### Requirement: Fail-open on cache errors

Cache read and write failures SHALL degrade to a live scrape rather than propagating errors to the caller.

#### Scenario: Read failure returns NULL to the caller

- **WHEN** a DuckDB read errors (locked file, corrupt DB, missing table)
- **THEN** the internal cache-read helper SHALL return `NULL`
- **AND** `immor_fetch()` SHALL proceed to scrape as if there was a cache miss

#### Scenario: Write failure emits a one-off warning

- **WHEN** a DuckDB write errors
- **THEN** the internal cache-write helper SHALL emit at most one `cli::cli_warn()` per session per failure mode
- **AND** it SHALL return without propagating the error to the caller

