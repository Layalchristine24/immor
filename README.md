
<!-- README.md is generated from README.Rmd. Please edit that file -->

# immor

<!-- badges: start -->

<!-- badges: end -->

immor (“immobilier” + “R”, sounds like “immortal”) scrapes real estate
listings from Swiss property portals, normalises them into a 28-column
tibble, and provides type-safe deduplication. Designed as the data
engine behind
[blockr.immor](https://github.com/Layalchristine24/blockr.immor).

## Installation

You can install the development version of immor from
[GitHub](https://github.com/Layalchristine24/immor) with:

``` r
# install.packages("pak")
pak::pak("Layalchristine24/immor")
```

## Usage

`immor_fetch()` is the umbrella entry point. The first call scrapes both
portals; subsequent calls within `max_age` (default 3600 seconds) return
the cached tibble without touching the network.

``` r
library(immor)

# Fetch listings from all portals. `query = immor_query()` is the default
# (both portals ignore query params today — filter post-fetch with dplyr).
# First call scrapes; subsequent calls hit the DuckDB cache.
listings <- immor_fetch()
listings <- immor_fetch()   # cache hit

# Inspect the result
dplyr::glimpse(listings)              # 28-column schema with types and sample values
head(listings$title)                  # listing titles
table(listings$portal)                # count per portal: "flatfox", "weckaeby"
table(listings$transaction_type)      # "rent" vs "buy"
table(listings$transaction_type, listings$portal)

# Filter by portal or transaction type
listings |> dplyr::filter(portal == "weckaeby")
listings |> dplyr::filter(transaction_type == "rent")

# Check distinct values before filtering
dplyr::distinct(listings, portal)
dplyr::distinct(listings, transaction_type)
```

### Caching

Results are cached in an on-disk DuckDB file. Repeat calls with the same
`(portals, max_pages, query)` shape within `max_age` seconds skip the
network.

``` r
# Where the cache lives (OS-conventional path via tools::R_user_dir())
immor_cache_dir()
immor_cache_db_path()

# Force a fresh scrape while still updating the cache
listings <- immor_fetch(max_age = 0)

# Skip the cache entirely for this call — do not read, do not write
listings <- immor_fetch(cache = FALSE)

# Accept any cached entry regardless of age (never trigger a scrape
# unless the cache is empty). Useful in interactive sessions where
# yesterday's data is good enough.
listings <- immor_fetch(max_age = Inf)

# Purge the on-disk cache
immor_cache_clear()

# Global kill switch — disables caching for every immor_fetch() call
# in the current R session. The switch also fires once, informatively,
# when set: "! Cache disabled by IMMOR_NO_CACHE."
Sys.setenv(IMMOR_NO_CACHE = "1")
```

## Visual Pipeline

For an interactive, no-code data pipeline UI, see the companion package
[blockr.immor](https://github.com/Layalchristine24/blockr.immor).

## Supported Portals

| Portal       | Country     | Method                 | Status    |
|--------------|-------------|------------------------|-----------|
| flatfox.ch   | Switzerland | REST API               | Available |
| weck-aeby.ch | Switzerland | HTML scraping (CasaWP) | Available |

Most major Swiss portals (homegate, immoscout24, comparis, newhome,
properstar) use bot protection (DataDome / Cloudflare) and cannot be
scraped. See the portal-landscape section of
[`doc/design.md`](doc/design.md#portal-landscape) for the full
investigation.

## Architecture

The architectural contract lives under
[`openspec/specs/`](openspec/specs/); [`doc/design.md`](doc/design.md)
is the human-reading map into it. Start with
[`openspec/specs/multi-portal-fetch/spec.md`](openspec/specs/multi-portal-fetch/spec.md)
for the umbrella orchestration, then descend into per-portal specs
(`portal-flatfox`, `portal-weckaeby`) as needed.

## Code of Conduct

Please note that the immor project is released with a [Contributor Code
of Conduct](CODE_OF_CONDUCT.md). By contributing to this project you
agree to abide by its terms.
