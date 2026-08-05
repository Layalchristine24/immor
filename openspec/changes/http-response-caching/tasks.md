## 1. Cache helpers (new file `R/cache.R`)

- [x] 1.1 Add `R/cache.R` with `immor_cache_dir()` — returns `R_user_dir("immor", "cache")` (imported via `@importFrom tools R_user_dir` in `R/immor-package.R`), creates directory lazily on first call, roxygenised with `@return`, `@examples`, `@export`.
- [x] 1.2 Add `immor_cache_db_path()` — returns `file.path(immor_cache_dir(), "immor.duckdb")` — exported, roxygenised.
- [x] 1.3 Add `immor_cache_clear()` — deletes the DuckDB file and any `.wal` sidecar; emits `cli::cli_alert_success()` on removal, `cli::cli_alert_info()` on already-empty; returns the path invisibly. Include `@return`, `@examples`, `@export`.
- [x] 1.4 Add internal `immor_cache_disabled()` — reads `Sys.getenv("IMMOR_NO_CACHE")`, truthy for `"1" / "true" / "yes"` (case-insensitive), falsy otherwise.
- [x] 1.5 Add internal `immor_cache_inform_once()` backed by a package-local environment flag so kill-switch / fs-error notices fire at most once per session per key.
- [x] 1.6 Add internal `immor_cache_key(portals, max_pages, query)` — `rlang::hash(list(sort(portals), as.integer(max_pages), unclass(query)))`.
- [x] 1.7 Add internal `immor_cache_read(key, max_age)` — opens DuckDB read-only, queries `immor_listings` for the freshest row batch matching `key`, returns `NULL` on miss / stale / any error; emits `cli::cli_alert_info()` on hit.
- [x] 1.8 Add internal `immor_cache_write(key, listings)` — opens DuckDB, appends the augmented tibble (`cache_key`, `cached_at` prefix columns) to `immor_listings`, creates the table on first write. Wraps write in `tryCatch()` for fail-open semantics.
- [x] 1.9 Run `devtools::document()` to regenerate `NAMESPACE` and `man/*.Rd` for the three new exports.

## 2. `immor_fetch()` wiring (`R/fetch-all.R`)

- [x] 2.1 Extend `immor_fetch()` signature to `immor_fetch(query, portals = NULL, deduplicate = TRUE, max_pages = 5L, cache = TRUE, max_age = 3600)`; update roxygen with `@param cache` and `@param max_age` documenting the interaction with `IMMOR_NO_CACHE`.
- [x] 2.2 Compute the cache key via `immor_cache_key()`.
- [x] 2.3 If `cache = TRUE` and the kill switch is off, call `immor_cache_read(key, max_age)` before dispatch; on a non-null hit, return immediately (no `cli_inform` about fetching).
- [x] 2.4 On cache miss, dispatch to portals as before, then call `immor_cache_write(key, result)` after deduplication.
- [x] 2.5 If `cache = TRUE` but the kill switch is on, emit `immor_cache_inform_once()` once per session and continue without cache.

## 3. Revert HTTP-layer plumbing

- [x] 3.1 Restore `immor_request(req, delay = 2)` in `R/http.R` — decorators only, no `cache`/`max_age` args.
- [x] 3.2 Restore `fetch_listings()` generic in `R/portal.R` — no `cache` parameter.
- [x] 3.3 Restore `fetch_listings.immor_portal_flatfox()` — no `cache` parameter; use `immor_request()` unchanged.
- [x] 3.4 Restore `fetch_listings.immor_portal_weckaeby()` and its `weckaeby_fetch_links()` / `weckaeby_fetch_detail()` helpers — no `cache` parameter.

## 4. Dependencies

- [x] 4.1 Add `duckdb` and `DBI` to `Imports` in `DESCRIPTION`.
- [x] 4.2 Verify `tools::R_user_dir` is still imported via `@importFrom` in `R/immor-package.R`.

## 5. Tests (`tests/testthat/`)

