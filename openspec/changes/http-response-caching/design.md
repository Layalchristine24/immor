## Context

Every outbound HTTP call in the package flows through [`immor_request()`](/R/http.R). Today the function is nine lines: user-agent → throttle → retry. Portals never call `httr2::request()` directly (enforced by the [`http-layer`](/openspec/specs/http-layer/spec.md) contract).

Two portals ship today: `flatfox` (REST JSON, ~33 k listings, `-published` sort, no crawl delay declared) and `weckaeby` (HTML archive + detail two-stage, 10 s crawl delay). Interactive users re-run `immor_fetch()` frequently, and every re-run pays the full network cost even though listing pages are stable for minutes at a time. The problem is not correctness — it is friction and portal politeness.

The roadmap plans to grow this from two portals to potentially dozens: [D1](/doc/roadmap.md) (five large Swiss portals, if bot protection ever lifts) and [D2](/doc/roadmap.md) (~200 CasaWP-based agency sites). Any caching design must scale with that growth without per-portal special-casing.

**This design pivoted mid-implementation.** The original plan was to wire `httr2::req_cache()` into `immor_request()` (see Decision 1). Live probing revealed neither portal is cacheable at the HTTP layer, so we moved the cache one level up — over the parsed listings — using DuckDB.

## Goals / Non-Goals

**Goals:**

- Repeat `immor_fetch()` calls with the same `(portals, max_pages, query)` shape within `max_age` seconds skip the network entirely.
- The mechanism is opt-in per call (`cache = TRUE / FALSE`), globally kill-switchable (`IMMOR_NO_CACHE=1`), and takes a caller-controlled `max_age` in seconds.
- Adding a new portal (D1 or D2) requires zero changes to the caching mechanism itself — the portal only implements `fetch_listings.immor_portal_<name>()` as before.
- Test isolation: tests never write into the real `R_user_dir("immor", "cache")`.
- Fail open: any DuckDB read or write error MUST degrade to a live scrape, not to an aborted call.
- Cache preserves the 28-column [`listing-schema`](/openspec/specs/listing-schema/spec.md) exactly — including list columns (`images`), date columns (`available_from`), and logical columns (`has_balcony`).

**Non-Goals:**

- Distributed caching, S3 backends, or shared team caches. Single-user, single-machine only.
- Per-URL granularity. If the user re-runs `immor_fetch()` after `max_age` expires, all portals rescrape — even if only one has changed. Adding per-portal or per-URL granularity is a future refinement (see Open Questions).
- Snapshot history / time-travel over cache entries. A new fetch's rows share the same `cache_key + cached_at`; older rows for the same key remain in the table until [`immor_cache_clear()`](/R/cache.R) removes them.
- DuckLake — DuckDB's lakehouse table format is too new (2024/2025) and adds substantial complexity (Parquet sidecar files, metadata catalog, snapshots) for what is essentially a session cache.
- HTTP-response-level caching. See Decision 1 — `httr2::req_cache()` cannot help with the current portals.
- Caching HTTP errors (`4xx`, `5xx`). Only successful fetches (returned tibble) reach the write step.

## Decisions

### Decision 1: DuckDB over `httr2::req_cache()`

**What:** cache the parsed listings tibble in a DuckDB table, not the raw HTTP responses.

**Why the pivot happened:** the first attempt wired `httr2::req_cache()` into `immor_request()`. Live probes against both portals revealed:

- **flatfox** sends `Cache-Control: private` with no `max-age`, no `ETag`, no `Last-Modified`, no `Expires`.
- **weck-aeby** sends none of `Cache-Control`, `ETag`, `Last-Modified`, `Expires`.

`httr2::resp_is_cacheable()` (inspected against `httr2 v1.0.7`) returns `TRUE` only if the response is a `200 OK` GET **AND** at least one of these is present:

- `Cache-Control: max-age=<N>` — set by server.
- `ETag` header.
- `Last-Modified` header.
- `Expires` header.

Neither portal's responses trigger any of those conditions, so `req_cache()` silently skipped every write. The `max_age` argument to `req_cache()` is a *maximum-age cap* for entries that would have been cached anyway — it does not force caching. This is by design in httr2; the library follows RFC 7234 semantics rather than acting as a "just cache everything" store.

**Why DuckDB, not RDS or Parquet:**

