test_that("immor_fetch(cache = FALSE) skips cache lookup and write", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  call_count <- 0L
  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, ...) {
      call_count <<- call_count + 1L
      immor_schema()
    }
  )

  suppressMessages(immor_fetch(immor_query(), cache = FALSE))
  suppressMessages(immor_fetch(immor_query(), cache = FALSE))

  # Two fetches → two round-trips through fetch_listings (no cache).
  expect_gte(call_count, 4L) # 2 portals * 2 calls
  expect_false(file.exists(immor_cache_db_path()))
})

test_that("immor_fetch() caches on first call and returns cached rows on second", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  synthetic_listing <- function(portal_name, id) {
    tibble::tibble(
      portal = portal_name,
      portal_id = as.character(id),
      url = paste0("https://example/", portal_name, "/", id),
      scraped_at = Sys.time(),
      transaction_type = "rent",
      property_type = "apartment",
      title = "Test",
      description = NA_character_,
      price = 1500 + id,
      price_unit = "monthly",
      currency = "CHF",
      rooms = 3.5,
      area_m2 = 85,
      floor = 2L,
      address_street = "Bahnhofstrasse 10",
      address_zip = "8001",
      address_city = "Zurich",
      address_canton = NA_character_,
      latitude = 47.4,
      longitude = 8.5,
      images = list(character()),
      available_from = as.Date(NA),
      year_built = NA_integer_,
      has_balcony = NA,
      has_parking = NA,
      has_elevator = NA,
      is_furnished = NA,
      energy_label = NA_character_
    )
  }

  scrape_count <- 0L
  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, ...) {
      scrape_count <<- scrape_count + 1L
      synthetic_listing(portal$name, scrape_count)
    }
  )

  first <- suppressMessages(immor_fetch(immor_query(), max_age = Inf))
  first_scrape_count <- scrape_count
  expect_s3_class(first, "tbl_df")
  expect_true(file.exists(immor_cache_db_path()))

  second <- suppressMessages(immor_fetch(immor_query(), max_age = Inf))
  # Cache hit → no new fetch_listings dispatches.
  expect_equal(scrape_count, first_scrape_count)
  expect_equal(nrow(second), nrow(first))
})

test_that("immor_fetch() forces re-fetch when max_age = 0", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  scrape_count <- 0L
  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, ...) {
      scrape_count <<- scrape_count + 1L
      immor_schema()
    }
  )

  suppressMessages(immor_fetch(immor_query(), max_age = 0))
  suppressMessages(immor_fetch(immor_query(), max_age = 0))

  # Both calls scrape; the cache read step is bypassed by max_age = 0.
  expect_gte(scrape_count, 4L)
})

test_that("immor_fetch() honours IMMOR_NO_CACHE and informs once", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(
    R_USER_CACHE_DIR = tmp,
    IMMOR_NO_CACHE = "1"
  )
  immor_cache_reset_notices()
  withr::defer(immor_cache_reset_notices())

  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, ...) {
      immor_schema()
    }
  )

  expect_message(
    suppressMessages(
      immor_fetch(immor_query(), cache = TRUE),
      classes = c("cliMessage")
    ),
    regexp = "IMMOR_NO_CACHE"
  )
  expect_false(file.exists(immor_cache_db_path()))
})

test_that("immor_fetch() cache-related portal failure is isolated", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, ...) {
      if (portal$name == "flatfox") {
        stop("simulated portal error")
      }
      immor_schema()
    }
  )

  expect_warning(
    suppressMessages(result <- immor_fetch(immor_query(), cache = FALSE)),
    regexp = "flatfox"
  )
  expect_s3_class(result, "tbl_df")
})
