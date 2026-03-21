# Contributing to immor

## Adding a New Portal

Before adding a portal, verify:
- The portal uses HTTPS
- The portal's robots.txt allows automated access
- The portal doesn't explicitly forbid scraping in its terms of service

Then:

1. Create `R/portal-{name}.R` following the pattern in `R/portal-flatfox.R`:
   - Constructor: `portal_{name}()` calling `new_portal()`
   - Fetch method: `fetch_listings.immor_portal_{name}(portal, query, max_pages, ...)`
   - Parse method: `parse_listing.immor_portal_{name}(portal, raw_listing)`

2. Ensure `parse_listing()` returns columns matching `immor_schema()` types. The `validate_listings()` function uses `ensure_type()` to enforce type stability — mismatched types will error immediately.

3. Register the portal in `R/portals.R` by adding it to the list returned by `immor_portals()`.

4. Write tests in `tests/testthat/test-portal-{name}.R`:
   - Test the constructor creates correct S3 classes
   - Test `parse_listing()` with mock data (add a `mock_{name}_listing()` to `tests/testthat/helper.R`)
   - Save sample API/HTML responses as fixtures in `tests/testthat/fixtures/`
   - Use `expect_snapshot()` for error/warning messages (not `expect_error()`/`expect_warning()`)

5. Add `@examples` and `@return` to the exported constructor function.

6. Document the portal in `doc/portals.md`.

7. Add the topic to `_pkgdown.yml`.

## Code Style

- Format with `air format .` after all code changes
- Use the base pipe `|>` (not magrittr `%>%`)
- Use `\()` for single-line anonymous functions
- Use `cli_abort()`, `cli_warn()`, `cli_inform()` for user-facing messages
- Use `rlang::arg_match()` for argument validation
- Wrap roxygen comments at 80 characters
- Every user-facing change gets a bullet in `NEWS.md`

## Testing Conventions

- Tests for `R/{name}.R` go in `tests/testthat/test-{name}.R`
- Use `expect_snapshot(error = TRUE)` for testing error messages
- Use `expect_snapshot()` for testing warning messages
- Use `local_mocked_bindings()` for mocking HTTP calls
- Use `test_path("fixtures", "file.json")` for fixture data
- Keep tests self-contained and minimal

## Running Checks

```bash
# Format code
air format .

# Run tests
Rscript -e "devtools::test()"

# Regenerate docs
Rscript -e "devtools::document()"

# Full package check
Rscript -e "devtools::check()"
```
