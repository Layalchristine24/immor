has_throttle_policy <- function(req) {
  !is.null(req$policies$throttle_realm)
}

has_retry_policy <- function(req) {
  !is.null(req$policies$retry_max_tries)
}

test_that("immor_request() sets user-agent, throttle, and retry decorators", {
  req <- httr2::request("https://example.com") |> immor_request()

  expect_false(is.null(req$options$useragent))
  expect_match(req$options$useragent, "^immor/")
  expect_true(has_throttle_policy(req))
  expect_true(has_retry_policy(req))
})

test_that("immor_request(delay = 10) throttles per weck-aeby's mandate", {
  req <- httr2::request("https://example.com") |> immor_request(delay = 10)
  expect_true(has_throttle_policy(req))
})

test_that("immor_request() does not layer httr2::req_cache()", {
  # Caching lives at the immor_fetch() umbrella level, not on the request.
  req <- httr2::request("https://example.com") |> immor_request()
  expect_null(req$policies$cache_path)
})
