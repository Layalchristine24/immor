# immor + blockr.immor Project Plan

## 1. immor — Core Scraping Engine ✅

### 1.1 Package skeleton ✅
- ✅ DESCRIPTION, LICENSE, NAMESPACE, .Rbuildignore, air.toml
- ✅ `R/immor-package.R` — package docs, `@import rlang`
- ✅ `R/globals.R` — roxyglobals managed

### 1.2 Schema & query ✅
- ✅ `R/schema.R` — `immor_schema()` (28-column canonical tibble), `validate_listings()`
- ✅ `R/query.R` — `immor_query()` S3 constructor with validation, `print.immor_query()`

### 1.3 Portal system ✅
- ✅ `R/portal.R` — `new_portal()`, `fetch_listings()` / `parse_listing()` generics
- ✅ `R/portals.R` — `immor_portals()` registry, `immor_portal()` lookup
- ✅ `R/http.R` — `immor_request()` with rate limiting, retry, user-agent

### 1.4 Portal scrapers ✅
- ✅ `R/portal-flatfox.R` — flatfox.ch REST API scraper (`/api/v1/public-listing/`, pagination via offset/limit)
- ✅ `R/portal-homegate.R` — homegate.ch (blocked by DataDome, warns gracefully and returns empty)

### 1.5 Aggregation ✅
- ✅ `R/fetch-all.R` — `immor_fetch()` multi-portal fetcher with progress
- ✅ `R/deduplicate.R` — `immor_deduplicate()` exact matching on (zip, street, rooms, price)

### 1.6 Tests (60 passing) ✅
- ✅ `tests/testthat/test-schema.R`
- ✅ `tests/testthat/test-query.R`
- ✅ `tests/testthat/test-portal-flatfox.R`
- ✅ `tests/testthat/test-portal-homegate.R`
- ✅ `tests/testthat/test-deduplicate.R`
- ✅ `tests/testthat/helper.R` — mock constructors
- ✅ `tests/testthat/fixtures/flatfox-response.json`

### 1.7 Documentation ✅
- ✅ `doc/design.md` — architecture, data flow, schema, how to add a portal
- ✅ `doc/portals.md` — landscape of 23+ Swiss real estate portals (Tier 1/2/3)
- ✅ `doc/shiny-app.md` — Shiny app user guide (historical, app removed)
- ✅ `doc/contributing.md` — contributor guide with code style conventions
- ✅ `README.Rmd` — package description, usage, supported portals, blockr.immor reference

### 1.8 Cleanup (post-blockr decision) ✅
- ✅ Removed `R/app.R` and `inst/app/app.R` — Shiny app moved to blockr.immor
- ✅ Removed `R/cache.R` — unused code (`immor_cache()` was never wired into fetchers)
- ✅ Removed `shiny`, `bslib`, `DT`, `leaflet` from DESCRIPTION Suggests
- ✅ Renamed `flatfox_parse_date()` → `parse_date()` — shared internal, fixed cross-reference bug in `R/portal-homegate.R:130`
- ✅ Added `CLAUDE.md`, `plan.md` to `.Rbuildignore`
- ✅ R CMD check: 0 errors, 0 warnings, 0 notes

### 1.9 Fix broken scrapers ✅
- ✅ Flatfox API endpoint changed: `/api/v1/flat/` → `/api/v1/public-listing/`
- ✅ Flatfox field renames: `title` → `public_title`/`short_title`, `zip` → `zipcode`, `moving_date_from` → `moving_date`
- ✅ Flatfox images now integer IDs (no longer objects with `url`)
- ✅ Flatfox `has_balcony`/`has_parking`/`has_elevator` removed from API → set to `NA`
- ✅ Homegate blocked by DataDome bot protection → warns gracefully, returns empty
- ✅ Updated test fixtures and mocks to match new API response structure
- ✅ Fixed README.Rmd code chunk syntax (`r` → `{r, eval = FALSE}`)
- ✅ Updated portal status table in README.Rmd

### 1.10 Simplify query + skill compliance ✅
- ✅ `immor_query()` simplified to only `transaction_type` (flatfox API ignores all filters)
- ✅ Removed dead code: `flatfox_offer_type()`, `flatfox_query_params()`
- ✅ Simplified `homegate_search_url()` — removed rooms/price params
- ✅ Added `@examples` to all exported functions (per r-package-development skill)
- ✅ Used `expect_snapshot()` for warnings (per testing-r-packages skill)
- ✅ Created `NEWS.md` with user-facing change bullets (per r-package-development skill)
- ✅ Created `_pkgdown.yml` with reference index (per r-package-development skill)
- ✅ Fixed DESCRIPTION: removed Shiny mention, added `cph` role (per cran-extrachecks skill)
- ✅ Updated README.Rmd usage example
- ✅ blockr.immor source block: post-fetch filtering with dplyr instead of query params
- ✅ R CMD check: 0 errors, 0 warnings, 0 notes (57 tests passing)

### 1.11 Type enforcement with ensure_type() ✅
- ✅ Fixed `R/ensure_type.R`: `%>%` → `|>`, explicit namespaces, removed internal roxygen
- ✅ `validate_listings()` now uses `ensure_type()` with all 28 column types
- ✅ `fetch_listings.immor_portal_flatfox()` uses `validate_listings()` return value
- ✅ Added `vctrs` to DESCRIPTION Imports
- ✅ Updated `_pkgdown.yml` with `ensure_type` topic
- ✅ Updated `doc/contributing.md` with `ensure_type()` guidance
- ✅ R CMD check: 0 errors, 0 warnings, 0 notes (58 tests passing)

