## MODIFIED Requirements

### Requirement: Shared request builder

The package SHALL provide an internal `immor_request(req, delay = 2, cache = FALSE, max_age = Inf)` builder that decorates every outbound `httr2` request with a shared set of policies, including an opt-in on-disk response cache.

#### Scenario: Every portal HTTP call routes through the builder

- **WHEN** any portal `fetch_listings.immor_portal_<name>()` (or its helpers) issues an HTTP request
- **THEN** the request SHALL be constructed via `httr2::request(...) |> immor_request(...)` before `httr2::req_perform()`
- **AND** portal code SHALL NOT call `httr2::req_user_agent()`, `httr2::req_throttle()`, `httr2::req_retry()`, or `httr2::req_cache()` directly

#### Scenario: Cache decorator applied when opted in

- **WHEN** `immor_request()` is called with `cache = TRUE`
- **THEN** the returned request SHALL include a `httr2::req_cache()` decorator pointing at [`immor_cache_dir()`](/R/cache.R) with the given `max_age`
- **AND** the cache decorator SHALL be applied BEFORE the throttle and retry decorators so cache hits skip both throttle and network

#### Scenario: Cache omitted when opted out

- **WHEN** `immor_request()` is called with `cache = FALSE` (the default) or when the global kill switch is engaged
- **THEN** the returned request SHALL NOT include a `httr2::req_cache()` decorator
- **AND** the request SHALL behave identically to the pre-caching contract

## ADDED Requirements

### Requirement: Cache directory contract

The package SHALL expose an `immor_cache_dir()` helper that returns the on-disk root used by `httr2::req_cache()` when caching is opted in.

#### Scenario: Default cache root follows R user-dir convention

- **WHEN** `immor_cache_dir()` is called with no environment override
- **THEN** it SHALL return `tools::R_user_dir("immor", "cache")` as a length-1 character vector
- **AND** it SHALL create the directory lazily on first use via `dir.create(..., recursive = TRUE, showWarnings = FALSE)`

#### Scenario: Cache directory is exported

- **WHEN** a user calls `immor::immor_cache_dir()`
- **THEN** the function SHALL be an exported, documented function with `@examples` and `@return` roxygen tags

### Requirement: Programmatic cache purge

The package SHALL expose an `immor_cache_clear()` helper for purging the cache directory contents in R without requiring the user to know the on-disk path.

#### Scenario: Successful purge

- **WHEN** `immor_cache_clear()` is called and the cache directory exists
- **THEN** the function SHALL delete every entry inside `immor_cache_dir()` (but not the directory itself)
- **AND** it SHALL emit a `cli::cli_alert_success()` naming the directory and the number of entries removed
- **AND** it SHALL return the path invisibly

#### Scenario: Missing cache directory is a no-op

- **WHEN** `immor_cache_clear()` is called before any cache has been written
- **THEN** the function SHALL return the path invisibly without raising an error
- **AND** it SHALL emit `cli::cli_alert_info()` stating that the cache was already empty

### Requirement: Global kill switch via `IMMOR_NO_CACHE`

The package SHALL honour an `IMMOR_NO_CACHE` environment variable that, when truthy, disables caching globally regardless of per-call arguments.

#### Scenario: Truthy value disables caching

- **WHEN** `IMMOR_NO_CACHE` is set to `"1"`, `"true"`, `"TRUE"`, `"yes"`, or `"YES"` (case-insensitive)
- **AND** any caller passes `cache = TRUE` to `immor_request()`
- **THEN** the returned request SHALL NOT include a `httr2::req_cache()` decorator
- **AND** `immor_request()` SHALL behave as though `cache = FALSE` had been passed

#### Scenario: Unset or falsy value leaves caching under caller control

- **WHEN** `IMMOR_NO_CACHE` is unset, empty, `"0"`, `"false"`, or `"no"`
- **THEN** the value of the `cache` argument passed to `immor_request()` SHALL determine whether the decorator is applied

#### Scenario: One-time inform on kill switch

- **WHEN** the kill switch is engaged for the first time in an R session and a caller requests caching
- **THEN** the package SHALL emit exactly one `cli::cli_inform()` naming `IMMOR_NO_CACHE` so the user understands why cache flags appear ineffective

### Requirement: TTL is a caller concern, not a builder concern

`immor_request()` SHALL accept `max_age` in seconds and forward it verbatim to `httr2::req_cache()` when caching is opted in, without imposing a package-level default TTL.

#### Scenario: Default `max_age` is `Inf`

- **WHEN** `immor_request()` is called with `cache = TRUE` and no explicit `max_age`
- **THEN** the `httr2::req_cache()` decorator SHALL be applied with `max_age = Inf`
- **AND** the cache entry SHALL never expire from TTL alone (evictable only by `immor_cache_clear()` or manual deletion)

#### Scenario: Portal callers supply endpoint-appropriate TTL

- **WHEN** a portal fetches an archive / index page
- **THEN** it SHOULD pass `max_age = 3600` (one hour) to `immor_request()`
- **AND** when fetching a listing detail page it SHOULD pass `max_age = 86400` (24 hours)
- **AND** portal implementations MAY deviate with documented rationale

### Requirement: Fail-open on cache errors

`immor_request()` SHALL degrade to an uncached live request when the cache layer fails at request time (permission denied, corrupt cache entry, disk full).

#### Scenario: Cache write failure falls through to network

- **WHEN** `httr2::req_perform()` on a cache-decorated request raises an error attributable to the cache layer (e.g. filesystem-related)
- **THEN** `immor_request()`'s caller SHALL retry the request without the cache decorator and return the live response
- **AND** the package SHALL emit exactly one `cli::cli_warn()` per session per failure mode explaining the fallback

### Requirement: Portal registry contract for caching

Every portal method under [`portal-registry`](/openspec/specs/portal-registry/spec.md) SHALL route HTTP requests through `immor_request()` with a `cache` argument passed through from `fetch_listings()`, so caching is inherited without portal-specific plumbing.

#### Scenario: New portal inherits caching by contract

- **WHEN** a new portal is added under `portal-registry` and its `fetch_listings.immor_portal_<name>()` calls `immor_request()`
- **THEN** the portal SHALL accept a `cache` parameter and forward it to every `immor_request()` invocation
- **AND** no code changes to `immor_request()` or `immor_fetch()` SHALL be required to enable caching for that portal
