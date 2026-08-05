test_that("immor_fetch() forwards cache = FALSE to every portal method", {
  captured <- list()

  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, cache = TRUE, ...) {
      captured[[portal$name]] <<- list(cache = cache, max_pages = max_pages)
      immor_schema()
    }
  )

  suppressMessages(immor_fetch(immor_query(), cache = FALSE))

  expect_named(captured, c("flatfox", "weckaeby"), ignore.order = TRUE)
  expect_false(captured$flatfox$cache)
  expect_false(captured$weckaeby$cache)
})

test_that("immor_fetch() forwards cache = TRUE by default", {
  captured <- list()

  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, cache = TRUE, ...) {
      captured[[portal$name]] <<- list(cache = cache, max_pages = max_pages)
      immor_schema()
    }
  )

  suppressMessages(immor_fetch(immor_query()))

  expect_true(captured$flatfox$cache)
  expect_true(captured$weckaeby$cache)
})

test_that("immor_fetch() cache-related portal failure is isolated", {
  local_mocked_bindings(
    fetch_listings = function(portal, query, max_pages = 5L, cache = TRUE, ...) {
      if (portal$name == "flatfox") {
        stop("cache directory unwritable")
      }
      immor_schema()
    }
  )

  expect_warning(
    suppressMessages(result <- immor_fetch(immor_query())),
    regexp = "flatfox"
  )
  expect_s3_class(result, "tbl_df")
})
