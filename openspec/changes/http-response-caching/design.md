## Context

Every outbound HTTP call in the package flows through [`immor_request()`](/R/http.R). Today the function is nine lines: user-agent → throttle → retry. Portals never call `httr2::request()` directly (enforced by the [`http-layer`](/openspec/specs/http-layer/spec.md) contract).

Two portals ship today: `flatfox` (REST JSON, ~33 k listings, `-published` sort, no crawl delay declared) and `weckaeby` (HTML archive + detail two-stage, 10 s crawl delay). Interactive users re-run `immor_fetch()` frequently, and every re-run pays the full network cost even though listing pages are stable for minutes at a time. The problem is not correctness — it is friction and portal politeness.

The roadmap plans to grow this from two portals to potentially dozens: [D1](/doc/roadmap.md) (five large Swiss portals, if bot protection ever lifts) and [D2](/doc/roadmap.md) (~200 CasaWP-based agency sites reachable via a shared parser toolkit). Any caching design must scale with that growth without per-portal special-casing.

A prior alternative — `memoise::memoise()` wrapping `immor_fetch()` or portal methods — was considered and rejected before this proposal (see Decision 1).

## Goals / Non-Goals

**Goals:**

- Repeat `immor_fetch()` calls within a session skip the network for URLs the cache has already seen.
- The mechanism is opt-in per call (`cache = TRUE / FALSE`), globally kill-switchable (`IMMOR_NO_CACHE=1`), and honours per-request-class TTL (short for archives, long for stable detail pages).
- Adding a new portal (D1 or D2) requires zero changes to the caching mechanism itself — the portal only routes through `immor_request()` and passes its own `max_age` values.
- Test isolation: tests never write into the real `R_user_dir("immor", "cache")`.
- Fail open: any cache error (corrupt file, permission denied) MUST degrade to a live request, not to an aborted call.

**Non-Goals:**

- Distributed caching, S3 backends, or shared team caches. Single-user, single-machine only.
- LRU / size-based eviction. Users delete the directory (or call `immor_cache_clear()`) when disk pressure matters. Deferred until a real user hits a cache-size problem.
- Caching parsed R objects (tibbles). Only raw HTTP responses. See Decision 1.
- ETag / Last-Modified conditional revalidation as a *separate* code path. `httr2::req_cache()` already handles this when the portal sends the headers; we do not implement it manually.
- Caching HTTP errors (`4xx`, `5xx`). By default `httr2::req_cache()` only caches `2xx` responses; we keep that behaviour.

## Decisions

### Decision 1: `httr2::req_cache()` over `memoise::memoise()`

**What:** wire caching at the HTTP layer (inside `immor_request()`), not at the R-function layer.

**Why:**

- **Granularity matches the pain.** The bottleneck is network I/O per request, not per portal or per `immor_fetch()` call. `req_cache()` keys on request URL, so weck-aeby's 20 detail pages cache independently — a single new listing invalidates one entry, not the whole crawl. `memoise` would cache at the wrapped-function level, forcing an all-or-nothing bulk hit or miss.
- **HTTP semantics come free.** `req_cache()` honours `Cache-Control`, `ETag`, `Last-Modified`, and issues conditional revalidation (`304 Not Modified`). A `304` costs one round-trip against a portal's rate limit but no listing re-parse and no bandwidth. `memoise` is a plain key→value store; it cannot revalidate.
- **Scales to N portals without per-portal code.** Every portal already routes through `immor_request()`, so a change there reaches D1 and D2 uniformly. `memoise` would require wrapping `fetch_listings.immor_portal_<name>()` per method or adding a wrapper in `immor_fetch()` — either creates a branching site that grows with the portal count.
- **Payload size matches the medium.** Cached HTTP bodies are small text (JSON / HTML); on-disk storage via `req_cache()` is fine. `memoise::cache_filesystem()` would serialize entire parsed tibbles, ballooning as portals expand into thousands of listings.

