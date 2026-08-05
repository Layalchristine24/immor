# Contributing to immor

This outlines how to propose a change to immor.
For a detailed discussion on contributing to this and other tidyverse-style packages, please see the [development contributing guide](https://rstd.io/tidy-contrib) and our [code review principles](https://code-review.tidyverse.org/).

## Fixing typos

You can fix typos, spelling mistakes, or grammatical errors in the documentation directly using the GitHub web interface, as long as the changes are made in the _source_ file.
This generally means you'll need to edit [roxygen2 comments](https://roxygen2.r-lib.org/articles/roxygen2.html) in an `.R`, not a `.Rd` file.
You can find the `.R` file that generates the `.Rd` by reading the comment in the first line.

## Bigger changes

If you want to make a bigger change, it's a good idea to first file an issue and make sure someone from the team agrees that it's needed.
If you've found a bug, please file an issue that illustrates the bug with a minimal
[reprex](https://www.tidyverse.org/help/#reprex) (this will also help you write a unit test, if needed).
See our guide on [how to create a great issue](https://code-review.tidyverse.org/issues/) for more advice.

### Pull request process

*   Fork the package and clone onto your computer. If you haven't done this before, we recommend using `usethis::create_from_github("Layalchristine24/immor", fork = TRUE)`.

*   Install all development dependencies with `devtools::install_dev_deps()`, and then make sure the package passes R CMD check by running `devtools::check()`.
    If R CMD check doesn't pass cleanly, it's a good idea to ask for help before continuing.
*   Create a Git branch for your pull request (PR). We recommend using `usethis::pr_init("brief-description-of-change")`.

*   Make your changes, commit to git, and then create a PR by running `usethis::pr_push()`, and following the prompts in your browser.
    The title of your PR should briefly describe the change.
    The body of your PR should contain `Fixes #issue-number`.

*  For user-facing changes, add a bullet to the top of `NEWS.md` (i.e. just below the first header). Follow the style described in <https://style.tidyverse.org/news.html>. Note that `NEWS.md` is maintained by [fledge](https://fledge.cynkra.com/); contributors add bullets to the top and fledge handles the release-note grouping and versioning at bump time.

### Code style

*   New code should follow the tidyverse [style guide](https://style.tidyverse.org).
    Apply it via [`air format .`](https://posit-dev.github.io/air/) — config lives in [`air.toml`](/air.toml). Please don't restyle code that has nothing to do with your PR.

*  We use [roxygen2](https://cran.r-project.org/package=roxygen2), with [Markdown syntax](https://cran.r-project.org/web/packages/roxygen2/vignettes/rd-formatting.html), for documentation.

*  We use [testthat](https://cran.r-project.org/package=testthat) (edition 3) for unit tests.
   Contributions with test cases included are easier to accept.

#### Project-specific style overrides

A few rules that deviate from or extend the tidyverse defaults for this package:

*   **Pipes**: use the base pipe `|>`, **never** magrittr `%>%`. magrittr is deliberately not a dependency; mixing pipe styles introduces one and makes diffs noisy.

*   **Anonymous functions**: use the shorthand `\()` (e.g. `\(x) x * 2`), not `function(x) x * 2`.

*   **User-facing messages**: prefer `cli::cli_abort()`, `cli::cli_warn()`, and `cli::cli_inform()` over base R `stop()` / `warning()` / `message()`. Use `cli`'s inline markup (`{.val ...}`, `{.fn ...}`, `{.url ...}`, `{?s}` pluralisation).

*   **Argument validation**: use `rlang::arg_match()` for enum-style arguments (see [`R/deduplicate.R`](/R/deduplicate.R) for the `method` argument pattern).

*   **Type stability**: every `fetch_listings.immor_portal_*()` method MUST end its return path with `validate_listings(result)`. `validate_listings()` uses the internal `ensure_type()` helper (a `vctrs::vec_cast()` wrapper) to enforce the 28-column schema; mismatched column types error immediately.

*   **File ↔ function naming**:
    - Portal files: `R/portal-<name>.R` houses `portal_<name>()`, plus the S3 methods `fetch_listings.immor_portal_<name>()` and `parse_listing.immor_portal_<name>()`.
    - Public API prefix `immor_*`: `immor_query()`, `immor_fetch()`, `immor_portals()`, `immor_portal()`, `immor_schema()`, `immor_deduplicate()`, `immor_request()` (internal).
    - Internal parser helpers use the portal prefix: `flatfox_parse_offer_type()`, `weckaeby_parse_price()`, etc.

*   **Global variables**: `R/globals.R` is managed by [`roxyglobals`](https://github.com/anthonynorth/roxyglobals). Do not hand-edit it. Add `#' @autoglobal` (or `#' @globals varname`) to the roxygen block of the function that needs it, then run `devtools::document()`.

*   **HTTP**: all outbound HTTP calls MUST go through `immor_request()` so they inherit user-agent identification, rate limiting, and retry-with-backoff. Do not call `httr2::request()` directly at the fetch layer.

*   **Caching**: the on-disk cache lives at the `immor_fetch()` umbrella level, not at the HTTP layer. New portals inherit caching automatically — they do NOT need a `cache` argument or any cache-specific plumbing. See [`R/cache.R`](/R/cache.R) for the DuckDB-backed helpers (`immor_cache_dir()`, `immor_cache_db_path()`, `immor_cache_clear()`).

For everything else, defer to <https://style.tidyverse.org>.

### Testing conventions

*   Tests for `R/<name>.R` live in `tests/testthat/test-<name>.R`.
*   Use `expect_snapshot(error = TRUE)` for testing error messages and `expect_snapshot()` for warnings.
*   Use `testthat::local_mocked_bindings()` (or fixtures) to isolate tests from network.
*   Portal fixture data belongs in `tests/testthat/fixtures/` — reference it via `test_path("fixtures", "file.json")`.
*   Portal snapshots regenerate via `testthat::snapshot_accept()` when the underlying wire format intentionally changes; otherwise treat a diff as a regression to investigate.

### Running checks

```bash
air format .                              # format
Rscript -e "devtools::document()"         # regenerate .Rd + NAMESPACE + globals
Rscript -e "devtools::test()"             # run testthat suite
Rscript -e "devtools::check()"            # full R CMD check
```

## Adding a new portal

Before writing code, verify:

- The portal uses HTTPS.
- Its `robots.txt` allows the endpoints you need (respect any crawl-delay).
- Its ToS does not explicitly forbid automated access.
- At least one field beyond the schema's minimum can be extracted usefully.

Then:

1. Create `R/portal-<name>.R` following the pattern in [`R/portal-flatfox.R`](/R/portal-flatfox.R) (API portal) or [`R/portal-weckaeby.R`](/R/portal-weckaeby.R) (HTML portal):
   - Constructor `portal_<name>()` calling `new_portal()`.
   - Fetch method `fetch_listings.immor_portal_<name>(portal, query, max_pages, ...)`.
   - Parse method `parse_listing.immor_portal_<name>(portal, raw_listing)`.
2. Ensure `parse_listing()` returns columns matching [`immor_schema()`](/R/schema.R); end `fetch_listings` with `validate_listings(result)`.
3. Register the portal in [`R/portals.R`](/R/portals.R) by adding it to `immor_portals()`.
4. Add tests in `tests/testthat/test-portal-<name>.R` with fixture data under `tests/testthat/fixtures/`.
5. Update the portal landscape section of [`doc/design.md`](/doc/design.md#portal-landscape).
6. Add the topic to [`_pkgdown.yml`](/_pkgdown.yml).
7. Draft an OpenSpec change under `openspec/changes/<slug>/` capturing the new capability (see the top-level [`CLAUDE.md`](/CLAUDE.md#using-openspec)).

## OpenSpec workflow

The architectural source-of-truth for this package is [`openspec/`](/openspec/). Before changing behaviour, draft a change proposal:

```bash
/opsx:propose <change-slug>            # from inside Claude Code
# or non-interactively:
openspec new change <change-slug>
```

See the top-level [`CLAUDE.md`](/CLAUDE.md#using-openspec) for the full lifecycle (proposal → design → spec delta → tasks → apply → verify → archive).

## Telemetry

immor itself ships no telemetry. OpenSpec (the workflow tool used to author change proposals in this repo) collects anonymous usage stats (command names + version, no arguments / paths / content / PII) by default. CI runs are auto-opted-out; for local shells, opt out once — this aligns with the project's no-telemetry posture in [`CLAUDE.md`](/CLAUDE.md). Either env var works — pick one:

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

Setting both is harmless. If you already have `DO_NOT_TRACK=1` from a previous opt-out, you don't need `OPENSPEC_TELEMETRY=0`. See the [OpenSpec README quick-start](https://github.com/Fission-AI/OpenSpec/blob/main/README.md#quick-start) for the canonical description, and [`CLAUDE.md`](/CLAUDE.md) "AI safety: Privacy / telemetry posture" for the broader policy posture.

## Code of Conduct

Please note that the immor project is released with a
[Contributor Code of Conduct](/CODE_OF_CONDUCT.md). By contributing to this
project you agree to abide by its terms.
