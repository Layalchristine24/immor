## Why

Interactive development in RStudio / Positron re-runs `immor_fetch()` frequently. Every invocation today re-fetches all ~33 k flatfox listings and walks every weck-aeby detail page under a mandated 10 s crawl delay. That is slow for the user and impolite toward the portals.

An earlier draft of this change proposed wiring `httr2::req_cache()` into the shared HTTP layer. Live probing revealed that neither current portal advertises the headers `httr2::req_cache()` needs to persist a response (flatfox sends only `Cache-Control: private`; weck-aeby sends no caching headers at all). `httr2::req_cache()` is a well-behaved HTTP client: it will not cache what the server does not mark cacheable, and it does **not** treat `max_age` as a client-side "cache anyway" override. The plumbing worked as coded — it just did nothing on the real endpoints. See design.md, Decision 1 for the diagnosis.

The pivot: cache the **parsed listings** in an on-disk DuckDB database keyed by the `(portals, max_pages, query)` shape. Repeat calls with the same shape return the cached rows without touching the network. The mechanism is portal-agnostic — every future portal ([D1](/doc/roadmap.md) and [D2](/doc/roadmap.md)) inherits it automatically because caching lives above `fetch_listings()` dispatch.

## What Changes

- Add `cache` (default `TRUE`) and `max_age` (default `3600` seconds) arguments to `immor_fetch()`.
- Cache each successful fetch as rows in a DuckDB table `immor_listings` inside `tools::R_user_dir("immor", "cache")`. Table adds two prefix columns — `cache_key` and `cached_at` — over the 28-column [`listing-schema`](/openspec/specs/listing-schema/spec.md).
- On hit within `max_age`, return the cached rows via a `SELECT * EXCLUDE (cache_key, cached_at)` query.
- Cache key: `rlang::hash(list(sort(portals), as.integer(max_pages), unclass(query)))`.
- Honour an `IMMOR_NO_CACHE` env var (values `"1"`, `"true"`, `"yes"`, case-insensitive) as a global kill switch, mirroring the `DO_NOT_TRACK` idiom already documented in [`/CLAUDE.md`](/CLAUDE.md).
- Introduce three exported helpers:
  - `immor_cache_dir()` — returns the cache directory (created lazily).
  - `immor_cache_db_path()` — returns the DuckDB file path inside that directory.
  - `immor_cache_clear()` — deletes the DuckDB file (and any `.wal` sidecar).
- `immor_request()`, portal `fetch_listings.*()` methods, and the `fetch_listings()` generic keep their pre-change signatures — the [`http-layer`](/openspec/specs/http-layer/spec.md) capability is untouched. Caching happens strictly above `fetch_listings()` dispatch, so **new portals ([D1](/doc/roadmap.md), [D2](/doc/roadmap.md)) inherit caching without any change to their code**.
- Fail-open on cache errors: any DuckDB read or write failure emits a one-off `cli::cli_warn()` and continues to a live scrape.
- Add `duckdb` and `DBI` to `Imports`. No changes to `httr2`.

## Capabilities

### New Capabilities

- `listings-cache`: on-disk DuckDB store persisting `immor_fetch()` results, with `immor_cache_dir()` / `immor_cache_db_path()` / `immor_cache_clear()` helpers, the `IMMOR_NO_CACHE` kill switch, and fail-open error handling.

### Modified Capabilities

- `multi-portal-fetch`: `immor_fetch()` gains `cache` and `max_age` arguments; consults [`listings-cache`](/openspec/specs/listings-cache/spec.md) before dispatching to portals, and writes each successful non-empty result back.

## Impact

- **Code touched:** [`/R/fetch-all.R`](/R/fetch-all.R) (cache lookup + write); new file [`/R/cache.R`](/R/cache.R) (all cache helpers). [`/R/http.R`](/R/http.R), [`/R/portal.R`](/R/portal.R), [`/R/portal-flatfox.R`](/R/portal-flatfox.R), and [`/R/portal-weckaeby.R`](/R/portal-weckaeby.R) revert to their pre-change signatures — no `cache` argument leaks below `immor_fetch()`.
- **Public API:** three new exports (`immor_cache_dir()`, `immor_cache_db_path()`, `immor_cache_clear()`); `immor_fetch()` gains `cache = TRUE` and `max_age = 3600` arguments.
- **Filesystem:** first use creates `tools::R_user_dir("immor", "cache")/immor.duckdb`. Documented as safe to delete at any time; `immor_cache_clear()` does the same in R.
- **User messaging:** cache hits emit `cli::cli_alert_info()`; kill-switch and filesystem-fallback notices use `immor_cache_inform_once()` so they fire at most once per session per reason.
- **Documentation:** [`/doc/design.md`](/doc/design.md) §3 is rewritten to describe the DuckDB cache layer; [`/doc/roadmap.md`](/doc/roadmap.md) N1 removed; [`/.github/CONTRIBUTING.md`](/.github/CONTRIBUTING.md) reverts to the pre-cache HTTP rule (new portals do NOT need to plumb `cache` through their signatures).
- **Dependencies:** `duckdb` and `DBI` added to `Imports`. Both are widely used, cross-platform R packages.
- **Tests:** new tests under [`/tests/testthat/`](/tests/testthat/) redirect `R_USER_CACHE_DIR` via `withr::local_envvar()` so the real user cache is untouched. Cover: helper round-trips (write → read), stale expiry, kill switch, per-portal error isolation, cache-key stability across portal-order permutations.
