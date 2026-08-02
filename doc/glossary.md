# immor — glossary

Vocabulary reference for immor. Terms are grouped by domain so you can skim the section that matches your question. Each entry links back to the capability spec, R file, or external source that owns the concept.

If you're looking for the architectural map, read [design.md](design.md). For "what's next", read [roadmap.md](roadmap.md).

---

## Package concepts

### Portal
An S3 object representing one real-estate website that immor can scrape. Every portal has classes `c("immor_portal_<name>", "immor_portal")` and is constructed by a portal-specific factory (`portal_flatfox()`, `portal_weckaeby()`) that delegates to `new_portal()`. Portals are enumerated by [`immor_portals()`](/R/portals.R) and looked up by [`immor_portal(name)`](/R/portals.R). See [`portal-registry`](/openspec/specs/portal-registry/spec.md).

### Portal registry
The named list returned by [`immor_portals()`](/R/portals.R). Each entry maps a portal name (e.g. `"flatfox"`) to a **constructor function** that takes no arguments and returns an `immor_portal` object. Registration is explicit — no autoloading from `R/portal-*.R`.

### Query
An `immor_query` object, currently just a tagged empty list. It is the S3 hook that every portal's `fetch_listings()` method accepts even when the wire protocol supports no filtering (as with the flatfox public API). Filtering happens **after** the fetch via `dplyr::filter()`. See [`query-construction`](/openspec/specs/query-construction/spec.md).

### Schema
The 28-column canonical zero-row tibble returned by [`immor_schema()`](/R/schema.R). Every portal parser must produce rows matching this shape, column-for-column, type-for-type. See [`listing-schema`](/openspec/specs/listing-schema/spec.md).

