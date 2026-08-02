## ADDED Requirements

### Requirement: Canonical zero-row tibble

The package SHALL expose `immor_schema()` as a no-argument function that returns a zero-row `tibble::tibble` with exactly 28 columns in a fixed order.

#### Scenario: Column names and order

- **WHEN** `immor_schema()` is called
- **THEN** the returned tibble SHALL have zero rows
- **AND** its column names SHALL be, in order: `portal`, `portal_id`, `url`, `scraped_at`, `transaction_type`, `property_type`, `title`, `description`, `price`, `price_unit`, `currency`, `rooms`, `area_m2`, `floor`, `address_street`, `address_zip`, `address_city`, `address_canton`, `latitude`, `longitude`, `images`, `available_from`, `year_built`, `has_balcony`, `has_parking`, `has_elevator`, `is_furnished`, `energy_label`

### Requirement: Canonical column types

Every column of `immor_schema()` SHALL have a fixed R type that every portal parser must match.

#### Scenario: Type prototypes

- **WHEN** the schema is created
- **THEN** column types SHALL be:
  - `character()`: `portal`, `portal_id`, `url`, `transaction_type`, `property_type`, `title`, `description`, `price_unit`, `currency`, `address_street`, `address_zip`, `address_city`, `address_canton`, `energy_label`
  - `numeric()` (double): `price`, `rooms`, `area_m2`, `latitude`, `longitude`
  - `integer()`: `floor`, `year_built`
  - `logical()`: `has_balcony`, `has_parking`, `has_elevator`, `is_furnished`
  - `list()`: `images`
  - `POSIXct`: `scraped_at`
  - `Date`: `available_from`

### Requirement: Common-denominator schema

The schema SHALL represent the common denominator across all portals — a portal that cannot fill a column SHALL emit `NA` of the correct type, and columns SHALL NOT be portal-specific.

#### Scenario: Portal missing a field

- **WHEN** a portal cannot extract `address_canton` (e.g. flatfox does not expose canton)
- **THEN** the portal parser SHALL set `address_canton = NA_character_` rather than omitting the column

#### Scenario: Adding a new column

- **WHEN** a proposal seeks to add a new column to `immor_schema()`
- **THEN** the proposal SHALL demonstrate that at least two portals populate that column with real data (not `NA`)
- **AND** portal-specific fields SHALL NOT be added

### Requirement: Schema is authoritative

Every portal's `fetch_listings.immor_portal_<name>()` return value SHALL exactly match `immor_schema()` in column set, column order, and column type.

#### Scenario: Portal returns non-schema tibble

- **WHEN** a portal parser produces columns that do not match the schema
- **THEN** [`validate_listings()`](/openspec/specs/type-enforcement/spec.md) SHALL abort at that portal's boundary, before rows enter [`immor_fetch()`](/openspec/specs/multi-portal-fetch/spec.md)
