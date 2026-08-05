test_that("immor_cache_dir() returns a length-1 path and creates it lazily", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  path <- immor_cache_dir()

  expect_type(path, "character")
  expect_length(path, 1L)
  expect_true(dir.exists(path))
})

test_that("immor_cache_db_path() points inside immor_cache_dir()", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  db <- immor_cache_db_path()
  expect_type(db, "character")
  expect_length(db, 1L)
  expect_true(startsWith(db, immor_cache_dir()))
  expect_match(db, "immor\\.duckdb$")
})

test_that("immor_cache_clear() removes the DuckDB file but keeps the directory", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  db <- immor_cache_db_path()
  writeLines("stub", db)
  expect_true(file.exists(db))

  expect_message(immor_cache_clear(), regexp = "Removed cache")
  expect_false(file.exists(db))
  expect_true(dir.exists(immor_cache_dir()))
})

test_that("immor_cache_clear() no-ops when nothing to remove", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  expect_message(immor_cache_clear(), regexp = "already empty")
})

test_that("immor_cache_disabled() is TRUE for truthy values", {
  for (val in c("1", "true", "TRUE", "yes", "YES", "Yes", "True")) {
    withr::with_envvar(list(IMMOR_NO_CACHE = val), {
      expect_true(immor_cache_disabled(), info = paste("value:", val))
    })
  }
})

test_that("immor_cache_disabled() is FALSE for falsy or unset values", {
  for (val in c("", "0", "false", "FALSE", "no", "NO", "anything else")) {
    withr::with_envvar(list(IMMOR_NO_CACHE = val), {
      expect_false(immor_cache_disabled(), info = paste("value:", val))
    })
  }
  withr::with_envvar(list(IMMOR_NO_CACHE = NA), {
    expect_false(immor_cache_disabled())
  })
})

test_that("immor_cache_inform_once() emits at most once per key per session", {
  immor_cache_reset_notices()
  withr::defer(immor_cache_reset_notices())

  expect_message(
    immor_cache_inform_once("test-key", "hello"),
    regexp = "hello"
  )
  expect_no_message(immor_cache_inform_once("test-key", "hello"))
  expect_message(
    immor_cache_inform_once("other-key", "world"),
    regexp = "world"
  )
})

test_that("immor_cache_key() is stable for equivalent shapes", {
  q <- immor_query()

  k1 <- immor_cache_key(c("flatfox", "weckaeby"), 5L, q)
  k2 <- immor_cache_key(c("weckaeby", "flatfox"), 5L, q)
  expect_identical(k1, k2)

  k3 <- immor_cache_key(c("flatfox", "weckaeby"), 5L, q)
  k4 <- immor_cache_key(c("flatfox", "weckaeby"), 10L, q)
  expect_false(identical(k3, k4))
})

test_that("immor_cache_read() / immor_cache_write() round-trip a fetch result", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  fake <- tibble::tibble(
    portal = "flatfox",
    portal_id = "42",
    url = "https://flatfox.ch/en/flat/42",
    scraped_at = Sys.time(),
    transaction_type = "rent",
    property_type = "apartment",
    title = "Test",
    description = NA_character_,
    price = 1500,
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
    images = list(c("url1", "url2")),
    available_from = as.Date("2026-09-01"),
    year_built = NA_integer_,
    has_balcony = NA,
    has_parking = NA,
    has_elevator = NA,
    is_furnished = NA,
    energy_label = NA_character_
  )

  key <- "test-key"
  expect_null(immor_cache_read(key, max_age = Inf))

  immor_cache_write(key, fake)
  hit <- suppressMessages(immor_cache_read(key, max_age = Inf))
  expect_s3_class(hit, "tbl_df")
  expect_equal(nrow(hit), 1L)
  expect_equal(hit$portal_id, "42")
  expect_equal(hit$images[[1]], c("url1", "url2"))
})

test_that("immor_cache_read() returns NULL when the entry is stale", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  fake <- tibble::tibble(
    portal = "flatfox",
    portal_id = "1",
    url = "u",
    scraped_at = Sys.time(),
    transaction_type = "rent",
    property_type = "apartment",
    title = "t",
    description = NA_character_,
    price = 1,
    price_unit = "monthly",
    currency = "CHF",
    rooms = NA_real_,
    area_m2 = NA_real_,
    floor = NA_integer_,
    address_street = NA_character_,
    address_zip = NA_character_,
    address_city = NA_character_,
    address_canton = NA_character_,
    latitude = NA_real_,
    longitude = NA_real_,
    images = list(character()),
    available_from = as.Date(NA),
    year_built = NA_integer_,
    has_balcony = NA,
    has_parking = NA,
    has_elevator = NA,
    is_furnished = NA,
    energy_label = NA_character_
  )

  key <- "stale-key"
  immor_cache_write(key, fake)
  # max_age = 0 → any entry is stale.
  expect_null(immor_cache_read(key, max_age = 0))
})
