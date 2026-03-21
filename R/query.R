#' Build a search query for immor
#'
#' Constructs a query object used to search across Swiss
#' real estate portals.
#'
#' @return An S3 object of class `immor_query`.
#'
#' @examples
#' immor_query()
#' @export
immor_query <- function() {
  out <- list()
  class(out) <- "immor_query"
  out
}

#' @export
print.immor_query <- function(x, ...) {
  cli::cli_h3("immor query")
  cli::cli_inform("Fetches all available listings from registered portals.")
  invisible(x)
}
