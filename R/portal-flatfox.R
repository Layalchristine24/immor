#' Create a flatfox portal
#'
#' Constructs a portal object for
#' [flatfox.ch](https://flatfox.ch), which provides a
#' public REST API.
#'
#' @return An `immor_portal` object for flatfox.
#'
#' @examples
#' portal_flatfox()
#' @export
portal_flatfox <- function() {
  new_portal(
    name = "flatfox",
    base_url = "https://flatfox.ch",
    api_url = "https://flatfox.ch/api/v1/public-listing/"
  )
}

#' @export
fetch_listings.immor_portal_flatfox <- function(
  portal,
  query,
  max_pages = 5L,
  cache = TRUE,
  ...
) {
  all_listings <- list()
  offset <- 0L
  limit <- 30L

  for (page in seq_len(max_pages)) {
    req <- httr2::request(portal$api_url) |>
      httr2::req_url_query(
        ordering = "-published",
        offset = offset,
        limit = limit,
      ) |>
      immor_request(cache = cache, max_age = 3600)

    resp <- httr2::req_perform(req)
    body <- httr2::resp_body_json(resp)
    results <- body$results %||% list()

    if (length(results) == 0) {
      break
    }

    parsed <- purrr::map(results, \(x) parse_listing(portal, x))
    all_listings <- c(all_listings, parsed)

    if (is.null(body$`next`)) {
      break
    }
    offset <- offset + limit
  }

  result <- dplyr::bind_rows(all_listings)

  if (nrow(result) == 0) {
    return(immor_schema())
  }

  validate_listings(result)
}

#' @export
parse_listing.immor_portal_flatfox <- function(portal, raw_listing) {
  base_url <- portal$base_url
  tibble::tibble(
    portal = "flatfox",
    portal_id = as.character(raw_listing$pk %||% NA),
    url = paste0(base_url, raw_listing$url %||% ""),
    scraped_at = Sys.time(),
    transaction_type = flatfox_parse_offer_type(
      raw_listing$offer_type
    ),
    property_type = flatfox_parse_property_type(
      raw_listing$object_category
    ),
    title = raw_listing$public_title %||%
      raw_listing$short_title %||%
      NA_character_,
    description = raw_listing$description %||% NA_character_,
    price = as.numeric(raw_listing$price_display %||% NA),
    price_unit = "monthly",
    currency = "CHF",
    rooms = as.numeric(raw_listing$number_of_rooms %||% NA),
    area_m2 = as.numeric(raw_listing$surface_living %||% NA),
    floor = as.integer(raw_listing$floor %||% NA),
    address_street = raw_listing$street %||% NA_character_,
    address_zip = as.character(raw_listing$zipcode %||% NA),
    address_city = raw_listing$city %||% NA_character_,
    address_canton = NA_character_,
    latitude = as.numeric(raw_listing$latitude %||% NA),
    longitude = as.numeric(raw_listing$longitude %||% NA),
    images = list(
      as.character(raw_listing$images %||% integer())
    ),
    available_from = parse_date(
      raw_listing$moving_date
    ),
    year_built = as.integer(raw_listing$year_built %||% NA),
    has_balcony = NA,
    has_parking = NA,
    has_elevator = NA,
    is_furnished = raw_listing$is_furnished %||% NA,
    energy_label = NA_character_,
  )
}

flatfox_parse_offer_type <- function(offer_type) {
  switch(offer_type %||% "RENT", RENT = "rent", BUY = "buy", "rent")
}

flatfox_parse_property_type <- function(category) {
  switch(
    category %||% "APARTMENT",
    APARTMENT = "apartment",
    HOUSE = "house",
    ROOM = "room",
    PARKING = "parking",
    COMMERCIAL = "commercial",
    "other"
  )
}

parse_date <- function(date_str) {
  if (is.null(date_str) || is.na(date_str)) {
    return(as.Date(NA))
  }
  tryCatch(as.Date(date_str), error = \(e) as.Date(NA))
}
