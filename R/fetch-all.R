#' Fetch listings from multiple portals
#'
#' Searches across one or more Swiss real estate portals
#' and returns a unified tibble of listings.
#'
#' @param query An [immor_query()] object specifying search
#'   criteria.
#' @param portals Character vector of portal names, or
#'   `NULL` to search all available portals.
#' @param deduplicate Whether to remove duplicate listings
#'   across portals.
#' @param max_pages Maximum number of result pages to fetch
#'   per portal.
#' @param cache Whether to use the on-disk HTTP response cache. Defaults
#'   to `TRUE`. Every portal method receives this argument via
#'   [fetch_listings()] dispatch, and passes it through to
#'   [immor_request()]. The `IMMOR_NO_CACHE` environment variable
#'   (values `"1"`, `"true"`, `"yes"`, case-insensitive) overrides this
#'   argument globally. See [immor_cache_dir()] and
#'   [immor_cache_clear()].
#'
#' @return A tibble conforming to [immor_schema()].
#'
#' @examples
#' \dontrun{
#' query <- immor_query()
#' listings <- immor_fetch(query)
#' # Fresh fetch, no cache:
#' listings <- immor_fetch(query, cache = FALSE)
#' }
#' @export
immor_fetch <- function(
  query,
  portals = NULL,
  deduplicate = TRUE,
  max_pages = 5L,
  cache = TRUE
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

  cli::cli_inform(
    "Fetching from {length(portal_names)} portal{?s}: {.val {portal_names}}."
  )

  all_results <- purrr::map(portal_names, function(name) {
    portal <- available[[name]]()
    cli::cli_progress_step("Scraping {.val {name}}")
    tryCatch(
      fetch_listings(portal, query, max_pages = max_pages, cache = cache),
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

  result
}