### 1.12 Remove transaction_type + dead code cleanup ✅
- ✅ `immor_query()` is now a no-arg constructor (flatfox API ignores all params including transaction_type)
- ✅ Removed `R/portal-homegate.R` — blocked by DataDome, dead code
- ✅ Removed `tests/testthat/test-portal-homegate.R` and homegate snapshots
- ✅ Removed `mock_homegate_listing()` from `tests/testthat/helper.R`
- ✅ Removed `rvest` and `jsonlite` from DESCRIPTION Imports (only used by homegate)
- ✅ Removed `doc/shiny-app.md` — obsolete (Shiny app was removed earlier)
- ✅ Updated `R/portals.R` — only flatfox in registry
- ✅ Updated `doc/design.md` — added schema design rationale, security considerations
- ✅ Updated `doc/portals.md` — full Swiss + international portal investigation
- ✅ Updated `doc/contributing.md` — security checks, snapshot testing, NEWS.md conventions
- ✅ Updated `README.Rmd` — simplified, flatfox only
- ✅ Updated `NEWS.md` with all changes
- ✅ blockr.immor: removed `transaction_type` from source block
- ✅ Both packages: R CMD check 0/0/0 (immor: 33 tests, blockr.immor: 10 tests)

---

## 2. blockr.immor — blockr Extension Package ✅

Location: `/Users/layalcynkra/github/layal-owner/blockr.immor/`

### 2.1 Package skeleton ✅
- ✅ DESCRIPTION (Imports: blockr.core, immor, leaflet, shiny; Remotes: BMS/blockr.core, Layalchristine24/immor)
- ✅ LICENSE (usethis::use_mit_license)
- ✅ NAMESPACE, .Rbuildignore, .gitignore, air.toml
- ✅ `R/blockr.immor-package.R` — package docs, `globalVariables(".")`, `.onLoad` registration
- ✅ `R/globals.R` — roxyglobals managed

### 2.2 Block implementations ✅
- ✅ `R/source-block.R` — `new_immor_source_block()` data block
  - Wraps `immor::immor_fetch(immor::immor_query(...))`
  - UI: transaction type, location, rooms slider, max price, portal checkboxes, search button
  - Registered as category "input"
- ✅ `R/dedup-block.R` — `new_immor_dedup_block()` transform block
  - Wraps `immor::immor_deduplicate()` via `bbquote`
  - `dat_valid` checks for required columns
  - Registered as category "transform"
- ✅ `R/map-block.R` — `new_immor_map_block()` plot block
  - Leaflet map with clustered markers
  - Custom `block_output` and `block_ui` S3 methods
  - `dat_valid` checks for latitude/longitude/title columns
  - Registered as category "plot"

### 2.3 Launcher ✅
- ✅ `R/app.R` — `run_app()` creates a board with source block and serves it

### 2.4 Tests (10 passing) ✅
- ✅ `tests/testthat/test-source-block.R` — block construction, parameterization, registration

### 2.5 Documentation ✅
- ✅ `doc/design.md` — block descriptions, pipeline examples, references
- ✅ `README.Rmd` — installation, usage, available blocks table

### 2.6 Verification ✅
- ✅ R CMD check: 0 errors, 0 warnings, 0 notes

---

## 3. Pending / Future 🚧

### 3.1 Push to GitHub 🙋‍♂️
- 🙋‍♂️ Push immor changes to `Layalchristine24/immor`
- 🙋‍♂️ Push blockr.immor to `Layalchristine24/blockr.immor`

### 3.2 weck-aeby.ch portal (CasaWP) ✅
Server-side rendered WordPress site (CasaWP plugin). No API — HTML scraping with httr2 + rvest.
robots.txt allows scraping with 10s crawl delay. ~4 buy + ~15 rent listings.
URLs: `/acheter/` (buy), `/louer/` (rent), `/objet/{slug}/?pk={id}&ret={type}` (detail).

- ✅ 3.2.1 Standalone R script prototype (`dev/weckaeby-prototype.R`)
  - Fetches both `/acheter/` and `/louer/`, deduplicates links by `pk` param
  - Parses detail pages: title (`.title`), price, address (Google Maps link), rooms, year, images, availability
  - Returns 28-column tibble, tested on live site (19 listings scraped)
- ✅ 3.2.2 Integrated into immor as `R/portal-weckaeby.R`
  - `portal_weckaeby()` constructor, registered in `immor_portals()`
  - `fetch_listings.immor_portal_weckaeby()` — two-stage: archive page → detail pages
  - `parse_listing.immor_portal_weckaeby()` — HTML → schema tibble via `raw_listing` list
  - `rvest` added to DESCRIPTION Imports
  - Internal helpers: `weckaeby_parse_price()`, `weckaeby_parse_address()`, `weckaeby_parse_details_block()`
- ✅ 3.2.3 Tests (62 passing in test-portal-weckaeby.R)
  - 4 HTML fixture files for buy, rent, no-price, zero-rent cases
  - Tests: constructor, buy parsing, rent parsing, prix sur demande, CHF 0, validate_listings, price edge cases, address parsing, pk extraction
- ✅ 3.2.4 Docs & NEWS.md updated
  - README.Rmd, NEWS.md, doc/portals.md, doc/design.md
  - R CMD check: 0/0/0 (95 tests total)

### 3.3 Additional portals 🟢
- 🟢 immoscout24.ch scraper
- 🟢 comparis.ch scraper
- 🟢 newhome.ch scraper

### 3.4 Enhancements 🟢
- 🟢 HTTP response caching (re-add `httr2::req_cache()` when needed)
- 🟢 Fuzzy deduplication method (beyond exact matching)
- 🟢 Additional blockr blocks (filter block, summary stats block)