- **RDS** (`saveRDS()`) works fine but gives no SQL surface and no ability to keep multiple cache-keys in one file elegantly. Fine for a one-off snapshot; awkward for a keyed store.
- **Parquet via `arrow`** is portable but adds `arrow` (~30 MB installed) and needs a sidecar catalog file to key entries.
- **DuckDB** is the best fit: a single `.duckdb` file, native list-column support (`VARCHAR[]`), SQL over the cache if the user ever wants it, `DBI` interoperability, small footprint. Round-trip of the full 28-column schema — including `images` (list of character) and `available_from` (`Date`) — is verified.

**Why cache at `immor_fetch()`, not per-portal:**

- The user's mental model is "one call, one result" — caching the umbrella result matches that.
- Portal methods remain untouched; no `cache` argument leaks below `immor_fetch()`.
- Per-portal caching is a future refinement (see Open Questions) if partial-refresh becomes valuable.

**Alternatives considered:**

- **Bespoke per-URL disk cache inside `immor_request()`.** Would restore the per-URL granularity from the original design. Rejected because it duplicates infrastructure DuckDB gives us for free (schema, transactions, keyed lookup) and forces all portals through a wrapper layer they don't need today.
- **`memoise::memoise(immor_fetch)` with a filesystem backend.** Rejected because memoise's on-disk cache serializes entire R objects opaquely (no schema, no queryability, no easy purge by key).

### Decision 2: `tools::R_user_dir("immor", "cache")` as the storage root

**What:** the DuckDB file lives at `R_user_dir("immor", "cache")/immor.duckdb`.

**Why:**

- R Core convention; users familiar with R packages know where to look and where to delete.
- OS conventions correctly separate cache (evictable) from data (durable) from config (portable).
- `tools::R_user_dir()` is base R since R 4.0; no dependency. Imported via `@importFrom` in [`/R/immor-package.R`](/R/immor-package.R) so call sites do not repeat the `tools::` prefix.

**Alternatives considered:**

- **`tempdir()`**: evaporates on session exit, defeats the cross-session use case.
- **A per-project `.immor-cache/`**: surprising, pollutes projects, useless in ad-hoc scripts.

### Decision 3: `cache` is opt-in at the umbrella, opt-out is easy

**Layered defaults:**

| Layer | Default | Override |
|---|---|---|
| `immor_fetch()` | `cache = TRUE, max_age = 3600` | user passes `cache = FALSE`, or a different `max_age` |
| `IMMOR_NO_CACHE` env var | unset | set to `"1"` / `"true"` / `"yes"` |

**Precedence (highest first):**

1. `IMMOR_NO_CACHE` env var — if truthy, `cache` is forced to `FALSE` regardless of arguments. Emits `cli::cli_inform()` once per session so users understand why cache flags appear ineffective.
2. Explicit `cache` argument — user's choice wins over the default.
3. Default `TRUE`.

**Why default `TRUE`?** The primary caller is a human at an R console re-running the fetch; polite-by-default is the right stance for that user. CI and package tests set the env var, so they get correct behaviour without knowing the argument exists.

### Decision 4: TTL is a caller concern, expressed as `max_age`

`immor_fetch(max_age = 3600)` says "any cache entry younger than 1 hour is fresh". `max_age = Inf` accepts any entry. `max_age = 0` forces a re-fetch while still writing the fresh result back.

Portal-endpoint-specific TTL (the earlier "3600 s archive, 86400 s detail" design) does not apply — DuckDB caches the whole `immor_fetch()` result, not per-URL, so there is only one TTL.

### Decision 5: Cache key includes the query object

Key formula: `rlang::hash(list(sort(portals), as.integer(max_pages), unclass(query)))`.

- `sort(portals)`: order-independent — `c("flatfox", "weckaeby")` hashes the same as `c("weckaeby", "flatfox")`.
- `as.integer(max_pages)`: matches the storage type; `5L` and `5` collide correctly.
- `unclass(query)`: strips the `immor_query` S3 class so future query arguments become part of the key automatically. `immor_query()` is currently no-arg, so `unclass(query)` is `list()`.

### Decision 6: Fail open on cache errors

DuckDB can, in principle, fail (locked file from a concurrent session, permission denied, corrupt DB). Both `immor_cache_read()` and `immor_cache_write()` wrap DuckDB calls in `tryCatch()`. On any error:

