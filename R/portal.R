#' Create a portal object
#'
#' Constructs an S3 portal object. Each portal represents
#' a Swiss real estate website that can be scraped for
#' listings.
#'
#' @param name Character name of the portal.
#' @param base_url Base URL of the portal.
#' @param ... Additional portal-specific configuration.
#'
#' @return An S3 object of class
#'   `c("immor_portal_{name}", "immor_portal")`.
#'
#' @examples
#' new_portal("example", "https://example.com")
#' @export
new_portal <- function(name, base_url, ...) {
  out <- list(name = name, base_url = base_url, ...)
  class(out) <- c(paste0("immor_portal_", name), "immor_portal")
  out
}

#' Fetch listings from a portal
#'
#' @param portal An `immor_portal` object.
#' @param query An [immor_query()] object.
#' @param max_pages Maximum number of pages to fetch.
#' @param ... Additional arguments passed to methods.
#'
#' @return A tibble conforming to [immor_schema()].
#'
#' @examples
#' \dontrun{
#' portal <- portal_flatfox()
#' query <- immor_query()
#' listings <- fetch_listings(portal, query)
#' }
#' @export
fetch_listings <- function(portal, query, max_pages = 5L, ...) {
  UseMethod("fetch_listings")
}

#' @export
fetch_listings.immor_portal <- function(portal, query, max_pages = 5L, ...) {
  cli::cli_abort(c(
    "No {.fn fetch_listings} method for portal {.val {portal$name}}.",
    "i" = "Implement {.fn fetch_listings.immor_portal_{portal$name}}."
  ))
}

#' Parse a raw listing into normalized schema
#'
#' @param portal An `immor_portal` object.
#' @param raw_listing Raw list from the portal API/HTML.
#'
#' @return A single-row tibble conforming to [immor_schema()].
#'
#' @examples
#' \dontrun{
#' portal <- portal_flatfox()
#' raw <- list(pk = 1, offer_type = "RENT")
#' parse_listing(portal, raw)
#' }
#' @export
parse_listing <- function(portal, raw_listing) {
  UseMethod("parse_listing")
}

#' @export
parse_listing.immor_portal <- function(portal, raw_listing) {
  cli::cli_abort(c(
    "No {.fn parse_listing} method for portal {.val {portal$name}}.",
    "i" = "Implement {.fn parse_listing.immor_portal_{portal$name}}."
  ))
}

#' @export
print.immor_portal <- function(x, ...) {
  cli::cli_h3("immor portal: {x$name}")
  cli::cli_dl(c("Base URL" = x$base_url))
  invisible(x)
}
