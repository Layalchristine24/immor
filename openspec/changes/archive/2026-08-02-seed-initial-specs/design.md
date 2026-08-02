## Context

immor is at package version `0.0.0.9003`. The package's [`R/`](/R/) tree has stabilised around eleven files that implement a well-defined set of behaviours (see [`/plan.md`](/plan.md) sections 1.1–1.12 and 3.2 for the working history). [`/doc/design.md`](/doc/design.md) captures the architecture in prose, and [`/doc/portals.md`](/doc/portals.md) documents the portal landscape as of 2026-04-01.

What is missing is the machine-readable contract layer: [`openspec/specs/`](/openspec/specs/) is empty. As a result:

1. `openspec list --specs` is empty and `openspec spec <capability>` has no answers.
2. Every future OpenSpec change would have to spell out MODIFIED requirements against a spec that doesn't yet exist — awkward and error-prone.
3. AI agents cannot honour the [`/CLAUDE.md`](/CLAUDE.md) directive to "cite the relevant [`openspec/specs/<capability>/spec.md`](/openspec/specs/) before showing any code" because there are no specs to cite.

The reasonable seed moment is now: the code is stable, the portal set is minimal (flatfox + weckaeby), and the schema is frozen at 28 columns.

## Goals / Non-Goals

**Goals:**

- Establish nine capability specs that together cover the entire public API and every internal contract that other portals must respect (`immor_request()`, `validate_listings()`, the S3 generics).
- Ground each requirement in a specific source-code owner so future changes can locate the affected file quickly.
- Use ADDED Requirements only — the seed change captures current behaviour verbatim.
- Pass `openspec validate seed-initial-specs --strict`.

**Non-Goals:**

- No `R/` changes. No new behaviour, no refactors, no dependency changes, no test changes, no NEWS.md entry (seeding docs is not user-facing).
- No coverage of future portals (immoscout24, comparis, newhome, homegate). Those enter as new capabilities via their own OpenSpec changes — see [`/doc/portals.md`](/doc/portals.md) for the queue.
- No coverage of `blockr.immor`, which lives in a separate repository and owns its own specs.
- No `## MODIFIED Requirements` — none exist yet.

## Decisions

### D1. One capability per public API concept, not one per file

**Choice**: nine capabilities keyed to concepts (`multi-portal-fetch`, `query-construction`, `listing-schema`, `type-enforcement`, `http-layer`, `portal-registry`, `portal-flatfox`, `portal-weckaeby`, `deduplication`) rather than one per [`R/`](/R/) file.

**Rationale**: OpenSpec's granularity should match the user-visible surface, not the file layout. `R/portals.R` (registry) and `R/portal.R` (generics) both feed the `portal-registry` capability; splitting them would fragment the contract. Conversely `R/portal-flatfox.R` is a fully self-contained portal implementation and gets its own capability so it can evolve independently of other portals.

**Alternative considered**: One capability per exported function. Rejected — too fine-grained, would create ~10 tiny specs for `immor_schema()`, `immor_query()`, `immor_deduplicate()` that duplicate description without adding contract precision.

### D2. `multi-portal-fetch` is the umbrella; other capabilities are its building blocks

**Choice**: `multi-portal-fetch` is named as the umbrella in [`/CLAUDE.md`](/CLAUDE.md) and cross-references the eight building blocks it composes.

**Rationale**: matches the mental model documented in [`/doc/design.md`](/doc/design.md) (data-flow diagram): `immor_query()` → `immor_fetch()` → portal `fetch_listings` → `parse_listing` → `validate_listings` → `immor_deduplicate` → tibble. Users start with `immor_fetch()` and only descend into per-portal specs when the umbrella doesn't answer their question.

### D3. Portal-specific parsing lives inside the portal spec, not in `listing-schema`

**Choice**: `listing-schema` describes the 28-column zero-row tibble and the "common denominator" rule. Each portal spec then adds requirements describing how it fills those columns.

**Rationale**: the schema does not care whether flatfox's `offer_type = "RENT"` becomes `transaction_type = "rent"` — that mapping is a portal concern. Keeping it there means adding a new portal touches only its own spec and does not need to modify `listing-schema`.

