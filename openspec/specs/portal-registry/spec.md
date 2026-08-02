# portal-registry Specification

## Purpose
TBD - created by archiving change seed-initial-specs. Update Purpose after archive.
## Requirements
### Requirement: Portal object constructor

The package SHALL expose `new_portal(name, base_url, ...)` as the S3 constructor for portal objects.

#### Scenario: Class assignment

- **WHEN** `new_portal(name = "example", base_url = "https://example.com", some_field = 1)` is called
- **THEN** the returned object SHALL be a list with fields `name`, `base_url`, and any additional named arguments from `...`
- **AND** its `class()` SHALL be `c("immor_portal_example", "immor_portal")` — subclass first, base class second

### Requirement: Print method

An `immor_portal` object SHALL have a `print` method that summarises the portal.

#### Scenario: Printing a portal

- **WHEN** the user prints a portal
- **THEN** `print.immor_portal()` SHALL emit a `cli::cli_h3()` heading "immor portal: {x$name}" and a `cli::cli_dl()` describing at least `"Base URL"`
- **AND** SHALL return the object invisibly

### Requirement: Fetch generic

The package SHALL define `fetch_listings(portal, query, max_pages = 5L, ...)` as an S3 generic with `UseMethod("fetch_listings")`.

#### Scenario: Dispatching to a portal implementation

- **WHEN** `fetch_listings(portal_flatfox(), immor_query())` is called
- **THEN** dispatch SHALL land on `fetch_listings.immor_portal_flatfox`

#### Scenario: Portal without implementation

- **WHEN** dispatch falls through to the base `fetch_listings.immor_portal` default (no subclass method defined)
- **THEN** the default SHALL abort via `cli::cli_abort()` naming the portal and instructing the reader to implement `fetch_listings.immor_portal_<name>`

### Requirement: Parse generic

The package SHALL define `parse_listing(portal, raw_listing)` as an S3 generic with `UseMethod("parse_listing")`.

#### Scenario: Dispatching to a portal parser

- **WHEN** `parse_listing(portal_flatfox(), raw)` is called with a portal that has a method defined
- **THEN** dispatch SHALL land on `parse_listing.immor_portal_flatfox`

#### Scenario: Portal without parser

- **WHEN** dispatch falls through to the base `parse_listing.immor_portal` default
- **THEN** the default SHALL abort via `cli::cli_abort()` naming the portal and instructing the reader to implement `parse_listing.immor_portal_<name>`

### Requirement: Registry enumeration

The package SHALL expose `immor_portals()` as a no-argument function returning a named list of portal constructor functions.

#### Scenario: Registered portals

- **WHEN** `immor_portals()` is called
- **THEN** the returned list SHALL contain at minimum the keys `"flatfox"` and `"weckaeby"`
- **AND** each entry SHALL be a function that, when invoked with no arguments, returns an `immor_portal` object

### Requirement: Registry lookup by name

The package SHALL expose `immor_portal(name)` that looks up and constructs a portal by name.

#### Scenario: Known portal name

- **WHEN** `immor_portal("flatfox")` is called
- **THEN** the function SHALL return `portal_flatfox()`

#### Scenario: Unknown portal name

- **WHEN** `immor_portal("unknown")` is called with a name not in `immor_portals()`
- **THEN** the function SHALL abort via `cli::cli_abort()` with the offending name and a list of available portals

### Requirement: New portals register through the same registry

Any new portal added under [`R/portal-<name>.R`](/R/) SHALL register itself by being added to the list literal returned by `immor_portals()` in [`R/portals.R`](/R/portals.R).

#### Scenario: New portal not registered

- **WHEN** a new portal file `R/portal-<name>.R` is added but `immor_portals()` is not updated
- **THEN** [`immor_fetch()`](/openspec/specs/multi-portal-fetch/spec.md) SHALL not reach that portal, and `immor_portal("<name>")` SHALL abort — this constitutes an incomplete change