### Common denominator (schema)
The design rule that governs the schema: a column enters the schema only if **at least two portals** can populate it with real (non-`NA`) data. A portal that cannot fill a schema column emits `NA` of the correct type. This is why `latitude` / `longitude` exist (flatfox provides them, weckaeby emits `NA`) but there is no `flatfox_pk` column. See [design.md § Design principles](design.md#1-common-denominator-schema).

### Type stability / type enforcement
The guarantee that every `fetch_listings.immor_portal_<name>()` return value has exact schema shape. Enforced by calling `validate_listings(result)` at the portal boundary, which routes through [`ensure_type()`](/R/ensure_type.R) (a `vctrs::vec_cast()` wrapper). A parser that produces the wrong type aborts that portal's fetch; the umbrella `immor_fetch()` catches the abort and continues with the other portals. See [`type-enforcement`](/openspec/specs/type-enforcement/spec.md).

### Portal boundary
The line where an `immor_portal_<name>` method returns to the umbrella `immor_fetch()`. Type checking, empty short-circuits, and error reporting all sit at this boundary — not deeper, not shallower. See [design.md § "Fail fast at the portal boundary"](design.md#2-fail-fast-fail-early-fail-clear--at-the-portal-boundary).

### Umbrella orchestration
The public entry point [`immor_fetch(query, portals, deduplicate, max_pages)`](/R/fetch-all.R). It dispatches to each registered portal via the `fetch_listings` S3 generic, catches per-portal errors, aggregates rows via `dplyr::bind_rows()`, and optionally deduplicates. See [`multi-portal-fetch`](/openspec/specs/multi-portal-fetch/spec.md).

### Deduplication key
The composite key `paste(address_zip, address_street, rooms, price, sep = "|")` used by [`immor_deduplicate()`](/R/deduplicate.R) to detect cross-portal duplicates under `method = "exact"`. Rows sharing a key are collapsed to one, keeping the first-by-alphabetical-portal (so a flatfox listing beats a weckaeby duplicate). See [`deduplication`](/openspec/specs/deduplication/spec.md).

### Two-portal rule
The extension rule for the schema: adding a column requires at least two portals to fill it with real data. Prevents the schema from bloating with portal-specific columns that would be perpetually `NA` on all but one portal. Discussed in [roadmap.md § New columns](roadmap.md).

---

## S3 dispatch (R OOP recap)

immor uses R's original S3 object system, not S4 or R6.

### S3 generic
A function that dispatches to a method based on the class of its first argument. immor defines two generics in [`/R/portal.R`](/R/portal.R):

```r
fetch_listings <- function(portal, query, max_pages = 5L, ...) {
  UseMethod("fetch_listings")
}
parse_listing <- function(portal, raw_listing) {
  UseMethod("parse_listing")
}
```

### S3 method
A function of the form `<generic>.<class>()` that R picks up automatically when the generic is called with an object of that class. For example, `fetch_listings.immor_portal_flatfox(portal, ...)` is called when `portal` has class `"immor_portal_flatfox"`.

### Default method
The catch-all `<generic>.default()` (or `<generic>.<base-class>()`) that runs when no more-specific method matches. immor's `fetch_listings.immor_portal` and `parse_listing.immor_portal` defaults `cli::cli_abort()` with an instructive message pointing at the missing subclass method — a partial portal implementation is caught immediately.

### Class hierarchy
The `class()` vector of an immor portal is subclass-first, base-class-second: `c("immor_portal_flatfox", "immor_portal")`. R's S3 dispatch tries `fetch_listings.immor_portal_flatfox` first; if absent, falls back to `fetch_listings.immor_portal` (which aborts).

---

## Real-estate domain

### Transaction type
Whether a listing is offered for rent or for sale. Normalised in immor to the string `"rent"` or `"buy"` in the `transaction_type` column. Different portals label this differently at the wire level:

- flatfox: `offer_type` is `"RENT"` / `"BUY"` (upper case).
- weck-aeby: the offer is inferred from the archive URL — `/louer/` is rent, `/acheter/` is buy.

### Property type
The kind of unit being offered. Normalised to `"apartment"`, `"house"`, `"room"`, `"parking"`, `"commercial"`, or `"other"`. Flatfox exposes `object_category`; weck-aeby currently leaves this as `NA` because the CasaWP labels do not map cleanly to the schema's enum.

### Half-rooms (Swiss convention)
Swiss real-estate listings quote rooms as fractional values — a `3.5-Zimmer-Wohnung` is a three-and-a-half-room apartment. The half-room is a smaller side room (dining area, extra study, not a full bedroom). `rooms` in the schema is `numeric` precisely so `3.5` fits without coercion. Anglophone portals often round to integers; the Swiss convention preserves the half.

### Cold rent vs. warm rent
"Cold" rent (Kaltmiete / loyer net) excludes utilities and heating; "warm" rent (Warmmiete / loyer brut) includes them. Listings sometimes label prices `Nettomiete` (net) or `Bruttomiete` (gross); the difference matters for comparison across portals. The schema's `price` column does not distinguish — it stores whatever the portal advertises, with `price_unit` capturing periodicity (`"monthly"` / `"weekly"` / `"total"`).

### Reference / referral ID
The portal-internal unique identifier for a listing. Stored in `portal_id` (character, not integer — leading-zero-safe). Same listing on two portals has different `portal_id` values.

### Address canton
The two-letter or three-letter Swiss cantonal code (`LU`, `ZH`, `VD`, …). Not currently populated by any of the two working portals — both leave it `NA`. Would populate if we added a geocoding step (see [roadmap.md](roadmap.md)).

### Price sentinel: "sur demande" / "auf Anfrage" / "on request"
A common wire-level marker meaning "we won't tell you the price without contact". immor normalises this to `NA_real_` in [`weckaeby_parse_price()`](/R/portal-weckaeby.R). A parsed price of exactly `0` is also normalised to `NA` — a listing at CHF 0 is definitionally a data-entry error.

---

## Portal-specific vocabulary

### CasaWP
A WordPress plugin sold by [Casasoft AG](https://casasoft.ch) for Swiss real-estate websites. Renders listings server-side into a semi-standardised HTML structure with `.title`, `div.details`, and Google Maps address links. `weck-aeby.ch` uses CasaWP; the parser [`parse_listing.immor_portal_weckaeby()`](/R/portal-weckaeby.R) knows this HTML shape. Roughly 200+ Swiss agencies use CasaWP — adding one more CasaWP site should mostly involve subclassing the weckaeby parser rather than writing from scratch. See [roadmap.md § Portal queue](roadmap.md).

### `pk` (primary key, in weck-aeby URLs)
The query-string parameter that identifies a CasaWP listing (`?pk=1234&ret=louer`). Used by [`weckaeby_extract_pk()`](/R/portal-weckaeby.R) to deduplicate archive links (the same listing can appear multiple times on `/acheter/` or `/louer/` with different slug URLs but the same `pk`). Stored as `portal_id` for weckaeby listings.

### `ret` (return, in weck-aeby URLs)
The query-string parameter indicating which archive page a detail URL came from (`ret=louer` = rent archive, `ret=acheter` = buy archive). Not used by immor — the transaction type is inferred from which archive was fetched, not from `ret`.

### Archive page (weckaeby)
The list-view URL like `/acheter/` or `/louer/` that contains anchor tags to individual `/objet/…` detail pages. [`fetch_listings.immor_portal_weckaeby()`](/R/portal-weckaeby.R) fetches both archives first, then descends into each unique detail URL.

### Detail page (weckaeby)
The single-listing URL like `/objet/{slug}/?pk={id}&ret={type}` whose HTML the CasaWP parser extracts.

### `object_category` (flatfox)
Flatfox's wire-level property-type code. Values: `"APARTMENT"`, `"HOUSE"`, `"ROOM"`, `"PARKING"`, `"COMMERCIAL"`, plus other codes that map to `"other"`. Normalised by [`flatfox_parse_property_type()`](/R/portal-flatfox.R).

### `offer_type` (flatfox)
Flatfox's wire-level transaction-type code. Values: `"RENT"`, `"BUY"`. Normalised by [`flatfox_parse_offer_type()`](/R/portal-flatfox.R). Unknown or missing values default to `"rent"`.

### `moving_date` (flatfox)
Flatfox's field name for the earliest possible move-in date. An ISO date string or `NULL`. Parsed by the shared [`parse_date()`](/R/portal-flatfox.R) helper into `available_from` (`Date` or `NA`).

### `zipcode` (flatfox)
Flatfox's field for postal code. Returned as an **integer**, which the parser must cast to `character` before storing in `address_zip` (Swiss postal codes are four digits, occasionally with leading zeros in edge regions).

---

## HTTP & scraping

### `httr2`
The modern R HTTP client (successor to `httr`). immor uses it throughout — every request begins as `httr2::request(url)`, is decorated by [`immor_request()`](/R/http.R), and is executed by `httr2::req_perform()`. See [`http-layer`](/openspec/specs/http-layer/spec.md).

### `rvest`
An R HTML-scraping library built on `xml2`. Used by [`portal_weckaeby()`](/R/portal-weckaeby.R) to extract elements from the CasaWP-rendered HTML via CSS selectors (`rvest::html_element(".title")`, `rvest::html_elements("a[href*='/objet/']")`, etc.).

### `robots.txt`
The plain-text file at a domain's root (e.g. `https://flatfox.ch/robots.txt`) that declares which paths automated agents may crawl and at what rate. immor's policy: we only add portals whose `robots.txt` allows the endpoints we need, and we honour any crawl-delay directive by increasing [`immor_request(delay = …)`](/R/http.R). See [design.md § Security & compliance posture](design.md#security--compliance-posture).

### Crawl delay
The minimum wait between requests to the same host, expressed in seconds. immor's default is `2` seconds; weck-aeby's `robots.txt` mandates `10`, honoured by `immor_request(delay = 10)` inside [`portal_weckaeby()`](/R/portal-weckaeby.R). Per-portal delays may only increase the default, never decrease it.

### Rate throttle
The `httr2::req_throttle(rate = 1 / delay)` decorator that enforces the crawl-delay client-side. immor applies it to every request via [`immor_request()`](/R/http.R).

### Retry with backoff
The `httr2::req_retry(max_tries = 3, backoff = \(x) x * 2)` decorator that retries a failed request up to two additional times, waiting 2× the previous delay each time. Handles transient DNS blips, 5xx bursts, and slow-network hiccups without user code needing to loop.

### User-Agent
The HTTP header identifying the client. immor sends `"immor/{utils::packageVersion(\"immor\")} (R package)"` — no browser masquerading, so blocked portals block us the same way they block any identified bot. This is deliberate; masquerading would violate the "scraping only where allowed" posture.

### DataDome
A commercial bot-detection service used by SMG-group portals (homegate, immoscout24) and Comparis. Returns HTTP 403 to any request lacking a real browser's JavaScript fingerprint. Not defeatable with `httr2` alone; would require Playwright or Selenium — see [roadmap.md § Rejected](roadmap.md#explicitly-rejected).

### Cloudflare (challenge)
Cloudflare's Bot Management product, either the classic "checking your browser" JavaScript challenge or Turnstile. Used by newhome.ch. Same class of block as DataDome from immor's perspective — not defeatable with the current stack.

### Azure Front Door
Microsoft's CDN + WAF product. Blocks properstar.ch scraping. Same category as the above.

### HSTS (HTTP Strict Transport Security)
A response header that instructs browsers to always use HTTPS for a domain. Not directly relevant to scraping (we already use HTTPS), but a positive TLS signal — noted for `flatfox.ch` in the [portal landscape](design.md#security--compliance-posture).

---

## Data types

### `tibble`
The `tibble::tibble()` class from the tidyverse — a modernised `data.frame` with saner printing and stricter subsetting. The return type of every immor function that emits rows.

### `zero-row tibble`
A tibble with the correct column names and types but no data rows. Returned by [`immor_schema()`](/R/schema.R) and by portal `fetch_listings` methods when a scrape produces no listings. Downstream code can `dplyr::bind_rows()` a zero-row tibble with any-row tibbles of the same schema without error.

### list column
A column of a tibble whose entries are R lists rather than atomic values. Used for `images` (each row's cell is a character vector of image URLs / IDs). Preserves the natural one-listing-many-images structure without joining a side table.

### `POSIXct`
R's date-time class. `scraped_at` in the schema — the wall-clock timestamp when the row was parsed. Timezone is the system's; not converted to UTC.

### `Date`
R's date-only class (no time-of-day). `available_from` in the schema. Portals sometimes return date strings in local formats (`%d.%m.%Y` for weck-aeby); the parser converts to `Date` and stores `NA` for unparseable / missing input.

### `vctrs::vec_cast()`
The `vctrs` package's central type-casting function. Given a value and a prototype (e.g. `character()`), it either coerces safely or errors. immor wraps it in [`ensure_type()`](/R/ensure_type.R) with a `cli`-flavoured error chain.

### Prototype (in vctrs)
A zero-length instance of a type that stands in for the type itself. `character()` is the character prototype, `integer()` the integer, `as.Date(character())` the Date prototype, `Sys.time()[0]` the POSIXct prototype. `ensure_type(df, x = integer(), y = logical())` uses prototypes as the target types.

### `NA` (typed)
R's missing value comes in typed flavours: `NA_character_`, `NA_integer_`, `NA_real_`. Portal parsers emit the correctly typed `NA` for each column so that `validate_listings()` does not have to coerce. Using bare `NA` (which is logical) in a numeric column will trigger a `vec_cast` warning at portal boundary.

---

## Package tooling

### `roxygen2`
The R documentation generator. Comments prefixed with `#'` above a function become `man/*.Rd` files (and the `NAMESPACE` exports list) via `devtools::document()`. immor uses `Roxygen: list(markdown = TRUE, ...)` in [`/DESCRIPTION`](/DESCRIPTION) to write docs in Markdown.

### `roxyglobals`
A roxygen extension that manages the top-of-file `utils::globalVariables()` declarations R CMD check demands for non-standard evaluation. Add `#' @autoglobal` to a function's roxygen block; `devtools::document()` writes the declarations into [`/R/globals.R`](/R/globals.R). Never hand-edit `R/globals.R`.

### `air`
[posit-dev/air](https://posit-dev.github.io/air/) — a fast R code formatter (think `rustfmt` for R). Config at [`/air.toml`](/air.toml). Run `air format .` before committing.

### `devtools`
The R package-development toolkit. `devtools::document()`, `devtools::test()`, `devtools::check()`, `devtools::build_readme()`. See [`/.github/CONTRIBUTING.md`](/.github/CONTRIBUTING.md#running-checks).

### `pkgdown`
Renders package documentation into a static website. Config at [`/_pkgdown.yml`](/_pkgdown.yml). Site is published to `https://layalchristine24.github.io/immor/`. The default output directory `docs/` is gitignored — do not confuse with the source-doc folder `doc/`.

### `fledge`
[cynkra/fledge](https://fledge.cynkra.com) — automates `NEWS.md` maintenance and version bumping. Contributors add bullets to the top of `NEWS.md`; fledge handles grouping into release notes and updating `DESCRIPTION`'s Version at release time.

### `OpenSpec`
The spec-driven change-management tool. Change proposals live under [`/openspec/changes/<slug>/`](/openspec/changes/); the archived contract lives under [`/openspec/specs/<capability>/`](/openspec/specs/). Slash commands `/opsx:propose`, `/opsx:apply`, `/opsx:archive`. See [`/CLAUDE.md § Using OpenSpec`](/CLAUDE.md#using-openspec).

### `blockr.core` / `blockr.immor`
The [blockr](https://github.com/BristolMyersSquibb/blockr.core) framework wraps R functions into interactive Shiny "blocks" for no-code pipelines. `blockr.immor` (companion package) provides source, transform, and plot blocks that call immor functions internally.

---

## Cross-references

Every entry above ultimately points at one of:

- **A capability spec** in [`/openspec/specs/`](/openspec/specs/) — the machine-readable contract.
- **An R file** in [`/R/`](/R/) — the implementation.
- **A sibling doc** — [design.md](design.md), [roadmap.md](roadmap.md).
- **An external resource** — pkgdown / roxygen2 / vctrs / httr2 / rvest / OpenSpec upstream docs.

If a term is missing from this file and you had to reach for the source, open a PR and add it here. Glossary entries are cheap; misunderstandings are expensive.
