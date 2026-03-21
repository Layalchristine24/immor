#' List available portals
#'
#' Returns a named list of all portal constructors
#' registered in immor.
#'
#' @return A named list of portal constructor functions.
#'
#' @examples
#' immor_portals()
#' names(immor_portals())
#' @export
immor_portals <- function() {
  list(
    flatfox = portal_flatfox
  )
}

#' Get a configured portal by name
#'
#' @param name Character name of the portal (e.g.,
#'   `"flatfox"`).
#'
#' @return An `immor_portal` object.
#'
#' @examples
#' immor_portal("flatfox")
#' @export
immor_portal <- function(name) {
  portals <- immor_portals()

  if (!name %in% names(portals)) {
    cli::cli_abort(c(
      "Unknown portal {.val {name}}.",
      "i" = "Available portals: {.val {names(portals)}}."
    ))
  }

  portals[[name]]()
}
