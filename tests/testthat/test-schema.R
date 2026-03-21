test_that("immor_schema() returns a zero-row tibble", {
  schema <- immor_schema()
  expect_s3_class(schema, "tbl_df")
  expect_equal(nrow(schema), 0L)
})

test_that("immor_schema() has all expected columns", {
  schema <- immor_schema()
  expected_cols <- c(
    "portal",
    "portal_id",
    "url",
    "scraped_at",
    "transaction_type",
    "property_type",
    "title",
    "description",
    "price",
    "price_unit",
    "currency",
    "rooms",
    "area_m2",
    "floor",
    "address_street",
    "address_zip",
    "address_city",
    "address_canton",
    "latitude",
    "longitude",
    "images",
    "available_from",
    "year_built",
    "has_balcony",
    "has_parking",
    "has_elevator",
    "is_furnished",
    "energy_label"
  )
  expect_equal(names(schema), expected_cols)
})

test_that("validate_listings() accepts valid tibble", {
  schema <- immor_schema()
  result <- validate_listings(schema)
  expect_s3_class(result, "tbl_df")
  expect_equal(names(result), names(schema))
})

test_that("validate_listings() rejects missing columns", {
  bad <- tibble::tibble(portal = "test")
  expect_snapshot(validate_listings(bad), error = TRUE)
})
