#' Create an empty immor listings tibble
#'
#' Returns a zero-row tibble with the canonical immor schema.
#' All portal scrapers must return data conforming to this
#' schema.
#'
#' @return A zero-row tibble with standardized columns.
#'
#' @examples
#' immor_schema()
#' names(immor_schema())
#' @export
immor_schema <- function() {
  tibble::tibble(
    portal = character(),
    portal_id = character(),
    url = character(),
    scraped_at = as.POSIXct(character()),
    transaction_type = character(),
    property_type = character(),
    title = character(),
    description = character(),
    price = numeric(),
    price_unit = character(),
    currency = character(),
    rooms = numeric(),
    area_m2 = numeric(),
    floor = integer(),
    address_street = character(),
    address_zip = character(),
    address_city = character(),
    address_canton = character(),
    latitude = numeric(),
    longitude = numeric(),
    images = list(),
    available_from = as.Date(character()),
    year_built = integer(),
    has_balcony = logical(),
    has_parking = logical(),
    has_elevator = logical(),
    is_furnished = logical(),
    energy_label = character(),
  )
}

validate_listings <- function(listings) {
  ensure_type(
    listings,
    portal = character(),
    portal_id = character(),
    url = character(),
    scraped_at = Sys.time()[0],
    transaction_type = character(),
    property_type = character(),
    title = character(),
    description = character(),
    price = numeric(),
    price_unit = character(),
    currency = character(),
    rooms = numeric(),
    area_m2 = numeric(),
    floor = integer(),
    address_street = character(),
    address_zip = character(),
    address_city = character(),
    address_canton = character(),
    latitude = numeric(),
    longitude = numeric(),
    images = list(),
    available_from = as.Date(character()),
    year_built = integer(),
    has_balcony = logical(),
    has_parking = logical(),
    has_elevator = logical(),
    is_furnished = logical(),
    energy_label = character(),
  )
}