- [x] 5.1 `test-cache.R`: `immor_cache_dir()` returns a length-1 character vector and creates the directory on first call. Isolate with `withr::local_envvar(R_USER_CACHE_DIR = withr::local_tempdir())`.
- [x] 5.2 `test-cache.R`: `immor_cache_db_path()` points to `immor.duckdb` inside `immor_cache_dir()`.
- [x] 5.3 `test-cache.R`: `immor_cache_clear()` removes the DuckDB file and no-ops on absent file.
- [x] 5.4 `test-cache.R`: `immor_cache_disabled()` truth table for env-var values.
- [x] 5.5 `test-cache.R`: `immor_cache_inform_once()` emits once per key per session.
- [x] 5.6 `test-cache.R`: `immor_cache_key()` is order-independent for `portals` and differs on `max_pages`.
- [x] 5.7 `test-cache.R`: `immor_cache_read()` / `immor_cache_write()` round-trip a full-schema tibble including list column and Date column; stale entries return `NULL`.
- [x] 5.8 `test-http.R`: `immor_request()` sets user-agent, throttle, and retry decorators and does NOT layer `httr2::req_cache()`.
- [x] 5.9 `test-fetch.R`: `immor_fetch(cache = FALSE)` skips cache read/write, no DuckDB file appears.
- [x] 5.10 `test-fetch.R`: first call scrapes, second call within `max_age` returns cached rows without dispatching to portals (mock `fetch_listings` and verify call count).
- [x] 5.11 `test-fetch.R`: `max_age = 0` forces re-fetch on every call.
- [x] 5.12 `test-fetch.R`: `IMMOR_NO_CACHE=1` disables caching and emits the once-per-session inform.
- [x] 5.13 `test-fetch.R`: per-portal error isolation still catches errors even with caching enabled.

## 6. Documentation

- [x] 6.1 Roxygen on the three new exports (`immor_cache_dir()`, `immor_cache_db_path()`, `immor_cache_clear()`) — `@param`, `@return`, `@examples`.
- [x] 6.2 Rewrite the "HTTP policy is centralised" section of `doc/design.md` to describe the DuckDB cache layer and how it sits ABOVE `fetch_listings()` dispatch.
- [x] 6.3 Remove the `### N1. HTTP response caching` block from `doc/roadmap.md` (item has shipped).
- [x] 6.4 Revert the `.github/CONTRIBUTING.md` HTTP paragraph to the pre-cache text: new portals do NOT need to plumb `cache` through their signatures. Add a bullet about the umbrella cache under `immor_fetch()`.
- [x] 6.5 ~~Add a `NEWS.md` bullet~~ — **do NOT edit `NEWS.md` manually**; it is maintained by [fledge](https://fledge.cynkra.com) and only the user runs `fledge::bump_version()` at release time. Fledge derives the entry from commit messages, so the feat/fix/chore prefix on the commit is what matters.

## 7. Verification

- [x] 7.1 `air format .`.
- [x] 7.2 `devtools::document()` + verify no unstaged changes to `man/` or `NAMESPACE`.
- [x] 7.3 `devtools::test()` — full suite green (150+ tests).
- [ ] 7.4 `devtools::check()` — 0 errors, 0 warnings; accept only the pre-existing `.claude` NOTE documented in `doc/roadmap.md`.
- [ ] 7.5 Live smoke: two consecutive `immor_fetch()` calls in a fresh R session — first takes ~3 minutes, second returns in < 1 second with `Cache hit: N listings...` message. `immor_cache_db_path()` grows in size after the first call.
- [ ] 7.6 Live smoke: `Sys.setenv(IMMOR_NO_CACHE = "1"); immor_fetch()` — kill-switch inform fires exactly once; no cache written.

## 8. Ship

- [ ] 8.1 User runs `fledge::bump_version()` — bumps `DESCRIPTION` and appends a fledge-authored `NEWS.md` section from commit messages. **Never edit `NEWS.md` manually.**
- [ ] 8.2 Commit with `feat(cache): store immor_fetch() results in DuckDB cache` (per global commit conventions).
- [ ] 8.3 Push to `f-http-response-caching` — PR #4 already open, will update in place.
- [ ] 8.4 On merge: run `/opsx:archive http-response-caching` to move the change to `openspec/changes/archive/` and apply deltas to `openspec/specs/`. This will create the new `openspec/specs/listings-cache/` capability spec.
