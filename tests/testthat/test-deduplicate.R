test_that("immor_deduplicate() removes exact duplicates", {
  listings <- dplyr::bind_rows(
    tibble::tibble(
      portal = "flatfox",
      portal_id = "1",
      url = "https://flatfox.ch/1",
      scraped_at = Sys.time(),
      transaction_type = "rent",
      property_type = "apartment",
      title = "Nice apartment",
      description = NA_character_,
      price = 1500,
      price_unit = "monthly",
      currency = "CHF",
      rooms = 3.5,
      area_m2 = 80,
      floor = 2L,
      address_street = "Bahnhofstrasse 10",
      address_zip = "8001",
      address_city = "Zurich",
      address_canton = "ZH",
      latitude = 47.37,
      longitude = 8.54,
      images = list(character()),
      available_from = as.Date(NA),
      year_built = NA_integer_,
      has_balcony = TRUE,
      has_parking = FALSE,
      has_elevator = TRUE,
      is_furnished = FALSE,
      energy_label = NA_character_
    ),
    tibble::tibble(
      portal = "homegate",
      portal_id = "2",
      url = "https://homegate.ch/2",
      scraped_at = Sys.time(),
      transaction_type = "rent",
      property_type = "apartment",
      title = "Schone Wohnung",
      description = NA_character_,
      price = 1500,
      price_unit = "monthly",
      currency = "CHF",
      rooms = 3.5,
      area_m2 = 80,
      floor = 2L,
      address_street = "Bahnhofstrasse 10",
      address_zip = "8001",
      address_city = "Zurich",
      address_canton = "ZH",
      latitude = 47.37,
      longitude = 8.54,
      images = list(character()),
      available_from = as.Date(NA),
      year_built = NA_integer_,
      has_balcony = TRUE,
      has_parking = FALSE,
      has_elevator = TRUE,
      is_furnished = FALSE,
      energy_label = NA_character_
    )
  )

  result <- immor_deduplicate(listings)
  expect_equal(nrow(result), 1L)
  expect_equal(result$portal, "flatfox")
})

test_that("immor_deduplicate() keeps unique listings", {
  listings <- dplyr::bind_rows(
    tibble::tibble(
      portal = "flatfox",
      portal_id = "1",
      url = "https://flatfox.ch/1",
      scraped_at = Sys.time(),
      transaction_type = "rent",
      property_type = "apartment",
      title = "Apartment A",
      description = NA_character_,
      price = 1500,
      price_unit = "monthly",
      currency = "CHF",
      rooms = 3.5,
      area_m2 = 80,
      floor = 2L,
      address_street = "Bahnhofstrasse 10",
      address_zip = "8001",
      address_city = "Zurich",
      address_canton = "ZH",
      latitude = 47.37,
      longitude = 8.54,
      images = list(character()),
      available_from = as.Date(NA),
      year_built = NA_integer_,
      has_balcony = NA,
      has_parking = NA,
      has_elevator = NA,
      is_furnished = NA,
      energy_label = NA_character_
    ),
    tibble::tibble(
      portal = "homegate",
      portal_id = "2",
      url = "https://homegate.ch/2",
      scraped_at = Sys.time(),
      transaction_type = "rent",
      property_type = "apartment",
      title = "Apartment B",
      description = NA_character_,
      price = 2000,
      price_unit = "monthly",
      currency = "CHF",
      rooms = 4,
      area_m2 = 100,
      floor = 1L,
      address_street = "Kramgasse 5",
      address_zip = "3011",
      address_city = "Bern",
      address_canton = "BE",
      latitude = 46.95,
      longitude = 7.45,
      images = list(character()),
      available_from = as.Date(NA),
      year_built = NA_integer_,
      has_balcony = NA,
      has_parking = NA,
      has_elevator = NA,
      is_furnished = NA,
      energy_label = NA_character_
    )
  )

  result <- immor_deduplicate(listings)
  expect_equal(nrow(result), 2L)
})

test_that("immor_deduplicate() handles empty tibble", {
  result <- immor_deduplicate(immor_schema())
  expect_equal(nrow(result), 0L)
})
