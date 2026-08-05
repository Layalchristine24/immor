## Why

Interactive development in RStudio / Positron re-runs `immor_fetch()` frequently. Every invocation today re-fetches all ~33 k flatfox listings and walks every weck-aeby detail page under a mandated 10 s crawl delay. That is slow for the user and impolite toward the portals. Caching successful HTTP responses on disk turns repeated calls within a reasonable window into local reads while keeping an explicit opt-out for CI, fresh-data runs, and tests.

The design must also scale to the deferred roadmap: [D1](/doc/roadmap.md) (five Swiss portals blocked today, some serving > 2 M visits/mo if ever unblocked) and [D2](/doc/roadmap.md) (~200 CasaWP-based agency sites). Both grow the *number of hosts and requests*, not the shape of `immor_request()`. Wiring the cache at the shared HTTP layer means each new portal inherits caching for free.

## What Changes

- Extend [`immor_request()`](/R/http.R) with a `cache` argument (opt-in) and a `max_age` argument (TTL in seconds) that route the request through `httr2::req_cache()` before throttle and retry decorators. Caching lives at the shared HTTP layer, so every current and future portal — including all D1 and D2 additions — inherits it uniformly.
- Add an `immor_cache_dir()` helper returning `tools::R_user_dir("immor", "cache")` (created lazily). Provide `immor_cache_clear()` for programmatic purging alongside "delete the directory" as the documented manual path.
- Honour an `IMMOR_NO_CACHE` env var: any truthy value (`"1"`, `"true"`, `"yes"`, case-insensitive) disables caching globally regardless of per-call arguments. Consistent with the `DO_NOT_TRACK` idiom already documented in [`/CLAUDE.md`](/CLAUDE.md).
- Add a `cache` argument to `immor_fetch()` (default `TRUE`) that is forwarded via `fetch_listings()` S3 dispatch. The forwarding path is portal-agnostic — `immor_fetch()` contains no per-portal branching, so adding portals under [`portal-registry`](/openspec/specs/portal-registry/spec.md) requires no changes to the umbrella entry point.
- Portal fetch methods (`portal-flatfox`, `portal-weckaeby`, and any future portal) accept an internal `cache` parameter and pass it through to every `immor_request()` call, applying per-endpoint TTL as appropriate (archive vs. detail).
- No new package dependency — `httr2::req_cache()` ships in `httr2 (>= 1.0.0)`, which is already in `Imports`.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `http-layer`: `immor_request()` gains an opt-in disk cache layered before throttle and retry, a documented cache-directory contract, and the `IMMOR_NO_CACHE` env-var kill switch.
- `multi-portal-fetch`: `immor_fetch()` gains a `cache` argument that is forwarded through `fetch_listings()` dispatch to every portal method uniformly.

## Impact

- **Code touched:** [`/R/http.R`](/R/http.R), [`/R/fetch.R`](/R/fetch.R), [`/R/portal-flatfox.R`](/R/portal-flatfox.R), [`/R/portal-weckaeby.R`](/R/portal-weckaeby.R). New file `/R/cache.R` for `immor_cache_dir()`, `immor_cache_clear()`, and the env-var check.
- **Public API:** `immor_fetch()` gains `cache = TRUE`; new exports `immor_cache_dir()` and `immor_cache_clear()`. `immor_request()` gains `cache = FALSE, max_age = Inf` — internal, but S3 dispatch reaches it.
- **Filesystem:** first use creates `tools::R_user_dir("immor", "cache")`. Documented as safe to delete at any time; `immor_cache_clear()` does the same in R.
- **User messaging:** cache hits and misses use `cli::cli_alert_info()` at verbose levels; header emission stays consistent with the rest of the package (`cli_abort` / `cli_warn` / `cli_inform`).
- **Documentation:** update [`/doc/design.md`](/doc/design.md) once landed; move the N1 entry out of [`/doc/roadmap.md`](/doc/roadmap.md) into the changelog. Add a paragraph to [`.github/CONTRIBUTING.md`](/.github/CONTRIBUTING.md) requiring new portals to opt into the cache via `immor_request()`.
- **Dependencies:** none new. Verify `DESCRIPTION` pins `httr2 (>= 1.0.0)`.
- **Tests:** new tests under [`/tests/testthat/`](/tests/testthat/) redirect the cache directory via `withr::local_envvar()` + `withr::local_tempdir()` per testthat 3 conventions. Cover: cache hit skips network, TTL expiry re-fetches, `IMMOR_NO_CACHE=1` disables, `cache = FALSE` disables per-call.
