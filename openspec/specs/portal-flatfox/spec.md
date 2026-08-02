# portal-flatfox Specification

## Purpose
TBD - created by archiving change seed-initial-specs. Update Purpose after archive.
## Requirements
### Requirement: Constructor

The package SHALL expose `portal_flatfox()` as a no-argument constructor that returns an `immor_portal` object with subclass `immor_portal_flatfox`.

#### Scenario: Constructor fields

- **WHEN** `portal_flatfox()` is called
- **THEN** the returned object SHALL have `name = "flatfox"`, `base_url = "https://flatfox.ch"`, and `api_url = "https://flatfox.ch/api/v1/public-listing/"`
- **AND** its `class()` SHALL be `c("immor_portal_flatfox", "immor_portal")`

### Requirement: REST-API pagination

`fetch_listings.immor_portal_flatfox(portal, query, max_pages, ...)` SHALL page through the flatfox public listing endpoint using offset/limit pagination.

#### Scenario: First page

- **WHEN** the fetch begins
- **THEN** the first request SHALL be `GET {portal$api_url}?ordering=-published&offset=0&limit=30`
- **AND** the request SHALL be built via `httr2::request()` and decorated by [`immor_request()`](/openspec/specs/http-layer/spec.md)

#### Scenario: Subsequent pages until cap

- **WHEN** the API response's `body$next` field is non-null and the current page count is below `max_pages`
- **THEN** the fetch SHALL advance `offset` by `limit` and issue the next request

#### Scenario: Termination conditions

- **WHEN** `body$next` is `NULL` OR the page count reaches `max_pages` OR `body$results` is empty
- **THEN** the fetch SHALL stop paginating and proceed to parse

### Requirement: Empty-result short-circuit

`fetch_listings.immor_portal_flatfox()` SHALL return an empty [`immor_schema()`](/openspec/specs/listing-schema/spec.md) when no listings were collected.

#### Scenario: No pages returned any listing

- **WHEN** `dplyr::bind_rows(parsed)` produces a zero-row tibble
- **THEN** the method SHALL return `immor_schema()` unchanged (no `validate_listings()` call needed)

### Requirement: Portal-boundary validation

`fetch_listings.immor_portal_flatfox()` SHALL close its non-empty return path by calling `validate_listings(result)`.

#### Scenario: Non-empty result

- **WHEN** at least one listing was parsed
- **THEN** the method's final statement SHALL be `validate_listings(result)`, so [`type-enforcement`](/openspec/specs/type-enforcement/spec.md) guarantees the returned tibble matches [`immor_schema()`](/openspec/specs/listing-schema/spec.md)

### Requirement: Listing normalisation

`parse_listing.immor_portal_flatfox(portal, raw_listing)` SHALL map one raw listing dict into a single-row tibble conforming to [`immor_schema()`](/openspec/specs/listing-schema/spec.md).

#### Scenario: Portal identification

- **WHEN** a raw listing is parsed
- **THEN** `portal` SHALL be `"flatfox"`, `portal_id` SHALL be `as.character(raw_listing$pk)`, and `url` SHALL be `paste0(portal$base_url, raw_listing$url)`

#### Scenario: Title fallback

- **WHEN** `raw_listing$public_title` is present
- **THEN** `title` SHALL be `raw_listing$public_title`

- **WHEN** `raw_listing$public_title` is missing but `raw_listing$short_title` is present
- **THEN** `title` SHALL be `raw_listing$short_title`

- **WHEN** both are missing
- **THEN** `title` SHALL be `NA_character_`

#### Scenario: Offer-type normalisation

- **WHEN** `raw_listing$offer_type == "RENT"`
- **THEN** `transaction_type` SHALL be `"rent"`

- **WHEN** `raw_listing$offer_type == "BUY"`
- **THEN** `transaction_type` SHALL be `"buy"`

- **WHEN** `raw_listing$offer_type` is missing or an unknown value
- **THEN** `transaction_type` SHALL default to `"rent"`

#### Scenario: Property-type normalisation

- **WHEN** `raw_listing$object_category` is `"APARTMENT"`, `"HOUSE"`, `"ROOM"`, `"PARKING"`, or `"COMMERCIAL"`
- **THEN** `property_type` SHALL be the corresponding lower-case string
- **AND** any other or missing category SHALL map to `"other"` (with `"APARTMENT"` as the default when the field is absent)

#### Scenario: Constant fields

- **WHEN** a flatfox listing is parsed
- **THEN** `price_unit` SHALL be `"monthly"` and `currency` SHALL be `"CHF"`
- **AND** `scraped_at` SHALL be `Sys.time()` at parse time

#### Scenario: Fields flatfox does not expose

- **WHEN** a flatfox listing is parsed
- **THEN** `address_canton`, `has_balcony`, `has_parking`, `has_elevator`, and `energy_label` SHALL all be `NA` of the schema-declared type

### Requirement: Move-in date parsing

`parse_listing.immor_portal_flatfox()` SHALL convert the raw `moving_date` string into a `Date`, tolerating missing or malformed input.

#### Scenario: Well-formed date

- **WHEN** `raw_listing$moving_date` is an ISO date string
- **THEN** `available_from` SHALL be `as.Date(raw_listing$moving_date)`

#### Scenario: Missing or malformed date

- **WHEN** `raw_listing$moving_date` is `NULL`, `NA`, or unparseable
- **THEN** `available_from` SHALL be `as.Date(NA)`

### Requirement: Image field is a list of character identifiers

`parse_listing.immor_portal_flatfox()` SHALL store `images` as a list column containing a single character vector of image identifiers.

#### Scenario: Present images

- **WHEN** `raw_listing$images` is present
- **THEN** `images` SHALL be `list(as.character(raw_listing$images))`
- **AND** the flatfox API's integer image IDs SHALL be coerced to `character` (not stored as objects with a `url` field — that shape was removed from the public API)

#### Scenario: No images

- **WHEN** `raw_listing$images` is `NULL`
- **THEN** `images` SHALL be `list(character(0))` (a list containing an empty character vector)