**Alternatives considered:**

- **`memoise::memoise(immor_fetch, cache = cache_filesystem(...))` with a `timeout()` wrapper.** Rejected: coarser granularity, no HTTP semantics, adds a dependency, and the D1/D2 scaling argument above.
- **Manual `hash(url) → filepath` cache written inside `immor_request()`.** Rejected: reimplements `httr2::req_cache()` badly. `httr2` maintainers will fix bugs we would otherwise inherit.
- **In-memory only cache (single-session).** Rejected: users open new R sessions between iterations; the pain is *cross-session* re-fetching too.

### Decision 2: `tools::R_user_dir("immor", "cache")` as the default cache root

**What:** the default cache directory follows the R user-dir convention:

- macOS: `~/Library/Caches/org.R-project.R/R/immor/`
- Linux (XDG): `$XDG_CACHE_HOME/R/immor/` or `~/.cache/R/immor/`
- Windows: `%LOCALAPPDATA%/R/cache/R/immor/`

**Why:**

- The R Core convention. Users familiar with R packages know where to look and where to delete.
- Not gitignored surprises — the directory lives outside project trees.
- OS conventions correctly separate cache (evictable) from data (durable) from config (portable).
- `tools::R_user_dir()` is base R since R 4.0; no dependency.

**Alternatives considered:**

- **`tempdir()`**: rejected — evaporates on session exit, defeats the cross-session use case.
- **A per-project `.immor-cache/` in `getwd()`**: rejected — surprising, pollutes projects, and useless when users call `immor_fetch()` from ad-hoc scripts.

### Decision 3: `cache` is opt-in at every layer, opt-out is easy

**Layered defaults:**

| Layer | Default | Override |
|---|---|---|
| `immor_request()` | `cache = FALSE` | callers pass `cache = TRUE` |
| Portal `fetch_listings.*` methods | pass through their own `cache` argument | — |
| `immor_fetch()` | `cache = TRUE` | user passes `cache = FALSE` |
| `IMMOR_NO_CACHE` env var | unset | set to `"1"` / `"true"` / `"yes"` |

**Precedence (highest first):**

1. `IMMOR_NO_CACHE` env var — if truthy, `cache` is forced to `FALSE` regardless of arguments. Emits `cli::cli_inform()` once per session so users understand why cache flags appear ineffective.
2. Explicit `cache` argument to `immor_fetch()` — user's choice wins over the default.
3. `immor_fetch()` default (`TRUE`).

**Why default `TRUE` at the umbrella level?** The primary caller is a human at an R console re-running the fetch; polite-by-default is the right stance for that user. CI and package tests set the env var, so they get correct behaviour without knowing the argument exists.

### Decision 4: TTL per request class, not per portal

**What:** `immor_request()` takes `max_age` in seconds; portal code passes different values for different endpoint classes.

**Recommended defaults** (portal implementations pick these, not `immor_request()`):

| Endpoint class | `max_age` | Reasoning |
|---|---|---|
| Archive / listing pages (index pages) | 3600 (1 h) | New listings appear; users notice within an hour. |
| Detail pages (single listing) | 86400 (24 h) | Once published, listing detail rarely changes. |

**Why this location?** TTL is a portal-endpoint concern, not a caller concern. `immor_fetch()` cannot know whether a URL is an archive or a detail — the portal knows. Passing `max_age` from portal helpers into `immor_request()` puts the knowledge in the right layer.

**Non-Decision:** we do NOT introduce a registry of portal-configured TTL. Each portal method decides at call-site. This keeps the [`portal-registry`](/openspec/specs/portal-registry/spec.md) contract narrow and avoids proliferating configuration surface.

### Decision 5: Fail open on cache errors

`httr2::req_cache()` can, in principle, fail (permission denied, disk full, corrupt cache file). The wrapper inside `immor_request()` MUST catch these and fall through to a live request rather than aborting. Emit `cli::cli_warn()` once per session per failure mode. Correctness beats speed — if the cache is broken, users still get their data.

