# immor

This is the project-conventions file. It is auto-loaded by Claude Code (and equivalent files surface to Cursor, Continue, Copilot) on session start.

immor ("immobilier" + "R", sounds like "immortal") scrapes real estate listings from Swiss property portals, normalises them into a 28-column tibble, and provides type-safe deduplication. It is the data engine behind [`blockr.immor`](https://github.com/Layalchristine24/blockr.immor).

The architectural source-of-truth for the package is [`openspec/`](openspec/):

- **Current behaviour** — one spec per capability under [`openspec/specs/<slug>/spec.md`](openspec/specs/).
- **Active proposals** — in-flight or deferred work under [`openspec/changes/<slug>/proposal.md`](openspec/changes/).
- **Historical decisions** — one folder per merged PR under [`openspec/changes/archive/`](openspec/changes/archive/).

**Developer docs** — for an English onboarding lens (architectural map + portal landscape + vocabulary glossary + forward-looking roadmap), see [`doc/design.md`](doc/design.md), [`doc/glossary.md`](doc/glossary.md), and [`doc/roadmap.md`](doc/roadmap.md). The OpenSpec specs remain authoritative — `doc/` is the human-reading entry point that links into them.

## Answering questions about this codebase

When asked *"how do I…"*, *"how does X work"*, *"what's the contract for…"*, or any behavioural / workflow question, **your first response must cite the relevant [`openspec/specs/<capability>/spec.md`](openspec/specs/) before showing any code, build target, or command**. Code is the implementation; specs are the contract. If a question can't be answered from any spec, flag the gap to the user rather than silently answering from code.

### Capability map

| Capability | What it covers |
|---|---|
| [`multi-portal-fetch`](openspec/specs/multi-portal-fetch/spec.md) | **Umbrella — start here.** `immor_fetch(query, portals, deduplicate, max_pages)` orchestrates one or more portal scrapers, aggregates results into a single tibble, and optionally deduplicates. |
| [`query-construction`](openspec/specs/query-construction/spec.md) | `immor_query()` — the no-argument S3 constructor consumed by every portal `fetch_listings` method. |
| [`listing-schema`](openspec/specs/listing-schema/spec.md) | `immor_schema()` — the 28-column canonical tibble every portal must produce. Common-denominator approach; missing portal fields become `NA`. |
| [`type-enforcement`](openspec/specs/type-enforcement/spec.md) | `ensure_type()` — the `vctrs::vec_cast()` wrapper used by `validate_listings()` at each portal's exit point. Fail fast, fail early, fail clear. |
| [`http-layer`](openspec/specs/http-layer/spec.md) | `immor_request()` — user-agent, rate limiting (default 1 req/2 s), 3 retries with exponential backoff. All portal HTTP goes through this. |
| [`portal-registry`](openspec/specs/portal-registry/spec.md) | `new_portal()` + `immor_portals()` + `immor_portal()`; the `fetch_listings()` / `parse_listing()` S3 generics that portals dispatch on. |
| [`portal-flatfox`](openspec/specs/portal-flatfox/spec.md) | REST-API scraper for `flatfox.ch/api/v1/public-listing/` — offset/limit pagination, `-published` ordering, ~33 k listings, API ignores all filter params. |
| [`portal-weckaeby`](openspec/specs/portal-weckaeby/spec.md) | HTML scraper for `weck-aeby.ch` (CasaWP WordPress plugin) — two-stage archive → detail fetch, 10 s crawl delay, ~4 buy + ~15 rent. |
| [`deduplication`](openspec/specs/deduplication/spec.md) | `immor_deduplicate()` — exact matching on `(address_zip, address_street, rooms, price)`. First occurrence by `portal` name is kept. |

## Using OpenSpec

### The four artefacts of a change

Every change under `openspec/changes/<slug>/` consists of exactly four artefacts. They must be written in this order; each unlocks the next:

| # | File | Role | What it contains |
|---|---|---|---|
| 1 | `proposal.md` | **Why + what at a high level.** Prose. | `## Why`, `## What Changes`, `## Capabilities`, `## Impact`. |
| 2 | `design.md` | **How.** Architectural decisions + alternatives + trade-offs. Prose. | `## Context`, `## Goals / Non-Goals`, `## Decisions`, `## Risks / Trade-offs`, `## Open Questions`. |
| 3 | `specs/<capability>/spec.md` | **The actual contract diff.** Machine-readable. | `## ADDED Requirements` / `## MODIFIED Requirements` / `## REMOVED Requirements` / `## RENAMED Requirements`, each with `### Requirement: <name>` blocks. |
| 4 | `tasks.md` | Implementation checklist. | `## <N>. <group>` headings; `- [ ] N.M description` checkboxes. |

### Critical validator rules — read before writing the spec

The validator only accepts contract changes inside `specs/<capability>/spec.md`. Common mistakes the validator catches:

- ❌ **`## ADDED Requirements` in `proposal.md` or `design.md`** — those headers are ignored anywhere except `specs/<capability>/spec.md`. Put descriptive prose in the prose files; put diff blocks in the spec file.
- ❌ **`### Requirement: <name>` with no scenario** — every requirement MUST have at least one `#### Scenario:` block.
- ❌ **`### Scenario:` (three hashtags) instead of `#### Scenario:` (four hashtags)** — silent fail; the validator skips it.
- ❌ **Capability name in `## Capabilities` (proposal.md) ≠ folder name under `specs/<capability>/`** — mismatch breaks the link.
- ✅ Each scenario uses `**WHEN** … **THEN** …` (and optionally `**AND** …`).
- ✅ Normative language uses SHALL / MUST, not "should" / "may".

### Lifecycle — Claude Code slash commands ↔ raw CLI

Both produce the same files; pick whichever feels natural. Slash commands run conversationally; CLI runs non-interactively.

| Stage | Slash command | `opsx:` short form | Raw CLI |
|---|---|---|---|
| Brainstorm before committing to a change | `/openspec-explore` | `/opsx:explore` | (none) |
| Create the change folder *and* generate all four artefacts in one go (no stops) | `/openspec-propose <slug>` | `/opsx:propose` | `openspec new change <slug>` then 4 × `openspec instructions <artifact> --change <slug>` |
| Create the change folder and start the four artefacts *one at a time*, with a review stop after each | `/openspec-new-change <slug>` | `/opsx:new` | `openspec new change <slug>` |
| Resume an in-progress change — write the next artefact in the queue | `/openspec-continue-change` | `/opsx:continue` | `openspec status --change <slug>` + `openspec instructions <next-artifact> --change <slug>` |
| Fast-forward an in-progress change to fill in all remaining artefacts (no stops) | `/openspec-ff-change` | `/opsx:ff` | (none — orchestrates the above) |
| Implement (work through `tasks.md`) | `/openspec-apply-change` | `/opsx:apply` | (none — implement; `tasks.md` is the checklist) |
| Verify before archiving | `/openspec-verify-change` | `/opsx:verify` | `openspec validate <slug> --strict` |
| Move into archive + apply deltas to main specs | `/openspec-archive-change` | `/opsx:archive` | `openspec archive <slug>` |
| Sync deltas to main specs *without* archiving | `/openspec-sync-specs` | `/opsx:sync` | (none) |
| Bulk-archive several merged changes | `/openspec-bulk-archive-change` | `/opsx:bulk-archive` | repeated `openspec archive` |
| Guided onboarding tour | `/openspec-onboard` | `/opsx:onboard` | (none) |

**Which start command to use:** `/openspec-propose` and `/openspec-new-change` produce the **same end state** (same four files, same validator pass). They differ only in review cadence — `propose` writes all four in one turn and you review at the end; `new-change` (paired with `continue-change`) stops after each artefact so you can redirect. Switching mid-flow is fine: review breaks during a `propose` run are allowed, and `ff-change` can power through the tail of a `new-change` run.

### Concrete workflow for the next change

```bash
# 0. Branch off main
git switch main && git pull
git switch -c <topic-or-fix>-<change-slug>

# 1. From inside Claude Code:
/opsx:propose <change-slug>
# → Creates openspec/changes/<slug>/ and writes proposal.md → design.md →
#   specs/<capability>/spec.md → tasks.md. Review each artefact in the IDE
#   as it's written; push back early.

# 2. Validate
openspec validate <change-slug> --strict
openspec show <change-slug>                        # human-readable markdown rendering
openspec show <change-slug> --json --deltas-only   # machine view of parsed deltas (pipe to jq)
openspec status --change <change-slug>             # 4/4 artifacts done?

# 3. Implement
/opsx:apply
# → Works through tasks.md; review the diffs.

# 4. Ship
git add -A && git commit -m "..."
gh pr create ...                                   # or /pr-create

# 5. After merge
/opsx:archive <change-slug>
# → Moves openspec/changes/<slug>/ → openspec/changes/archive/<YYYY-MM-DD>-pr-<N>-<slug>/.
git add -A && git commit -m "chore(openspec): archive <slug>"
```

### Quick command reference

```bash
openspec list                              # all active changes
openspec list --specs                      # all current capability specs
openspec view                              # interactive dashboard
openspec status --change <slug>            # which artefacts done vs missing
openspec instructions <artifact> --change <slug>   # exact template + schema rules
openspec show <slug>                       # human-readable markdown rendering of a change
openspec show <slug> --json --deltas-only          # machine view of parsed deltas (pipe to jq)
openspec spec <capability>                 # show one capability spec
openspec validate <slug> --strict          # validate one change
openspec validate --all                    # validate every change + spec
openspec archive <slug>                    # archive + apply deltas
```

### Reference

[openspec.dev](https://openspec.dev) · [OpenSpec getting-started guide](https://github.com/Fission-AI/OpenSpec/blob/main/docs/getting-started.md) · [README quick start](https://github.com/Fission-AI/OpenSpec/blob/main/README.md#quick-start).

Past decisions live in `openspec/changes/archive/` — search there before deep-diving into `git log`.

## R-package skills

Use these skills proactively when the work matches:

- **`r-package-development`** — devtools / roxygen2 / testthat workflows.
- **`testing-r-packages`** — testthat 3+ patterns; fixtures live under [`tests/testthat/fixtures/`](tests/testthat/fixtures/).
- **`pr-create`** — open a PR + monitor CI to passing.
- **`pr-threads-address`** / **`pr-threads-resolve`** — review-thread handling.
- **`cran-extrachecks`** — only relevant if this package ever ships to CRAN (currently internal-only).
- **`lifecycle`** — deprecation + supersession workflows (not yet needed at `0.0.0.9xxx`).
- **`cli`** — error / message formatting; prefer `cli_abort` / `cli_warn` / `cli_inform` over base R `stop` / `warning` / `message`.
- **`describe-design`** — architecture documentation if a new capability needs a spec.
- **`simplify`** — review-changed-code pass for reuse / quality / efficiency.
- **`critical-code-reviewer`** — rigorous review before merge.
- **`find-skills`** — discover other skills.

## AI safety

This section declares the file-read policy so a fresh AI session doesn't have to ask. The rules are committed (in this file) and therefore apply to every contributor's AI tooling, not just the original author's.

### Universal "never read" (industry standard)

Files outside any project repository that may contain secrets or per-user state — applies to every project, not just this one:

| Category | Concrete paths |
|---|---|
| Environment files outside any repo | `~/.env*` |
| Cloud credentials | `~/.aws/credentials`, `~/.azure/`, `~/.gcp/`, `~/.gcloud/` |
| SSH / GPG | `~/.ssh/id_*`, `~/.gnupg/` |
| Token / auth stores | `~/.netrc`, `~/.npmrc`, `~/.docker/config.json`, `~/.git-credentials` |
| Per-user language config | `~/.Renviron`, `~/.Rprofile`, `~/.pypirc`, `~/.cargo/credentials` |
| Shell / session history | `~/.bash_history`, `~/.zsh_history`, `~/.Rhistory` |
| Browser / keychain stores | OS-specific (Keychain on macOS, Credential Manager on Windows) |

The user-level `~/.Renviron` / `~/.Rprofile` typically contain `GITHUB_PAT` and other API keys — never read.

**Gitignored** files inside the repo that match the same patterns (e.g. a developer's local `.env` not under version control) are also potentially secret. Don't read.

### Project-specific "never read" (this repo)

| Path | Why off-limits | Where to look instead |
|---|---|---|
| `man/*.Rd` | Auto-generated by roxygen2 — edits get overwritten. | `R/*.R` roxygen comments; regenerate via `devtools::document()`. |
| `.claude/settings.local.json` | Per-user AI tool state (allowlist, hooks). | Gitignored; never relevant to code. |
| `renv/library/`, `.Rproj.user/`, `*-Ex.R` | Build artefacts / IDE state. | `.Rbuildignore` / `.gitignore` declare the boundary. |
| `tests/testthat/_snaps/**` | Auto-generated snapshot files. | Regenerate via `testthat::snapshot_accept()` when the underlying behaviour intentionally changes. |

### Committed config is OK to read

A common over-refusal trap. The rule:

- **Committed at the repo root** (e.g. `.Rbuildignore`, `.gitignore`, `air.toml`, `DESCRIPTION`, `_pkgdown.yml`) → project config, repo-public, **OK to read**. If something inside contains a secret, that's a separate hardening task (rotate, move out, gitignore), not an AI-policy issue.
- **Gitignored** (e.g. `.claude/settings.local.json`, a local `.env`) → may contain per-developer secrets, **don't read**.
- **At `~/…`** (user-level) → never read (see universal section above).

Specs describe contracts; test fixtures under [`tests/testthat/fixtures/`](tests/testthat/fixtures/) describe portal wire formats and are safe to read.

### Privacy / telemetry posture

immor is a public GitHub repo but treat scraped listing data as third-party content that belongs to the source portals.

- **No telemetry / analytics** — don't introduce code that phones home (`posthog`, `mixpanel`, custom analytics endpoints). Existing local logging via `cli_alert_*` / `cli_inform` is fine.
- **No uploads to third-party web tools** without explicit instruction. Don't paste fixture JSON/HTML, live listing data, or API responses into pastebins / gists / online diagram renderers — even tools that advertise privacy may cache or index.
- **AI conversations** — if your AI tool offers a privacy / training opt-out (Claude Code, Cursor, Copilot all support this), turn it on for this repo.
- **`gh` CLI is OK** — it talks to GitHub which already has the code. Other outbound network access (beyond `gh`, `pak` resolving GitHub packages, and the portal HTTP calls made through `immor_request()`) requires explicit user approval before adding new calls.
- **Respect robots.txt and rate limits.** New portals only get added if their robots.txt allows scraping and their ToS does not forbid it. `immor_request()` enforces a default 2 s delay per host with 3 retries — do not weaken those defaults; per-portal overrides (e.g. weck-aeby's 10 s delay) may only increase them.
- **OpenSpec telemetry** — disabled. OpenSpec collects anonymous command-name + version stats by default. CI runs are auto-opted-out; for local shells, opt out once. Either env var works — pick one:

  **Option A — OpenSpec-specific** (recommended; scope is just OpenSpec):

  ```zsh
  echo 'export OPENSPEC_TELEMETRY=0' >> ~/.zshrc   # ~/.bashrc on bash
  source ~/.zshrc
  echo $OPENSPEC_TELEMETRY                          # → 0
  ```

  **Option B — universal opt-out**; also disables telemetry in other tools that honour the convention (npm, gh, deno, …):

  ```zsh
  echo 'export DO_NOT_TRACK=1' >> ~/.zshrc          # ~/.bashrc on bash
  source ~/.zshrc
  echo $DO_NOT_TRACK                                # → 1
  ```

  Setting both is harmless. If you already have `DO_NOT_TRACK=1` from a previous opt-out, you don't need `OPENSPEC_TELEMETRY=0`.

## Conventions

- **English code identifiers, multilingual scraped content.** Source portals ship in DE / FR / IT; the schema is English (`address_street`, `has_balcony`) and internal helper names reference the original locale only where unavoidable (`weckaeby_parse_price` etc.).
- **Base pipe `|>` only.** Do not introduce `magrittr::%>%` — the package deliberately avoids the magrittr dependency. See [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md) for the full style guide.
- **Markdown link style — root-absolute for upward links.** Adopts the [Google Markdown style guide](https://google.github.io/styleguide/docguide/style.html#links) rule:
  - A link that leaves its own directory is written from the repository root, with a leading `/` — `/R/schema.R`, not `../../R/schema.R`.
  - Same-directory and downward links stay as they are — `openspec/specs/multi-portal-fetch/spec.md`, `../portal.R` inside `R/`, `./sibling.md`.
  - Root-absolute links resolve correctly on GitHub (their docs are explicit that links "beginning with `/` are relative to the repository root"). Trade-off: local Markdown previewers (VS Code, RStudio) do not resolve the leading `/` — the docs are read on GitHub, and this file takes that trade explicitly.
  - The one known wart: a link to the repository root itself (`/` alone) 404s ([github/markup#1502](https://github.com/github/markup/issues/1502)). Don't write one. Directory links one level in and deeper (`/openspec/`, `/doc/`) resolve fine through GitHub's blob→tree redirect.
  - `CLAUDE.md` sits at the repo root, so its internal links are all downward and stay bare. `.github/CONTRIBUTING.md` sits one level deep, so anything outside `.github/` is written root-absolute (`/CLAUDE.md`, `/R/schema.R`, `/CODE_OF_CONDUCT.md`).
- **Schema is the common denominator.** New columns only get added when at least two portals populate the field. Portal-specific fields do not enter [`immor_schema()`](R/schema.R).
- **Type stability at every portal boundary.** `fetch_listings.immor_portal_*()` methods must end with `validate_listings(result)`; this is enforced via `ensure_type()` in [`R/ensure_type.R`](R/ensure_type.R).
- **Fail fast on parse errors.** `immor_fetch()` catches per-portal errors and continues (returns `immor_schema()` for the failed portal); per-listing errors inside `portal-weckaeby` are logged via `cli_warn()` and skipped. Do not swallow errors silently.
- **`roxyglobals` manages `R/globals.R`.** Don't hand-edit that file; use `@autoglobal` on functions that need it.

## Workflow

1. Before changing **behaviour**, draft `openspec/changes/<slug>/proposal.md` (or run `/opsx:propose <slug>`).
2. Implement the proposal — code changes + updates to the corresponding `openspec/specs/<slug>/spec.md` (or run `/opsx:apply`).
3. On merge, move the proposal → `archive/` (or run `/opsx:archive <slug>`).