### D4. Cross-cutting `http-layer` requirements are one capability, not repeated

**Choice**: `immor_request()`'s user-agent, throttle, and retry behaviour lives in `http-layer`. Portal specs REFER to `http-layer` for HTTP-level guarantees but do not duplicate the requirements.

**Rationale**: violation-of-duplication catches divergence: if a future proposal reduces the retry count from 3, it only needs to modify `http-layer` — every portal is affected transitively. No coordinated multi-spec update.

### D5. Portal-registry owns the S3 generics + their default-method aborts

**Choice**: `fetch_listings.immor_portal` and `parse_listing.immor_portal` (the abort defaults) are requirements under `portal-registry`, not under each portal.

**Rationale**: those defaults are the contract that says "every portal MUST implement its own method". They belong at the registry level. Individual portal specs then add "SHALL implement `fetch_listings.immor_portal_<name>`" as a concrete refinement.

### D6. `deduplication` is separate from `multi-portal-fetch`

**Choice**: even though `immor_fetch(deduplicate = TRUE)` calls `immor_deduplicate()` by default, deduplication has its own capability spec.

**Rationale**: it is independently useful (users can call `immor_deduplicate()` on hand-assembled tibbles) and its logic — the exact key, the first-by-portal winning strategy — is likely to see future changes (fuzzy matching, per-key weighting). Isolating it minimises churn in `multi-portal-fetch` when dedup evolves.

### D7. Requirement names are noun-phrase capability slices

**Choice**: use descriptive noun phrases like "Registered portals enumeration" or "Retry with exponential backoff", not verb phrases like "Enumerates registered portals" or "Retries with backoff".

**Rationale**: OpenSpec's `### Requirement: <name>` reads naturally as "capability spec MUST provide `<name>`" — nouns compose cleanly under both `ADDED` and `MODIFIED` headers.

## Risks / Trade-offs

- **[Risk]** Seed specs will inevitably freeze some accidental behaviour that was never intended as a contract (e.g. the exact wording of `cli_inform` messages, or the specific default `max_pages = 5L`). → **Mitigation**: keep requirements at the observable-behaviour level, not the message-wording level. Where a numeric default matters, document it as-is; a future change can propose a MODIFIED requirement to change it consciously.
- **[Risk]** Users may search `openspec/specs/` for portals that don't exist yet (homegate, immoscout24). → **Mitigation**: [`/doc/portals.md`](/doc/portals.md) already lists the full portal landscape with block-status rationale. `/CLAUDE.md` points there.
- **[Risk]** `type-enforcement` and `listing-schema` are tightly coupled — the schema's type list is the argument set to `validate_listings()`. → **Mitigation**: acceptable coupling. A future MODIFIED to `listing-schema` (add a column) will necessarily MODIFY `type-enforcement`; the two specs cross-reference each other explicitly to make that obvious.
- **[Trade-off]** Per-portal specs mean the umbrella `multi-portal-fetch` cannot fully describe what happens without the reader also opening the portal spec. → Accepted: it matches the code split. `multi-portal-fetch` describes the aggregation contract; the portal specs describe the wire-format contract.

## Migration Plan

Not applicable — this is docs-only. No deploy, no rollback. After the PR is merged, `/opsx:archive seed-initial-specs` moves the change under `openspec/changes/archive/` and copies the ADDED requirements into `openspec/specs/<capability>/spec.md`.

## Open Questions

1. Should `blockr.immor` integration be a capability here (call it `blockr-source-integration`)? → **Deferred**. `blockr.immor` is a separate repo with its own OpenSpec instance. This repo's specs describe what `blockr.immor` consumes, not the block API itself.
2. Should `_pkgdown.yml` reference index be captured as a spec? → **No**. That is a build artefact; the reference topics can be inferred from `@export` tags.
3. Should `NEWS.md` / `fledge` release conventions be captured as a `release-cadence` capability? → **Deferred**. Not part of the runtime contract; move to a separate proposal if it becomes a source of confusion.