- `read` returns `NULL`, so `immor_fetch()` proceeds to a live scrape.
- `write` emits a one-off `cli::cli_warn()` via `immor_cache_inform_once()` and returns.

Correctness beats speed — if the cache is broken, users still get their data.

### Decision 7: Public helpers

Export three functions:

- `immor_cache_dir()` — returns the path as a length-1 character vector; creates the directory lazily on first call.
- `immor_cache_db_path()` — returns the full DuckDB file path (`.../immor.duckdb`) inside the cache directory.
- `immor_cache_clear()` — deletes the DuckDB file (and any `.wal` write-ahead-log sidecar) and emits `cli::cli_alert_success()`.

**Why three, not two?** Users occasionally want the raw DB path (to attach with the DuckDB CLI, for instance). Exposing `immor_cache_db_path()` alongside `immor_cache_dir()` keeps that ergonomic without forcing users to concatenate.

## Risks / Trade-offs

- **DuckDB file grows unbounded.** Every unique `(portals, max_pages, query)` shape accumulates a new row batch on each cache-miss scrape; stale entries are not evicted. → Documented: users call `immor_cache_clear()` when disk pressure matters. If this ever becomes real friction, we add scoped eviction (`immor_cache_clear(older_than = "7 days")`) — see Open Questions.
- **Cache key mismatch surprises the user.** A user edits `max_pages = 5L` to `max_pages = 10L`, notices the fetch takes 2 minutes again, and wonders why the cache "broke". → Documented at `?immor_fetch`. Different shape = different key = separate cache entry.
- **DuckDB write concurrency.** Two R sessions running `immor_fetch()` at the same time can lock each other out of the DB file. → DuckDB's file lock is process-level; the tryCatch on writes downgrades to a live-only fetch with a one-off warning. Not catastrophic.
- **List-column round-trip depends on the `duckdb` R package version.** Verified against the current `duckdb` release via a smoke script. → Pinning is unnecessary today; if a regression appears we bump the DESCRIPTION `Imports` lower bound.
- **`immor_query()` is trivial today.** The cache key hashes `unclass(query)`, which currently reduces to `list()`. Future query-arg changes automatically differentiate keys, but until then the key is essentially `(portals, max_pages)`.
- **Test flakiness from residual cache state.** Every test that touches the cache uses `withr::local_envvar(R_USER_CACHE_DIR = withr::local_tempdir())`. The old test helper's global `Sys.setenv(IMMOR_NO_CACHE = "1")` was **removed** because it leaked into interactive R sessions — see Migration Plan below and the follow-up commit history on the PR branch.

## Migration Plan

immor is pre-1.0 and internal-only, so there is no external migration story. Sequence:

1. Add `duckdb` and `DBI` to `Imports` in `DESCRIPTION`.
2. Rewrite [`/R/cache.R`](/R/cache.R) with the DuckDB helpers.
3. Wire the cache lookup + write into `immor_fetch()` in [`/R/fetch-all.R`](/R/fetch-all.R).
4. Revert [`/R/http.R`](/R/http.R), [`/R/portal.R`](/R/portal.R), [`/R/portal-flatfox.R`](/R/portal-flatfox.R), and [`/R/portal-weckaeby.R`](/R/portal-weckaeby.R) to their pre-change signatures.
5. Update [`/doc/design.md`](/doc/design.md) §3 to describe the DuckDB layer.
6. Update [`/.github/CONTRIBUTING.md`](/.github/CONTRIBUTING.md) — new portals do NOT plumb `cache` through their signatures.
7. User runs `fledge::bump_version()` at release time — never edit `NEWS.md` manually.

**Rollback:** revert the PR. Leftover DuckDB files under `R_user_dir("immor", "cache")` are harmless artefacts and can be deleted manually or via `immor_cache_clear()`.

## Open Questions

- Should `immor_cache_clear()` accept `older_than` for age-scoped purging? Deferred — YAGNI until a user hits disk-pressure friction.
- Should we add per-portal cache entries so a partial refresh (only re-fetch stale portals) is possible? Deferred to a future proposal.
- Should we expose `immor_cache_summary()` — a helper that returns a small tibble of `(cache_key, cached_at, n_rows)` for the user to inspect what is in the DB? Leaning yes but scope-parked for a follow-up.
- If DuckLake stabilises and the R integration matures, is there value in migrating to it for snapshot history? Revisit in 2027.
