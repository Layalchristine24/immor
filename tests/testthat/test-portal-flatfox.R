test_that("portal_flatfox() creates valid portal", {
  p <- portal_flatfox()
  expect_s3_class(p, "immor_portal_flatfox")
  expect_s3_class(p, "immor_portal")
  expect_equal(p$name, "flatfox")
})

test_that("parse_listing.immor_portal_flatfox() normalizes data", {
  portal <- portal_flatfox()
  raw <- mock_flatfox_listing()
  result <- parse_listing(portal, raw)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)
  expect_equal(result$portal, "flatfox")
  expect_equal(result$portal_id, "12345")
  expect_equal(result$transaction_type, "rent")
  expect_equal(result$property_type, "apartment")
  expect_equal(result$price, 1500)
  expect_equal(result$rooms, 3.5)
  expect_equal(result$area_m2, 85)
  expect_equal(result$address_zip, "8001")
  expect_equal(result$address_city, "Zurich")
  expect_true(is.na(result$has_balcony))
  expect_true(is.na(result$has_parking))
})

test_that("parse_listing.immor_portal_flatfox() handles missing fields", {
  portal <- portal_flatfox()
  raw <- list(pk = 1, offer_type = "RENT")
  result <- parse_listing(portal, raw)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)
  expect_equal(result$portal, "flatfox")
  expect_true(is.na(result$title))
  expect_true(is.na(result$price))
})
