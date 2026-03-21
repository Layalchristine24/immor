#' Remove duplicate listings across portals
#'
#' Identifies and removes listings that appear on multiple
#' portals based on matching address, price, and rooms.
#'
#' @param listings A tibble of listings from one or more
#'   portals, conforming to [immor_schema()].
#' @param method Deduplication method. Currently only
#'   `"exact"` is supported.
#'
#' @return A deduplicated tibble. When duplicates are found,
#'   the first occurrence (by portal name) is kept.
#'
#' @examples
#' listings <- immor_schema()
#' immor_deduplicate(listings)
#' @export
immor_deduplicate <- function(
  listings,
  method = c("exact")
) {
  method <- arg_match(method)

  if (nrow(listings) == 0) return(listings)

  dedup_key <- paste(
    listings$address_zip %||% "",
    listings$address_street %||% "",
    listings$rooms %||% "",
    listings$price %||% "",
    sep = "|"
  )

  listings$dedup_key_ <- dedup_key
  result <- listings |>
    dplyr::arrange(.data$portal) |>
    dplyr::filter(!duplicated(.data$dedup_key_))

  n_removed <- nrow(listings) - nrow(result)
  if (n_removed > 0) {
    cli::cli_inform(
      "Removed {n_removed} duplicate listing{?s}."
    )
  }

  result$dedup_key_ <- NULL
  result
}
