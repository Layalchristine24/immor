## ADDED Requirements

### Requirement: No-argument query constructor

The package SHALL expose `immor_query()` as a **no-argument** S3 constructor that returns an object of class `immor_query`.

#### Scenario: Constructor call

- **WHEN** a caller invokes `immor_query()`
- **THEN** the function SHALL return an object `x` with `class(x) == "immor_query"`
- **AND** `x` SHALL be an empty list (`length(x) == 0`)

#### Scenario: No filter arguments accepted

- **WHEN** `immor_query()` is documented and inspected
- **THEN** the function SHALL take no arguments
- **AND** its help page SHALL make clear that filtering is applied post-fetch by consumers (e.g. `blockr.immor` via `dplyr::filter()` on the returned tibble)

### Requirement: Printed representation

An `immor_query` object SHALL have a `print` method that describes its behaviour to the user.

#### Scenario: Printing an immor_query

- **WHEN** the user prints an `immor_query` object
- **THEN** `print.immor_query()` SHALL emit a `cli::cli_h3()` heading "immor query" and one `cli::cli_inform()` line explaining that all available listings will be fetched from registered portals
- **AND** SHALL return the object invisibly

### Requirement: Portal contract

Every portal `fetch_listings.immor_portal_<name>()` method SHALL accept an `immor_query` object as its `query` argument even if it does not use the query's fields.

#### Scenario: Query passthrough

- **WHEN** [`immor_fetch()`](/openspec/specs/multi-portal-fetch/spec.md) dispatches to a portal
- **THEN** the portal method SHALL receive the exact `immor_query` object supplied by the caller
- **AND** SHALL NOT be required to inspect any of its fields (a portal MAY ignore the query when its wire protocol does not support filtering, as flatfox currently does)
