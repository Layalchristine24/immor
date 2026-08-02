# portal-weckaeby Specification

## Purpose
TBD - created by archiving change seed-initial-specs. Update Purpose after archive.
## Requirements
### Requirement: Constructor

The package SHALL expose `portal_weckaeby()` as a no-argument constructor that returns an `immor_portal` object with subclass `immor_portal_weckaeby`.

#### Scenario: Constructor fields

- **WHEN** `portal_weckaeby()` is called
- **THEN** the returned object SHALL have `name = "weckaeby"`, `base_url = "https://www.weck-aeby.ch"`, `buy_path = "/acheter/"`, and `rent_path = "/louer/"`
- **AND** its `class()` SHALL be `c("immor_portal_weckaeby", "immor_portal")`

### Requirement: Two-stage archive → detail fetch

`fetch_listings.immor_portal_weckaeby(portal, query, max_pages, ...)` SHALL follow a two-stage flow: first fetch the two archive pages, then fetch each detail page.

#### Scenario: Both transaction archives are fetched

- **WHEN** the method begins
- **THEN** the method SHALL fetch both `paste0(portal$base_url, portal$buy_path)` and `paste0(portal$base_url, portal$rent_path)` in order
- **AND** each archive page's link count SHALL be reported to the user via `cli::cli_inform()` with `{.url page_url}` markup

#### Scenario: Detail pages fetched per link

- **WHEN** archive links have been extracted
- **THEN** the method SHALL fetch each detail URL individually and pass the resulting HTML to `parse_listing.immor_portal_weckaeby()` via `list(html = ..., transaction_type = ..., url = ...)`

### Requirement: Mandatory 10-second crawl delay

Every HTTP request to `weck-aeby.ch` SHALL be throttled at `delay = 10` to honour the portal's `robots.txt`.

#### Scenario: Archive fetch delay

- **WHEN** `weckaeby_fetch_links(page_url)` builds its request
- **THEN** it SHALL call `immor_request(delay = 10)` before `httr2::req_perform()`

#### Scenario: Detail fetch delay

- **WHEN** `weckaeby_fetch_detail(detail_url)` builds its request
- **THEN** it SHALL call `immor_request(delay = 10)` before `httr2::req_perform()`

### Requirement: Link deduplication by `pk`

Archive links SHALL be deduplicated by their `pk=<digits>` query parameter, and links without a `pk` SHALL be dropped.

#### Scenario: Duplicate `pk` across links

- **WHEN** multiple `href` values point at the same `pk`
- **THEN** only the first occurrence in DOM order SHALL be kept
- **AND** links with no `pk=<digits>` match SHALL be excluded from the fetch list

### Requirement: Per-listing error isolation

`fetch_listings.immor_portal_weckaeby()` SHALL emit a `cli::cli_warn()` and skip a single failing listing without aborting the whole portal fetch.

#### Scenario: One detail page 404s

- **WHEN** `weckaeby_fetch_detail(link)` or `parse_listing()` throws for a single detail URL
- **THEN** the method SHALL catch the error, emit `cli::cli_warn("Failed to parse {.url {link}}: {conditionMessage(e)}")`, drop that listing, and continue with the next link

### Requirement: Empty-result short-circuit

`fetch_listings.immor_portal_weckaeby()` SHALL return an empty [`immor_schema()`](/openspec/specs/listing-schema/spec.md) when no listings were successfully parsed.

#### Scenario: Zero rows collected

- **WHEN** `dplyr::bind_rows(all_listings)` produces a zero-row tibble
- **THEN** the method SHALL return `immor_schema()` unchanged

### Requirement: Portal-boundary validation

`fetch_listings.immor_portal_weckaeby()` SHALL close its non-empty return path by calling `validate_listings(result)`.

#### Scenario: Non-empty result

- **WHEN** at least one listing was parsed
- **THEN** the method's final statement SHALL be `validate_listings(result)`

### Requirement: CasaWP HTML parsing

`parse_listing.immor_portal_weckaeby(portal, raw_listing)` SHALL extract a single-row [`immor_schema()`](/openspec/specs/listing-schema/spec.md) row from the CasaWP-rendered HTML.

#### Scenario: Portal identification

- **WHEN** parsing a listing
- **THEN** `portal` SHALL be `"weckaeby"`
- **AND** `portal_id` SHALL be the `pk` extracted from `raw_listing$url` via `weckaeby_extract_pk()`
- **AND** `url` SHALL be `raw_listing$url`

#### Scenario: Title extraction

- **WHEN** `.title` is present in the detail HTML
- **THEN** `title` SHALL be `rvest::html_text2()` of `.title`, or `NA_character_` if the element is absent

#### Scenario: Address extraction from Google Maps link

- **WHEN** the detail HTML contains an anchor whose `href` matches `google.com/maps`
- **THEN** the anchor's text SHALL be passed to `weckaeby_parse_address()` to produce `address_street`, `address_zip`, `address_city`
- **AND** the address parser SHALL match `(.+),\s*(\d{4})\s+(.+)` to populate all three, falling back to `(\d{4})\s+(.+)` when the street is absent

#### Scenario: Price extraction

- **WHEN** the details block has a `Prix` or `Loyer` label
- **THEN** its value SHALL be passed through `weckaeby_parse_price()` which strips non-digit characters and returns `NA_real_` for "sur demande" / "auf Anfrage" / "on request" phrasings
- **AND** a parsed price of `0` SHALL be normalised to `NA_real_`

#### Scenario: Price unit derives from transaction type

- **WHEN** `raw_listing$transaction_type == "buy"`
- **THEN** `price_unit` SHALL be `"total"`

- **WHEN** `raw_listing$transaction_type == "rent"` (or missing)
- **THEN** `price_unit` SHALL be `"monthly"`

#### Scenario: Constant currency

- **WHEN** a weckaeby listing is parsed
- **THEN** `currency` SHALL be `"CHF"`

#### Scenario: Details-block field extraction

- **WHEN** the details block contains labels matching `Nombre de pi`, `Surface habitable|Wohnfl`, `construction|Baujahr`, `Balcon`, `Parking`, or `Disponibilit`
- **THEN** `rooms`, `area_m2`, `year_built`, `has_balcony`, `has_parking`, and `available_from` SHALL be populated from the corresponding value string using the type-appropriate coercion (`numeric`, `numeric`, `integer`, French/German boolean, and `%d.%m.%Y` Date respectively)
- **AND** missing labels SHALL leave the field at its schema-typed `NA` value

#### Scenario: Description assembly

- **WHEN** `div.detail .container` contains one or more non-empty `<p>` elements
- **THEN** `description` SHALL be the newline-joined `rvest::html_text2()` of those paragraphs
- **AND** SHALL be `NA_character_` when no non-empty paragraph exists

#### Scenario: Image URL extraction

- **WHEN** the HTML contains `img[src*='casagateway']` or `img[src*='flatfox.ch/thumb']` elements
- **THEN** their `src` attributes SHALL be collected into a single character vector and stored in `images` as `list(img_urls)`

#### Scenario: Fields weckaeby does not expose

- **WHEN** a weckaeby listing is parsed
- **THEN** `property_type`, `floor`, `address_canton`, `latitude`, `longitude`, `has_elevator`, `is_furnished`, and `energy_label` SHALL all be `NA` of the schema-declared type

