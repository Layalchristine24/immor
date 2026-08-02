## 1. Author the nine capability specs

- [x] 1.1 Write `specs/multi-portal-fetch/spec.md` covering `immor_fetch()` orchestration, per-portal error isolation, aggregation, optional dedup, pagination cap.
- [x] 1.2 Write `specs/query-construction/spec.md` covering `immor_query()` no-argument S3 constructor and its `print` method.
- [x] 1.3 Write `specs/listing-schema/spec.md` covering the 28-column canonical zero-row tibble, column types, common-denominator rule.
- [x] 1.4 Write `specs/type-enforcement/spec.md` covering `ensure_type()`, `validate_listings()`, and portal-boundary contract.
- [x] 1.5 Write `specs/http-layer/spec.md` covering `immor_request()` user-agent + throttle + retry.
- [x] 1.6 Write `specs/portal-registry/spec.md` covering `new_portal()`, `immor_portals()`, `immor_portal()`, and the `fetch_listings` / `parse_listing` S3 generics.
- [x] 1.7 Write `specs/portal-flatfox/spec.md` covering the flatfox REST-API scraper: pagination, offer/property type normalisation, image list shape.
- [x] 1.8 Write `specs/portal-weckaeby/spec.md` covering the weckaeby HTML scraper: two-stage archive→detail, 10 s crawl delay, CasaWP parsing rules.
- [x] 1.9 Write `specs/deduplication/spec.md` covering `immor_deduplicate()` exact-match composite key and first-by-portal winning rule.

## 2. Validate the change

- [ ] 2.1 Run `openspec validate seed-initial-specs --strict` and confirm zero errors.
- [ ] 2.2 Run `openspec show seed-initial-specs --json --deltas-only | jq '.deltas | length'` and confirm nine capability deltas are recognised.
- [ ] 2.3 Run `openspec status --change seed-initial-specs` and confirm 4/4 artefacts are done.

## 3. Ship

- [ ] 3.1 Commit the change folder + updated `/CLAUDE.md`, `/.github/CONTRIBUTING.md`, `/README.Rmd`, `/README.md`, `/CODE_OF_CONDUCT.md`.
- [ ] 3.2 Push branch `docs-update-specs`, open PR, merge.
- [ ] 3.3 After merge, run `openspec archive seed-initial-specs` to move the specs into [`/openspec/specs/`](/openspec/specs/).
- [ ] 3.4 Commit and push the archived state: `chore(openspec): archive seed-initial-specs`.

## 4. Follow-up

- [ ] 4.1 Confirm `openspec list --specs` now lists all nine capabilities.
- [ ] 4.2 Confirm `openspec spec <capability>` renders for each of the nine.
- [ ] 4.3 Verify [`/CLAUDE.md`](/CLAUDE.md) capability-map links all resolve on the merged commit.
