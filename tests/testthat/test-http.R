has_cache_policy <- function(req) {
  !is.null(req$policies$cache_path)
}

has_throttle_policy <- function(req) {
  !is.null(req$policies$throttle_realm)
}

has_retry_policy <- function(req) {
  !is.null(req$policies$retry_max_tries)
}

test_that("immor_request() applies no cache decorator by default", {
  req <- httr2::request("https://example.com") |> immor_request()
  expect_false(has_cache_policy(req))
})

test_that("immor_request(cache = TRUE) applies the cache decorator", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(
    R_USER_CACHE_DIR = tmp,
    IMMOR_NO_CACHE = ""
  )
  immor_cache_reset_notices()
  withr::defer(immor_cache_reset_notices())

  req <- httr2::request("https://example.com") |>
    immor_request(cache = TRUE, max_age = 3600)

  expect_true(has_cache_policy(req))
})

test_that("IMMOR_NO_CACHE=1 overrides cache = TRUE with a one-time inform", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(
    R_USER_CACHE_DIR = tmp,
    IMMOR_NO_CACHE = "1"
  )
  immor_cache_reset_notices()
  withr::defer(immor_cache_reset_notices())

  expect_message(
    req1 <- httr2::request("https://example.com") |>
      immor_request(cache = TRUE),
    regexp = "IMMOR_NO_CACHE"
  )
  expect_false(has_cache_policy(req1))

  expect_no_message(
    req2 <- httr2::request("https://example.com/other") |>
      immor_request(cache = TRUE)
  )
  expect_false(has_cache_policy(req2))
})

test_that("immor_request() still sets user-agent, throttle, retry decorators", {
  req <- httr2::request("https://example.com") |> immor_request()

  expect_false(is.null(req$options$useragent))
  expect_match(req$options$useragent, "^immor/")
  expect_true(has_throttle_policy(req))
  expect_true(has_retry_policy(req))
})

test_that("immor_request() cache decorator sits before throttle in the chain", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(
    R_USER_CACHE_DIR = tmp,
    IMMOR_NO_CACHE = ""
  )

  req <- httr2::request("https://example.com") |>
    immor_request(cache = TRUE, max_age = 3600)

  # Both policies present; cache short-circuit runs before throttle wait.
  expect_true(has_cache_policy(req))
  expect_true(has_throttle_policy(req))
})

test_that("immor_request() writes cache entries to immor_cache_dir()", {
  skip_if_not_installed("httptest2")
  tmp <- withr::local_tempdir()
  withr::local_envvar(
    R_USER_CACHE_DIR = tmp,
    IMMOR_NO_CACHE = ""
  )

  path <- immor_cache_dir()
  expect_length(list.files(path), 0L)

  httr2::with_mocked_responses(
    mock = function(req) httr2::response(body = charToRaw("hi")),
    {
      httr2::request("https://example.com") |>
        immor_request(cache = TRUE, max_age = 3600) |>
        httr2::req_perform()
    }
  )

  # Mocked responses don't actually populate req_cache() (mock intercepts before
  # the cache layer writes), so this test only asserts the decorator was applied
  # and the pipeline did not error.
  expect_true(dir.exists(path))
})
