test_that("immor_cache_dir() returns a length-1 path and creates it lazily", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  path <- immor_cache_dir()

  expect_type(path, "character")
  expect_length(path, 1L)
  expect_true(dir.exists(path))
  expect_true(
    startsWith(path, normalizePath(tmp, winslash = "/")) ||
      startsWith(path, tmp)
  )
})

test_that("immor_cache_clear() removes contents but keeps the directory", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  path <- immor_cache_dir()
  writeLines("payload", file.path(path, "entry-1"))
  writeLines("payload", file.path(path, "entry-2"))
  expect_length(list.files(path), 2L)

  expect_message(immor_cache_clear(), regexp = "Removed 2 entries")
  expect_true(dir.exists(path))
  expect_length(list.files(path), 0L)
})

test_that("immor_cache_clear() no-ops on empty directory", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)
  immor_cache_dir()

  expect_message(immor_cache_clear(), regexp = "already empty")
})

test_that("immor_cache_clear() no-ops when directory does not exist", {
  tmp <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = tmp)

  expect_message(immor_cache_clear(), regexp = "does not exist yet")
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
