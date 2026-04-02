# immor Architecture

## Overview

immor is a real estate portal aggregator built as an R package. It scrapes listings from property portals, normalizes them into a unified schema, deduplicates across portals, and returns a tidy tibble. Interactive filtering and visualization is handled by the companion package blockr.immor.

Inspired by [worldclubratings.com](https://worldclubratings.com) (David Schoch, cynkra).

## Data Flow

```
immor_query()          Create query object
      |
      v
immor_fetch()          Dispatch to portal scrapers
      |
      +---> fetch_listings.immor_portal_flatfox()   (JSON API)
      +---> fetch_listings.immor_portal_weckaeby()  (HTML scraping via rvest)
      |
      v
parse_listing()        Normalize each raw listing to immor_schema()
      |
      v
validate_listings()    Type enforcement via ensure_type()
      |
      v
immor_deduplicate()    Remove cross-portal duplicates
      |
      v
tibble result          Unified listings tibble (28 columns)
```

## Inspecting Results

`immor_fetch()` returns a tibble. The default `print()` output is a condensed
tibble header — use these to explore the data:

```r
listings <- immor_fetch(immor_query())

dplyr::glimpse(listings)         # full column overview with types and sample values
head(listings$title)             # first few listing titles
table(listings$portal)           # count per portal
table(listings$transaction_type) # "rent" vs "buy"
View(listings)                   # RStudio spreadsheet view
```

Expected output shape: ~160–200 rows, 28 columns, portals `"flatfox"` and
`"weckaeby"`. A 404 warning for one weck-aeby listing is normal (listing
removed between archive fetch and detail fetch).

## Schema Design

### Common denominator approach

The schema defines 28 columns that represent the **common denominator** across all portals. This means:

- Every portal scraper must return a tibble with all 28 columns
- Columns that a portal can't fill get `NA` (e.g., flatfox has no `address_canton`, no `has_balcony`)
- `validate_listings()` uses `ensure_type()` (vctrs::vec_cast) to enforce correct column types — mismatched types error immediately ("fail fast, fail early, fail clear")
- The schema acts like a SQL UNION — all sources produce the same shape

### Adding columns

New columns should only be added if at least 2 portals provide the data. Portal-specific fields should not be added to the schema.

### Schema columns

| Column | Type | Description |
|---|---|---|
| `portal` | character | Source portal name |
| `portal_id` | character | Unique ID on source portal |
| `url` | character | Full listing URL |
| `scraped_at` | POSIXct | Scrape timestamp |
| `transaction_type` | character | "rent" or "buy" (from portal data) |
| `property_type` | character | "apartment", "house", "room", "parking", "commercial", "other" |
| `title` | character | Listing title |
| `description` | character | Full description text |
| `price` | numeric | Price (monthly rent or sale price) |
| `price_unit` | character | "monthly", "weekly", "total" |
| `currency` | character | e.g. "CHF", "EUR" |
| `rooms` | numeric | Number of rooms |
| `area_m2` | numeric | Living area in m2 |
| `floor` | integer | Floor number |
| `address_street` | character | Street address |
| `address_zip` | character | Postal code |
| `address_city` | character | City |
| `address_canton` | character | Canton/state/region code |
| `latitude` | numeric | Latitude |
| `longitude` | numeric | Longitude |
| `images` | list | List of image URLs or IDs |
| `available_from` | Date | Move-in date |
| `year_built` | integer | Year built |
| `has_balcony` | logical | Has balcony |
| `has_parking` | logical | Has parking |
| `has_elevator` | logical | Has elevator |
| `is_furnished` | logical | Furnished |
| `energy_label` | character | Energy label |

## S3 Class Hierarchy

### Portal objects

Each portal is an S3 object with classes `c("immor_portal_{name}", "immor_portal")`.

Constructor: `new_portal(name, base_url, ...)`

### Generics

- `fetch_listings(portal, query, max_pages)` — fetch and parse listings
- `parse_listing(portal, raw_listing)` — convert a single raw listing to schema

### Query objects

`immor_query()` returns an S3 object of class `immor_query`. It takes no arguments — all filtering is handled post-fetch by the blockr.immor app.

## Adding a New Portal

1. Create `R/portal-{name}.R` with:
   - `portal_{name}()` — constructor calling `new_portal()`
   - `fetch_listings.immor_portal_{name}()` — HTTP fetch + pagination
   - `parse_listing.immor_portal_{name}()` — map raw data to `immor_schema()`
2. Ensure `parse_listing()` returns columns matching `immor_schema()` types. `validate_listings()` uses `ensure_type()` to enforce type stability.
3. Register the portal in `R/portals.R` by adding it to `immor_portals()`
4. Add tests in `tests/testthat/test-portal-{name}.R` with fixture data
5. Add portal info to `doc/portals.md`

### Security considerations

Before adding a portal, verify:
- The portal uses HTTPS
- The portal's robots.txt allows automated access to the endpoints you need
- The portal doesn't explicitly forbid scraping in its terms of service
- Rate limiting is applied via `immor_request()`

## HTTP Layer

All HTTP requests go through `immor_request()` which adds:
- User-Agent header identifying the package
- Rate limiting (1 request per 2 seconds per host)
- Retry with exponential backoff (3 attempts)

## Deduplication

Cross-portal deduplication uses exact matching on `(address_zip, address_street, rooms, price)`. Fuzzy matching is planned for future versions.
