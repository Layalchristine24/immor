<!-- NEWS.md is maintained by https://fledge.cynkra.com, contributors should not edit this file -->

# immor (development version)

* `immor_query()` is now a no-argument constructor. All parameters (`transaction_type`, `location`, `rooms`, `price`, `property_type`, `bbox`) have been removed since the flatfox API ignores all query filters. Use 'blockr.immor' for interactive filtering.
* `portal_flatfox()` updated to use the new `/api/v1/public-listing/` endpoint after the previous `/api/v1/flat/` endpoint was removed.
* Removed `portal_homegate()` — homegate.ch is blocked by DataDome bot protection and cannot be scraped.
* Removed standalone Shiny app (`run_app()`). Use 'blockr.immor' for the interactive UI.
* Removed unused `immor_cache()` function.
* Added `@examples` to all exported functions.

# immor 0.0.0.9001 (2026-03-11)

## Chore

- Use air.

- Use roxyglobals.

- Add readme.

- Create R package.