### Decision 6: Argument placement in `immor_request()`

New signature: `immor_request(req, delay = 2, cache = FALSE, max_age = Inf)`.

- `delay` stays where it is.
- `cache` and `max_age` are keyword-only in spirit — callers pass them by name.
- `max_age = Inf` means "cache never expires from TTL alone" (`httr2::req_cache()` accepts this; entries are still evictable manually).
- When `cache = FALSE`, `max_age` is ignored (documented).

### Decision 7: Public helpers

Export `immor_cache_dir()` and `immor_cache_clear()`:

- `immor_cache_dir()` returns the path as a length-1 character vector; creates the directory lazily on first call.
- `immor_cache_clear()` deletes the directory contents and emits `cli::cli_alert_success()`.

**Why export?** Users need a way to inspect and purge the cache without knowing internal paths. `blockr.immor` may add a button that calls `immor_cache_clear()`.

## Risks / Trade-offs

- **Cache directory grows unbounded.** → Documented: users delete the directory or call `immor_cache_clear()`. If D1 unlocks and immoscout24's ~2 M-visits/mo scale materialises, we add size-based eviction as a follow-up (`immor_cache_clear(older_than = "7 days")`).
- **TTL mismatch surprises the user.** A user editing a listing, refreshing, and not seeing changes because of a 24 h detail cache. → Documented at the `?immor_fetch` help page; `cache = FALSE` is a one-token override; env var kills globally.
- **`httr2::req_cache()` behaviour change across `httr2` minor versions.** → Pin `httr2 (>= 1.0.0)` and cover behaviour in tests. `httr2` follows semver.
- **Test flakiness from residual cache state.** → Every test uses `withr::local_envvar(IMMOR_NO_CACHE = "1")` unless it explicitly tests cache behaviour, in which case it also uses `withr::local_tempdir()` and re-points the cache directory. Self-sufficient tests per testthat 3.
- **Interaction with rate-limit throttle.** `req_cache()` sits before `req_throttle()` in the decorator chain. A cache hit correctly skips both throttle and network. Verify explicitly in tests — a false positive here (throttle applied to a cache hit) would waste the entire point.
- **Env var typo goes unnoticed.** `IMMOR_NO_CACHE=yes` works, `IMMOR_NOCACHE=1` does not. → Document the exact name; consider a startup message if a similar-looking var is set. Deferred to feedback.
- **Cache directory path leaked in errors.** Not sensitive — it is deterministic per-OS and per-user. Fine.

## Migration Plan

immor is pre-1.0 and internal-only, so there is no external migration story. Sequence:

1. Introduce the new arguments as additive (defaults preserve current behaviour where `cache = FALSE`).
2. Set `immor_fetch(cache = TRUE)` as the default in the same PR — this is the intended user-facing change.
3. Bump version to `0.0.0.9005` in `DESCRIPTION` per the fledge pattern.
4. Add a `NEWS.md` bullet describing the cache and the `IMMOR_NO_CACHE` env var.
5. Update `doc/design.md` to describe the cache layer and remove the `N1` entry from `doc/roadmap.md`.

**Rollback:** revert the PR. No on-disk migration required; leftover cache files under `R_user_dir("immor", "cache")` are harmless leftovers and can be deleted manually.

## Open Questions

- Should `immor_cache_clear()` accept `older_than` for age-scoped purging? Deferred — YAGNI until asked.
- Should we emit a one-time `cli::cli_inform()` on first cache hit per session, so users know the cache is engaged? Leaning **no** to avoid chattiness; verbose CLI is a separate concern.
- For the D2 CasaWP toolkit refactor, do we want a shared `casawp_max_age_archive` / `casawp_max_age_detail` constant, or keep TTL choices per-portal? Deferred to the D2 change proposal.
