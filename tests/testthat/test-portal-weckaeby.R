test_that("portal_weckaeby() creates valid portal", {
  p <- portal_weckaeby()
  expect_s3_class(p, "immor_portal_weckaeby")
  expect_s3_class(p, "immor_portal")
  expect_equal(p$name, "weckaeby")
  expect_equal(p$base_url, "https://www.weck-aeby.ch")
})

test_that("parse_listing parses buy listing", {
  portal <- portal_weckaeby()
  raw <- list(
    html = rvest::read_html(test_path("fixtures/weckaeby-detail-buy.html")),
    transaction_type = "buy",
    url = "https://www.weck-aeby.ch/objet/test/?pk=1729204&ret=acheter"
  )
  result <- parse_listing(portal, raw)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1L)
  expect_equal(ncol(result), 28L)
  expect_equal(result$portal, "weckaeby")
  expect_equal(result$portal_id, "1729204")
  expect_equal(result$transaction_type, "buy")
  expect_equal(result$title, "Au calme proche du centre-ville")
  expect_equal(result$price, 990000)
  expect_equal(result$price_unit, "total")
  expect_equal(result$currency, "CHF")
  expect_equal(result$rooms, 7)
  expect_equal(result$address_street, "Route des Noisetiers 14")
  expect_equal(result$address_zip, "1700")
  expect_equal(result$address_city, "Fribourg")
  expect_equal(result$year_built, 1951L)
  expect_identical(result$has_balcony, TRUE)
  expect_identical(result$has_parking, TRUE)
  expect_equal(length(result$images[[1]]), 2L)
  expect_match(result$images[[1]][1], "casagateway")
})

test_that("parse_listing parses rental listing", {
  portal <- portal_weckaeby()
  raw <- list(
    html = rvest::read_html(test_path("fixtures/weckaeby-detail-rent.html")),
    transaction_type = "rent",
    url = "https://www.weck-aeby.ch/objet/test/?pk=85923594&ret=louer"
  )
  result <- parse_listing(portal, raw)

  expect_equal(result$transaction_type, "rent")
  expect_equal(result$price, 1850)
  expect_equal(result$price_unit, "monthly")
  expect_equal(result$rooms, 4.5)
  expect_equal(result$address_street, "Rue du Botzet 3")
  expect_equal(result$available_from, as.Date("2026-08-01"))
  expect_identical(result$has_balcony, TRUE)
  expect_identical(result$has_parking, FALSE)
  expect_equal(length(result$images[[1]]), 2L)
  expect_match(result$images[[1]][1], "flatfox")
})

test_that("parse_listing handles 'Prix sur demande'", {
  portal <- portal_weckaeby()
  raw <- list(
    html = rvest::read_html(test_path("fixtures/weckaeby-detail-no-price.html")),
    transaction_type = "buy",
    url = "https://www.weck-aeby.ch/objet/test/?pk=1651351"
  )
  result <- parse_listing(portal, raw)

  expect_true(is.na(result$price))
  expect_equal(result$title, "L'exception \u00e0 un nom")
  expect_equal(result$address_zip, "1763")
  expect_equal(result$address_city, "Granges-Paccot")
  expect_equal(result$year_built, 2001L)
})

test_that("parse_listing handles CHF 0 rent as NA", {
  portal <- portal_weckaeby()
  raw <- list(
    html = rvest::read_html(test_path("fixtures/weckaeby-detail-rent-zero.html")),
    transaction_type = "rent",
    url = "https://www.weck-aeby.ch/objet/test/?pk=99999&ret=louer"
  )
  result <- parse_listing(portal, raw)

  expect_true(is.na(result$price))
  expect_equal(result$rooms, 1.5)
  expect_equal(result$available_from, as.Date("2026-09-01"))
})

test_that("parse_listing output passes validate_listings", {
  portal <- portal_weckaeby()
  raw <- list(
    html = rvest::read_html(test_path("fixtures/weckaeby-detail-buy.html")),
    transaction_type = "buy",
    url = "https://www.weck-aeby.ch/objet/test/?pk=1729204"
  )
  result <- parse_listing(portal, raw)

  validated <- validate_listings(result)
  expect_s3_class(validated, "tbl_df")
  expect_equal(nrow(validated), 1L)
  expect_equal(ncol(validated), 28L)
})

test_that("weckaeby_parse_price handles edge cases", {
  expect_equal(weckaeby_parse_price("CHF 990'000"), 990000)
  expect_equal(weckaeby_parse_price("CHF 1'340'000.-"), 1340000)
  expect_equal(weckaeby_parse_price("CHF 2'900.-/mois"), 2900)
  expect_true(is.na(weckaeby_parse_price("Prix sur demande")))
  expect_true(is.na(weckaeby_parse_price(NA)))
  expect_true(is.na(weckaeby_parse_price(NULL)))
})

test_that("weckaeby_parse_address handles formats", {
  addr <- weckaeby_parse_address("Route des Noisetiers 14, 1700 Fribourg")
  expect_equal(addr$street, "Route des Noisetiers 14")
  expect_equal(addr$zip, "1700")
  expect_equal(addr$city, "Fribourg")

  addr2 <- weckaeby_parse_address("1763 Granges-Paccot")
  expect_true(is.na(addr2$street))
  expect_equal(addr2$zip, "1763")
  expect_equal(addr2$city, "Granges-Paccot")

  addr3 <- weckaeby_parse_address(NA)
  expect_true(is.na(addr3$street))
  expect_true(is.na(addr3$zip))
  expect_true(is.na(addr3$city))
})

test_that("weckaeby_extract_pk extracts pk from URL", {
  buy_url <- "https://www.weck-aeby.ch/objet/test/?pk=1729204&ret=acheter"
  expect_equal(weckaeby_extract_pk(buy_url), "1729204")

  rent_url <- "https://www.weck-aeby.ch/objet/test/?pk=85923594"
  expect_equal(weckaeby_extract_pk(rent_url), "85923594")

  expect_true(is.na(weckaeby_extract_pk("https://www.weck-aeby.ch/acheter/")))
})
