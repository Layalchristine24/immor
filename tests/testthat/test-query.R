test_that("immor_query() creates a valid query", {
  q <- immor_query()
  expect_s3_class(q, "immor_query")
})

test_that("print.immor_query() works", {
  q <- immor_query()
  expect_snapshot(print(q))
})
