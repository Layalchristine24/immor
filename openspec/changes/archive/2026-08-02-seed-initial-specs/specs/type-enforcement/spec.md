## ADDED Requirements

### Requirement: `ensure_type()` helper

The package SHALL expose `ensure_type(.data, ..., .default = NULL)` as an exported helper that casts a data frame's columns to caller-specified prototype types using `vctrs::vec_cast()`.

#### Scenario: Successful cast

- **WHEN** `ensure_type(df, x = integer(), y = logical())` is called with columns already of the requested types
- **THEN** the function SHALL return a `tibble::tibble` with columns cast to the requested types in the requested order
- **AND** SHALL NOT abort

#### Scenario: Type coercion within `vctrs::vec_cast()` rules

- **WHEN** an input column can be safely coerced to the target type per `vctrs::vec_cast()` (e.g. `integer()` → `numeric()`)
- **THEN** `ensure_type()` SHALL perform the coercion and return the result
- **AND** SHALL NOT emit a warning

### Requirement: Failure-mode diagnostics

`ensure_type()` SHALL wrap `vctrs::vec_cast()` failures in a `cli::cli_abort()` chain with the parent error preserved.

#### Scenario: Incompatible types

- **WHEN** a column cannot be cast (e.g. a character column into `integer()` with non-numeric strings)
- **THEN** `ensure_type()` SHALL abort with message "Type stability violated"
- **AND** the underlying `vctrs::vec_cast()` error SHALL be attached as the `parent` of the `cli` condition
- **AND** the abort SHALL be attributed to the caller's frame via `call = .call`

#### Scenario: Column missing from input

- **WHEN** a name in `...` does not appear in `names(.data)`
- **THEN** `ensure_type()` SHALL abort with "Columns missing" and name the absent column(s) via `{.var}`

### Requirement: Optional default type

`ensure_type()` SHALL accept a `.default` prototype that applies to any input column not explicitly listed in `...`.

#### Scenario: `.default` provided

- **WHEN** a caller passes `.default = character()` and the input has columns not named in `...`
- **THEN** those columns SHALL be cast to `character()` and included in the output
- **AND** the returned tibble SHALL contain all columns from `...` plus any defaulted columns

#### Scenario: `.default` omitted

- **WHEN** `.default = NULL` (the default)
- **THEN** only columns named in `...` SHALL appear in the output
- **AND** any other columns of `.data` SHALL be dropped

### Requirement: Portal-boundary validation

The package SHALL provide `validate_listings(listings)` (internal) that calls `ensure_type()` with the full [`immor_schema()`](/openspec/specs/listing-schema/spec.md) column set as its type argument.

#### Scenario: Well-formed portal output

- **WHEN** a portal `fetch_listings.immor_portal_<name>()` method calls `validate_listings(result)` on a tibble whose columns match the schema
- **THEN** the call SHALL succeed and return the validated tibble

#### Scenario: Portal produces wrong type

- **WHEN** a portal returns `price` as `character()` instead of `numeric()`
- **THEN** `validate_listings()` SHALL abort at that portal's boundary, before the tibble enters `immor_fetch()`'s aggregation step

### Requirement: Portal method contract

Every `fetch_listings.immor_portal_<name>()` method SHALL end its return path with `validate_listings(result)` unless the return is the empty `immor_schema()` short-circuit.

#### Scenario: Non-empty result

- **WHEN** a portal parser has produced one or more rows
- **THEN** the last statement of `fetch_listings.immor_portal_<name>()` SHALL be `validate_listings(result)`

#### Scenario: Empty short-circuit

- **WHEN** a portal produced zero listings (e.g. all archive links 404-ed)
- **THEN** the portal method MAY return `immor_schema()` directly without calling `validate_listings()`
