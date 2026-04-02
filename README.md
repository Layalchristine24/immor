
<!-- README.md is generated from README.Rmd. Please edit that file -->

# immor

<!-- badges: start -->

<!-- badges: end -->

immor (“immobilier” + “R”, sounds like “immortal”) scrapes real estate
listings from Swiss property portals, normalizes them into a 28-column
tibble, and provides type-safe deduplication. Designed as the data
engine behind
[blockr.immor](https://github.com/Layalchristine24/blockr.immor).

## Installation

You can install the development version of immor from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("Layalchristine24/immor")
```

## Usage

``` r
library(immor)

# Fetch listings from all portals
query <- immor_query()
listings <- immor_fetch(query)

# Inspect the result
dplyr::glimpse(listings)        # 28-column schema overview
head(listings$title)            # listing titles
table(listings$portal)          # count per portal
table(listings$transaction_type) # rent vs buy
```

Note: `print(listings)` shows a condensed tibble summary. Use
`dplyr::glimpse(listings)` or `View(listings)` in RStudio for the full
column view.

## Visual Pipeline

For an interactive, no-code data pipeline UI, see the companion package
[blockr.immor](https://github.com/Layalchristine24/blockr.immor).

## Supported Portals

| Portal       | Country     | Method                 | Status    |
|--------------|-------------|------------------------|-----------|
| flatfox.ch   | Switzerland | REST API               | Available |
| weck-aeby.ch | Switzerland | HTML scraping (CasaWP) | Available |

Most major Swiss portals (homegate, immoscout24, comparis, newhome,
properstar) use bot protection (DataDome/Cloudflare) and cannot be
scraped. See `doc/portals.md` for the full investigation.
