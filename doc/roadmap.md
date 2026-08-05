# immor — roadmap

Forward-looking list of what's planned, deferred, or explicitly rejected. Living document; entries move down (from "next" toward "deferred") as priorities shift, or up (from "deferred" toward "next") as blockers clear.

If you want to know what already works, read [design.md](design.md). For vocabulary, [glossary.md](glossary.md).

**Legend:**
- 🚧 **Next** — actively planned or in-flight.
- 🟢 **Deferred** — deliberately postponed; blockers or lower priority.
- ❌ **Rejected** — decided against, with rationale.

Every entry lists (a) what, (b) why, (c) what would unblock it or what it depends on.

---

## Package status snapshot (2026-08)

- Version: `0.0.0.9003` (development).
- Portals working: `flatfox.ch`, `weck-aeby.ch`.
- Tests passing: 60+ (see [`/tests/testthat/`](/tests/testthat/)).
- R CMD check: 0 errors, 0 warnings, 0 notes.
- CRAN: **not planned** — internal / GitHub-only release model.
- Companion: [`blockr.immor`](https://github.com/Layalchristine24/blockr.immor) v0.0.0.9000.

---

## 🚧 Next

Items that are the most likely next unit of work. Order is rough priority, not strict sequence.

### N1. Fuzzy deduplication

**What:** extend [`immor_deduplicate()`](/R/deduplicate.R) with `method = "fuzzy"` — currently only `"exact"` is supported.

**Why:** the same apartment appears on flatfox and weck-aeby with tiny differences: `"Bahnhofstrasse 12"` vs. `"Bahnhofstr. 12"`, price `2400` vs. `2500` because one includes CHF 100 for utilities. Exact-match today misses these; fuzzy would catch them.

**Design sketch:**
- Address normalisation: strip abbreviations (`str.` → `strasse`), lowercase, collapse whitespace.
- Price tolerance: `abs(a - b) / max(a, b) < 0.1` (default 10 % threshold), configurable.
- Latitude/longitude proximity when both portals provide them (Haversine distance < 50 m).
- Rooms exact.
- Confidence score returned in a new column so callers can filter by strictness.

**Unblocks / touched capabilities:** [`deduplication`](/openspec/specs/deduplication/spec.md) gains a fuzzy branch. The `method` `arg_match` set expands to `c("exact", "fuzzy")`.

**Dependencies:** possibly `stringdist` (fuzzy string comparison). Add to Imports.

---

### N2. `blockr.immor` blocks polish

**What:** improve the three blockr blocks in [`blockr.immor`](https://github.com/Layalchristine24/blockr.immor) — source, dedup, map — based on real-user friction.

**Why:** the interactive UI is the primary consumer of immor. Cleaner UX validates the split of concerns (immor = data engine, blockr.immor = UI).

**Not owned by this repo** — tracked here for cross-reference. Concrete items: filter block, summary-stats block, price-histogram block.

---

## 🟢 Deferred

Items we want but that are not the next unit of work. Reason for deferral is listed.

### D1. Additional Swiss portals (if blocks lift)

**What:** portal scrapers for the currently-blocked Swiss portals.

**Why not now:** every major Swiss portal above weck-aeby's size has adopted DataDome or Cloudflare. See [design.md § Portal landscape](design.md#portal-landscape).

**Deferred queue (if the block ever lifts, or if a legitimate API becomes available):**

| Portal | Ownership | Est. listings | Blocker |
|---|---|---|---|
| homegate.ch | Swiss Marketplace Group | ~2 M visits/mo | DataDome; SMG owns immoscout24 too, so a single SMG partnership would unlock both. |
| immoscout24.ch | Swiss Marketplace Group | ~2.6 M visits/mo (market leader) | DataDome + Cloudflare. |
| comparis.ch | Comparis Group | ~1.5 M visits/mo | DataDome. Meta-aggregator, so overlap risk with other sources. |
| newhome.ch | Newhome AG | (unknown) | Cloudflare challenge. |
| properstar.ch | Properstar SA | (unknown) | Azure Front Door. |

**Unblocking scenarios:**
- Official API access via partner agreement (probably requires a business relationship with SMG).
- Portal drops bot protection (unlikely for market leaders).
- immor gains a browser-automation backend (see D5) — but that changes the security posture and adds heavy dependencies.

**What we would need to build:** a new `portal-<name>` capability spec + `R/portal-<name>.R` + tests. See [design.md § Adding a new portal](design.md#adding-a-new-portal).

---

### D2. Additional CasaWP-based agency sites

**What:** portals for the ~200+ Swiss agencies using [Casasoft AG's CasaWP WordPress plugin](https://casasoft.ch).

**Why not now:** each individual CasaWP site has a small listing count (~10–30). Volume-per-effort ratio is unfavourable versus a single big portal. Also each site can override the CasaWP defaults, so per-site testing is still needed.

**Path to unblock:** if we generalise the weck-aeby parser into a re-usable `casawp_*` toolkit ([`/R/portal-weckaeby.R`](/R/portal-weckaeby.R) already has parser helpers that could be extracted), adding a new CasaWP site becomes ~1 day of work. Worth doing once we have 3+ CasaWP sites planned.

**Design sketch:** factor `weckaeby_parse_price()`, `weckaeby_parse_address()`, `weckaeby_parse_details_block()` into a shared `casawp_*` helper file. New CasaWP portals then subclass and override only what's site-specific.

---

### D3. International expansion

**What:** portals in AT / DE / FR / IT / NL / UK.

**Why not now:** every non-Swiss portal we investigated is either blocked (DataDome / Cloudflare / Azure Front Door / bespoke), has no public API, or explicitly forbids scraping in `robots.txt`. See [design.md § International portals investigated](design.md#international-portals-investigated).

**Only unblocker in sight:** willhaben.at *is* accessible but `robots.txt` explicitly forbids automation. If willhaben published an official API or changed its `robots.txt`, it would be the easiest add.

**Design implication if added:** the schema would need `currency` per row (already there) and possibly `address_country`. `address_country` would need the two-portal rule check — one international portal is not enough.

---

### D4. Geocoding backfill

**What:** fill `latitude`, `longitude`, `address_canton` when the portal doesn't provide them.

**Why not now:** geocoding requires an external API (Nominatim / Google / MapTiler). Introduces a network dependency outside the portal set, plus rate limits and possibly billing. `blockr.immor`'s map block only needs lat/long for flatfox listings (which already provide them) — weck-aeby is geographically concentrated (Freiburg/Bulle canton area) so the missing coordinates hurt less than they would elsewhere.

**Path to unblock:** if a user reports the missing weck-aeby coordinates as a blocker for their use case, we add an optional geocoding step behind a flag: `immor_geocode(listings, service = "nominatim")`.

**Design implication:** would add a new capability `geocoding` and a new dependency. Schema unchanged (all three columns already exist and accept `NA`).

---

### D5. Browser-automation backend

**What:** a portal implementation that drives a headless browser (Playwright / Selenium / puppeteer via `chromote`) to defeat DataDome / Cloudflare.

**Why not now:** enormous scope expansion. Adds a heavy dependency (Chrome), changes the deployment story (needs a display or headless container), and — critically — puts immor into a **grey-zone posture**: portals block bots deliberately, and simulating a real browser to circumvent that block is not clearly consistent with the "respect robots.txt and ToS" principle. See [design.md § Non-goals](design.md#non-goals).

**Would reconsider if:** the "big" Swiss portals published official APIs and we needed just a browser fallback for a handful of edge cases where the API misses data. Unlikely.

---

### D6. Property-type inference for weck-aeby

**What:** populate `property_type` for weck-aeby listings (currently always `NA_character_`).

**Why not now:** CasaWP's `Cat.gorie` / `Type` labels don't map cleanly to the schema's enum. Would need a bilingual (French / German) label-to-enum lookup table, plus manual inspection of ~15 rent + ~4 buy listings to build the initial table.

**Path to unblock:** small; probably an afternoon. Do it when someone actually wants to filter by property type across portals in `blockr.immor`.

---

### D7. Description-content extraction for flatfox

**What:** currently `description` for flatfox is `raw_listing$description %||% NA_character_`, but the flatfox API's `description` field is often terse or missing while the rendered HTML has richer content.

**Why not now:** would require a second HTTP call per listing to fetch the HTML, tripling flatfox's fetch time. Not worth it unless downstream consumers actively use `description`.

---

### D8. Test coverage expansion

**What:** hit the deduplication edge cases (numeric vs character coercion, `NA` handling in composite keys) and the `ensure_type()` failure paths.

**Why not now:** current coverage is decent (60+ tests) and the code is stable. Would prioritise if we made structural changes to [`deduplication`](/openspec/specs/deduplication/spec.md) or [`type-enforcement`](/openspec/specs/type-enforcement/spec.md) — which N1 (fuzzy dedup) will trigger anyway.

---

### D9. `blockr.immor` cross-portal comparison block

**What:** a blockr block that pairs listings by fuzzy-dedup key and shows side-by-side price / rooms differences across portals.

**Why not now:** N1 (fuzzy dedup) must land first. Once fuzzy dedup ships with a `dedup_confidence` column, this block becomes a straightforward render.

---

### D10. Stale-while-revalidate helpers for `blockr.immor`

**What:** two small helpers on top of [`listings-cache`](/openspec/specs/listings-cache/spec.md) so `blockr.immor` can implement a "keep yesterday's data visible, refresh in the background on button click, never show a blank dashboard" UX.

- `immor_cache_read_only(portals, max_pages, query)` — returns the cached tibble or `NULL`; never scrapes. Lets a Shiny app initialise its `reactiveVal(listings)` without ever blocking, and decide "show empty state" vs "trigger a background scrape" for a cold-start machine.
- `immor_cache_info()` — returns a `tibble(cache_key, cached_at, n_rows)`. Lets the dashboard render "Updated 2 hours ago" without externally tracking timestamps, and survives R session restarts.

**Why not now:** the priority is **making the current immor package robust** — get [`http-response-caching`](/openspec/changes/http-response-caching/) PR merged, tighten tests around the DuckDB layer, harden error paths, stabilise the eight capability specs — *before* growing new API surface for downstream consumers. `blockr.immor` can implement stale-while-revalidate today with `immor_fetch(max_age = Inf)` at load + `promises::future_promise(immor_fetch(max_age = 0))` at button click; the helpers above are polish, not blockers.

**Design sketch:**
- Both helpers live in [`/R/cache.R`](/R/cache.R) alongside `immor_cache_dir()` / `immor_cache_db_path()` / `immor_cache_clear()`.
- `immor_cache_read_only()` is a thin wrapper around the internal `immor_cache_read(key, max_age = Inf)` that already exists — the trick is exposing it as public API with a stable signature.
- `immor_cache_info()` is a `SELECT cache_key, MAX(cached_at) AS cached_at, COUNT(*) AS n_rows FROM immor_listings GROUP BY cache_key` on the DuckDB store.
- Neither helper triggers a scrape; both are safe to call from anywhere in a Shiny reactive graph.

**Unblocks / touched capabilities:** modifies [`listings-cache`](/openspec/specs/listings-cache/spec.md) with two ADDED requirements.

**Dependencies:** none — only requires the DuckDB cache landed in `http-response-caching`.

**Not addressing here** (also deferred until robustness work lands): `immor_fetch_async()` returning a `promises::promise` — nice one-liner in blockr but couples immor to async infra. Blockr can wrap `immor_fetch()` in `promises::future_promise()` itself.

---

## ❌ Explicitly rejected

Items we've decided against, so future proposals don't rediscover the same reasoning.

### R1. Filtering at the API layer / rich `immor_query()`

**What was rejected:** an `immor_query()` with `transaction_type`, `location`, `rooms`, `price`, `property_type`, `bbox` arguments passed to the portal APIs.

**Why:** flatfox's public API **ignores every filter parameter**. Adding query args would give false comfort — the returned tibble would be exactly the same regardless of the arguments. Better to make the constructor take nothing and filter honestly with `dplyr::filter()` post-fetch. Historical archive: this was implemented in v0.0.0.9001 and removed in v0.0.0.9002.

**Would reconsider if:** flatfox introduces a filtering API that actually filters, or if a new portal's wire protocol supports filtering that pre-fetch pushdown would materially help (e.g. bandwidth-limited endpoint).

---

### R2. Shiny app inside immor

**What was rejected:** shipping `run_app()` and an interactive UI as part of the immor package.

**Why:** conflates concerns. immor is the data engine; the UI lives in the companion package [`blockr.immor`](https://github.com/Layalchristine24/blockr.immor). Keeping them split means immor can be depended on by non-Shiny consumers (batch scripts, notebooks, other packages) without pulling `shiny` / `bslib` / `leaflet` / `DT` into their dependency tree. Historical: `run_app()`, `R/app.R`, and `inst/app/app.R` were removed in v0.0.0.9002.

**Would reconsider if:** never, structurally.

---

### R3. Rebrand / user-agent masquerading

**What was rejected:** setting `User-Agent` to a real-browser string to slip past bot-detection.

**Why:** immor's posture is "scrape only where allowed". Masquerading defeats the portal's opt-out mechanism — if a portal blocks bots, it means they don't consent to being scraped. Sending a false UA is dishonest and legally shakier than the current stance.

**Would reconsider if:** never. If we need browser fingerprints, D5 (browser automation) is the honest path.

---

### R4. Bundling scraped data in the package

**What was rejected:** committing `.rda` snapshots of listings into `data/` for offline use.

**Why:** listing data is third-party content that belongs to the source portals — bundling it in a public GitHub package would raise licensing / privacy questions. Also stale within minutes. Users who want offline can pickle their own `immor_fetch()` results.

---

### R5. Homegate scraper preservation

**What was rejected:** keeping `R/portal-homegate.R` as dead-but-parked code for the day DataDome lifts.

**Why:** dead code rots. The old homegate scraper was based on parsing `__NEXT_DATA__` JSON that no longer exists (page structure changed). If DataDome ever lifts, we'd rewrite from scratch. Historical: `R/portal-homegate.R` and its tests were removed in v0.0.0.9002.

---

## Working notes

Not roadmap items; just running discussion of tensions worth capturing.

### Note A. `_pkgdown.yml` `docs/` collision

pkgdown's default output directory is `docs/`, which is gitignored. Our source-doc folder is `doc/` (singular), which is `.Rbuildignored` but tracked. This works but relies on the singular/plural distinction — a future contributor who runs `usethis::use_pkgdown()` and doesn't notice the ignore rules could publish stale HTML. Consider explicit `destination:` config in `_pkgdown.yml` if this bites.

### Note B. `NEWS.md` / fledge coupling

`NEWS.md` is maintained by [fledge](https://fledge.cynkra.com). Contributors add bullets to the top; fledge groups + versions at release time. Non-obvious to first-time contributors — the header line in `NEWS.md` says so, and [`/.github/CONTRIBUTING.md`](/.github/CONTRIBUTING.md) mentions it, but a bad edit to `NEWS.md` can confuse fledge.

### Note C. `openspec` and `docs/` are ignored by pkgdown by default

pkgdown ignores directories whose name starts with `.` and the standard R package directories. `openspec/` will show up in the pkgdown site unless we add it to `.Rbuildignore` (it already is) or explicitly hide it. Should verify next time pkgdown site is regenerated.

### Note D. Accepted `R CMD check` NOTE: hidden `.claude` directory

`devtools::check()` emits one `NOTE`:

> checking for hidden files and directories … NOTE
> Found the following hidden files and directories: `.claude`

Root cause: macOS's LaunchServices (Positron, VSCode with Claude Code) tags `.claude/` with a `com.apple.provenance` extended attribute. That xattr is re-added the instant it's cleared (as long as the IDE is running), so `xattr -cr` doesn't stick. During `R CMD build`, `.Rbuildignore` matches `^\.claude$` and R attempts `unlink(".claude", recursive = TRUE)`; contents are removed but the empty parent directory survives in the tarball. `R CMD check` then flags it as a hidden entry.

Why we accept it: immor is internal-only (no CRAN release planned — see [`/CLAUDE.md`](/CLAUDE.md) "R-package skills → cran-extrachecks"). One informational `NOTE` alongside 0 errors, 0 warnings is fine. The alternative (moving `.claude/commands/` + `.claude/skills/` to a non-hidden `_claude/` and using a symlink from `.claude/`) adds config surgery that breaks the Claude Code default discovery convention.

Reproducible workaround if a CRAN release ever becomes relevant: quit Positron / VSCode, run `xattr -cr .claude/`, then `devtools::check()` — the xattr will not be re-added by the OS while the IDE is closed and the note disappears.

---

## How to add to this roadmap

If you want to propose a new item:

1. Add a new subsection under the appropriate priority (🚧 / 🟢 / ❌).
2. Include: **What**, **Why**, **Design sketch** (optional), **Unblocks** (which capability specs would need MODIFIED requirements), **Dependencies**.
3. If it's material scope, open an [OpenSpec proposal](/CLAUDE.md#using-openspec) at the same time.

If you're removing an item because it shipped:

1. Delete the subsection.
2. Reference the archived change under [`/openspec/changes/archive/`](/openspec/changes/archive/) so the history is one click away.
