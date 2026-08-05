## 1. Cache helpers (new file `R/cache.R`)

- [x] 1.1 Add `R/cache.R` with `immor_cache_dir()` — returns `tools::R_user_dir("immor", "cache")`, creates directory lazily on first call, roxygenised with `@return`, `@examples`, `@export`.
- [x] 1.2 Add `immor_cache_clear()` in the same file — deletes contents (not the directory itself), emits `cli::cli_alert_success()` on success, `cli::cli_alert_info()` on already-empty, returns the path invisibly. Include `@return`, `@examples`, `@export`.
- [x] 1.3 Add internal `immor_cache_disabled()` helper — reads `Sys.getenv("IMMOR_NO_CACHE")`, returns `TRUE` for `"1" / "true" / "yes"` (case-insensitive), `FALSE` otherwise. Used by `immor_request()`.
- [x] 1.4 Add internal `immor_cache_inform_once()` helper backed by a package-local environment flag so the kill-switch notice fires exactly once per session per fallback mode.
- [x] 1.5 Run `devtools::document()` to regenerate `NAMESPACE` and `man/*.Rd` for the two new exports.

## 2. `immor_request()` extension (`R/http.R`)

- [x] 2.1 Extend `immor_request()` signature to `immor_request(req, delay = 2, cache = FALSE, max_age = Inf)`; update roxygen (`@param cache`, `@param max_age`) and re-document.
- [x] 2.2 In the body, if `isTRUE(cache) && !immor_cache_disabled()`, prepend `httr2::req_cache(path = immor_cache_dir(), max_age = max_age)` to the pipeline **before** `req_throttle()` / `req_retry()`, so cache hits skip throttle and network.
- [x] 2.3 If `isTRUE(cache) && immor_cache_disabled()`, call `immor_cache_inform_once()` and skip the cache decorator (fall through to the uncached pipeline).
- [x] 2.4 Wrap the request-cache decorator application in a `tryCatch()` so a filesystem error (e.g. permission denied on cache dir) emits `cli::cli_warn()` once per session and returns the uncached decorated request — fail open per Decision 5.

## 3. Portal fetch method updates

- [x] 3.1 `R/portal-flatfox.R`: add `cache = TRUE` to `fetch_listings.immor_portal_flatfox()`'s signature; pass `cache = cache, max_age = 3600` (archive TTL) to every `immor_request()` call.
- [x] 3.2 `R/portal-weckaeby.R`: add `cache = TRUE` to `fetch_listings.immor_portal_weckaeby()`'s signature; pass `cache = cache, max_age = 3600` (archive) for the index request and `cache = cache, max_age = 86400` (detail) for each detail-page request.
- [x] 3.3 Update any helper (`weckaeby_fetch_detail()`, flatfox pagination helpers) to accept and forward `cache` / `max_age` — no direct `httr2` calls without going through `immor_request()`.

## 4. `immor_fetch()` (`R/fetch.R`)

- [x] 4.1 Extend `immor_fetch()` signature to `immor_fetch(query, portals = NULL, deduplicate = TRUE, max_pages = 5L, cache = TRUE)`; update roxygen with `@param cache` documenting the interaction with `IMMOR_NO_CACHE`.
- [x] 4.2 In the dispatch loop, forward `cache = cache` to each `fetch_listings()` call. No per-portal branching.
- [x] 4.3 Confirm the existing `tryCatch()` per-portal isolation still catches any cache-related error surfaced from portal methods and emits a `cli::cli_warn()` per the modified spec.

## 5. Tests (`tests/testthat/`)

- [x] 5.1 `test-cache.R`: `immor_cache_dir()` returns a length-1 character vector and creates the directory on first call. Use `withr::local_envvar(R_USER_CACHE_DIR = tempdir())` to isolate.
- [x] 5.2 `test-cache.R`: `immor_cache_clear()` deletes contents but preserves the directory; no-ops cleanly when directory is empty or missing. Snapshot the `cli::cli_alert_*` output.
- [x] 5.3 `test-cache.R`: `immor_cache_disabled()` truth table — `"1"`, `"true"`, `"TRUE"`, `"yes"`, `"YES"` are truthy; `""`, `"0"`, `"false"`, `"no"`, unset are falsy.
- [x] 5.4 `test-http.R`: `immor_request(req, cache = FALSE)` returns a request with no cache decorator (verify via `req$policies` inspection); `cache = TRUE` adds the decorator; `IMMOR_NO_CACHE=1` overrides `cache = TRUE`. Use `withr::local_envvar()` for isolation.
- [x] 5.5 `test-http.R`: with `httptest2` (or `httr2::with_mock_dir()`), verify a second request to the same URL within `max_age` skips the network — mocked backend records one request across two calls.
- [x] 5.6 `test-http.R`: `max_age = 0` re-fetches on every call (TTL bypass path).
- [x] 5.7 `test-http.R`: fail-open — inject a cache directory the process cannot write to; the request still succeeds (uncached), and exactly one `cli::cli_warn()` fires.
- [x] 5.8 `test-fetch.R`: `immor_fetch(query, cache = FALSE)` propagates `cache = FALSE` to every dispatched `fetch_listings()` call (mock the S3 methods and record args).
- [x] 5.9 Ensure every existing test that hits `immor_fetch()` runs under `withr::local_envvar(IMMOR_NO_CACHE = "1")` unless the test explicitly targets cache behaviour — avoid cross-test cache pollution.

## 6. Documentation

- [x] 6.1 Update roxygen on `immor_fetch()`, `immor_request()`, `immor_cache_dir()`, `immor_cache_clear()` — full `@param` / `@return` / `@examples`, `@family` grouping if applicable.
- [x] 6.2 Add a section "HTTP response caching" to `doc/design.md` describing the cache layer, the env var, and portal TTL conventions.
- [x] 6.3 Remove the `### N1. HTTP response caching` block from `doc/roadmap.md` (item has shipped).
- [x] 6.4 Add a bullet to `.github/CONTRIBUTING.md` requiring new portals to forward `cache` / `max_age` through `immor_request()`.
- [x] 6.5 Add a `NEWS.md` bullet describing the cache and the `IMMOR_NO_CACHE` env var. Fledge will version it at release.

## 7. Verification

- [x] 7.1 `air format .` (per `.github/CONTRIBUTING.md` style rules).
- [x] 7.2 `devtools::document()` + verify no unstaged changes to `man/` or `NAMESPACE`.
- [x] 7.3 `devtools::test()` — full suite green.
- [x] 7.4 `devtools::check()` — 0 errors, 0 warnings; accept only the pre-existing `.claude` NOTE documented in `doc/roadmap.md`.
- [ ] 7.5 Manual smoke: two consecutive `immor_fetch()` calls in a fresh R session — second call is visibly faster, and `immor_cache_dir()` contents grow after the first call.
- [ ] 7.6 Manual smoke: set `IMMOR_NO_CACHE=1`, re-run — kill-switch inform fires once, second call takes the full network time again.

## 8. Ship

- [ ] 8.1 Bump `DESCRIPTION` Version to `0.0.0.9005` and update `NEWS.md` per fledge.
- [ ] 8.2 Commit with `feat(http): add opt-in httr2::req_cache() to immor_request()` (per global commit conventions).
- [ ] 8.3 Open PR from `f-http-response-caching` → `main`.
- [ ] 8.4 On merge: run `/opsx:archive http-response-caching` to move the change to `openspec/changes/archive/` and apply deltas to `openspec/specs/`.
