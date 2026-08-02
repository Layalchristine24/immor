# http-layer Specification

## Purpose
TBD - created by archiving change seed-initial-specs. Update Purpose after archive.
## Requirements
### Requirement: Shared request builder

The package SHALL provide an internal `immor_request(req, delay = 2)` builder that decorates every outbound `httr2` request with a shared set of policies.

#### Scenario: Every portal HTTP call routes through the builder

- **WHEN** any portal `fetch_listings.immor_portal_<name>()` (or its helpers) issues an HTTP request
- **THEN** the request SHALL be constructed via `httr2::request(...) |> immor_request()` before `httr2::req_perform()`
- **AND** portal code SHALL NOT call `httr2::req_user_agent()`, `httr2::req_throttle()`, or `httr2::req_retry()` directly

### Requirement: Package-identified user agent

`immor_request()` SHALL set a user-agent header that identifies the package and its installed version.

#### Scenario: User-agent header format

- **WHEN** `immor_request()` decorates a request
- **THEN** the user-agent SHALL be `"immor/{utils::packageVersion(\"immor\")} (R package)"`
- **AND** SHALL be applied via `httr2::req_user_agent()`

### Requirement: Per-host rate throttling

`immor_request()` SHALL enforce a per-host request rate via `httr2::req_throttle()`, with a default of one request per two seconds.

#### Scenario: Default delay

- **WHEN** a caller does not override `delay`
- **THEN** the request SHALL be throttled at `rate = 1 / 2` (one request per two seconds per host)

#### Scenario: Explicit longer delay

- **WHEN** a caller passes `delay = 10` (e.g. weck-aeby's mandated 10-second crawl delay)
- **THEN** the request SHALL be throttled at `rate = 1 / 10`
- **AND** callers MAY only increase the delay; a delay shorter than the default MUST NOT be introduced without explicit justification in a new proposal

### Requirement: Retry with exponential backoff

`immor_request()` SHALL apply a retry policy via `httr2::req_retry()` with a bounded number of attempts and an escalating backoff.

#### Scenario: Retry policy

- **WHEN** `immor_request()` decorates a request
- **THEN** `httr2::req_retry(max_tries = 3, backoff = \(x) x * 2)` SHALL be applied
- **AND** transient HTTP failures SHALL be retried up to two additional times before the request propagates the error to the caller

### Requirement: Portal fetch method uses the builder for all requests

Every portal's fetch and helper functions SHALL construct HTTP requests through `immor_request()` so that user-agent, throttle, and retry apply uniformly.

#### Scenario: Direct httr2 call is a contract violation

- **WHEN** a code reviewer or lint pass finds `httr2::request(...) |> httr2::req_perform()` without an intervening `immor_request()`
- **THEN** the caller SHALL be considered non-compliant and MUST be corrected before merge

