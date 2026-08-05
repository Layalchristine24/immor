#' Fetch listings from multiple portals
#'
#' Searches across one or more Swiss real estate portals
#' and returns a unified tibble of listings.
#'
#' Results are cached in an on-disk DuckDB database at
#' [immor_cache_db_path()]. Repeat calls with the same
#' `(portals, max_pages, query)` shape within `max_age` seconds return
#' the cached listings without hitting the network.
#'
#' @param query An [immor_query()] object specifying search
#'   criteria.
#' @param portals Character vector of portal names, or
#'   `NULL` to search all available portals.
#' @param deduplicate Whether to remove duplicate listings
#'   across portals.
#' @param max_pages Maximum number of result pages to fetch
#'   per portal.
#' @param cache Whether to consult and populate the on-disk cache.
#'   Defaults to `TRUE`. The `IMMOR_NO_CACHE` environment variable
#'   (values `"1"`, `"true"`, `"yes"`, case-insensitive) overrides this
#'   argument globally.
#' @param max_age Maximum cache-entry age in seconds before it is
#'   considered stale and re-fetched. Defaults to `3600` (one hour).
#'   Set `max_age = Inf` to accept any cached entry regardless of age;
#'   `max_age = 0` forces a re-fetch while still writing the new result
#'   into the cache.
#'
#' @return A tibble conforming to [immor_schema()].
#'
#' @examples
#' \dontrun{
#' query <- immor_query()
#' listings <- immor_fetch(query)
#' # Fresh fetch, no cache:
#' listings <- immor_fetch(query, cache = FALSE)
#' # Accept any cached entry regardless of age:
#' listings <- immor_fetch(query, max_age = Inf)
#' }
#' @export
immor_fetch <- function(
  query,
  portals = NULL,
  deduplicate = TRUE,
  max_pages = 5L,
  cache = TRUE,
  max_age = 3600
) {
  available <- immor_portals()

  if (is.null(portals)) {
    portal_names <- names(available)
  } else {
    unknown <- setdiff(portals, names(available))
    if (length(unknown) > 0) {
      cli::cli_abort(c(
        "Unknown portal{?s}: {.val {unknown}}.",
        "i" = "Available: {.val {names(available)}}."
      ))
    }
    portal_names <- portals
  }

  cache_enabled <- isTRUE(cache) && !immor_cache_disabled()
  if (isTRUE(cache) && immor_cache_disabled()) {
    immor_cache_inform_once(
      "kill_switch",
      c(
        "!" = "Cache disabled by {.envvar IMMOR_NO_CACHE}.",
        "i" = "Unset the variable to re-enable caching."
      )
    )
  }

  key <- immor_cache_key(portal_names, max_pages, query)

  if (cache_enabled) {
    hit <- immor_cache_read(key, max_age = max_age)
    if (!is.null(hit)) {
      return(hit)
    }
  }

  cli::cli_inform(
    "Fetching from {length(portal_names)} portal{?s}: {.val {portal_names}}."
  )

  all_results <- purrr::map(portal_names, function(name) {
    portal <- available[[name]]()
    cli::cli_progress_step("Scraping {.val {name}}")
    tryCatch(
      fetch_listings(portal, query, max_pages = max_pages),
      error = function(e) {
        cli::cli_warn(
          "Failed to fetch from {.val {name}}: {conditionMessage(e)}"
        )
        immor_schema()
      }
    )
  })

  result <- dplyr::bind_rows(all_results)

  cli::cli_inform("Found {nrow(result)} listing{?s} total.")

  if (deduplicate && nrow(result) > 0) {
    result <- immor_deduplicate(result)
  }

  if (cache_enabled) {
    immor_cache_write(key, result)
  }

  result
}
