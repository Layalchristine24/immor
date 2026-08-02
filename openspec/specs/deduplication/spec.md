# deduplication Specification

## Purpose
TBD - created by archiving change seed-initial-specs. Update Purpose after archive.
## Requirements
### Requirement: Public deduplicator

The package SHALL expose `immor_deduplicate(listings, method = c("exact"))` as the deduplication entry point over a listings tibble conforming to [`immor_schema()`](/openspec/specs/listing-schema/spec.md).

#### Scenario: Method validation

- **WHEN** `method` is supplied
- **THEN** the value SHALL be validated by `rlang::arg_match()` against the allowed set (currently `"exact"` only)
- **AND** an invalid value SHALL abort with the `rlang::arg_match` diagnostic

### Requirement: Empty-input passthrough

`immor_deduplicate()` SHALL return an empty tibble unchanged.

#### Scenario: Zero-row input

- **WHEN** `nrow(listings) == 0`
- **THEN** the function SHALL return `listings` unchanged and SHALL NOT emit any `cli` messages

### Requirement: Exact-match key

`method = "exact"` SHALL treat listings as duplicates when their `address_zip`, `address_street`, `rooms`, and `price` all match after coercion to character via `paste(..., sep = "|")`.

#### Scenario: Composite key

- **WHEN** two listings across portals have identical `address_zip`, `address_street`, `rooms`, and `price`
- **THEN** they SHALL be flagged as duplicates and only one row SHALL survive
- **AND** the composite key SHALL be built as `paste(zip, street, rooms, price, sep = "|")` with `NULL` values coerced to `""`

#### Scenario: Any one field differs

- **WHEN** two listings agree on three of the four key fields but differ on the fourth
- **THEN** they SHALL NOT be treated as duplicates and both rows SHALL survive

### Requirement: First-by-portal winning strategy

Among rows sharing a composite key, the surviving row SHALL be the first one after ordering by `portal` (alphabetical).

#### Scenario: Cross-portal duplicate

- **WHEN** a listing exists in both `"flatfox"` and `"weckaeby"` with the same composite key
- **THEN** the `"flatfox"` row SHALL survive (alphabetical priority) and the `"weckaeby"` row SHALL be removed

### Requirement: Deduplication reporting

`immor_deduplicate()` SHALL report the number of removed rows to the user when it removes any.

#### Scenario: Duplicates removed

- **WHEN** the function removes `n_removed > 0` rows
- **THEN** it SHALL emit `cli::cli_inform("Removed {n_removed} duplicate listing{?s}.")` exactly once
- **AND** the return value's row count SHALL equal `nrow(listings) - n_removed`

#### Scenario: No duplicates found

- **WHEN** every row has a unique composite key
- **THEN** the function SHALL return the input unchanged and SHALL NOT emit a message

### Requirement: Internal key column is not exposed

The temporary composite-key column used during deduplication SHALL NOT appear in the returned tibble.

#### Scenario: Return schema preserved

- **WHEN** `immor_deduplicate()` returns
- **THEN** the returned tibble's columns SHALL exactly match the input columns (no `dedup_key_` or similar internal artefact SHALL be present)

