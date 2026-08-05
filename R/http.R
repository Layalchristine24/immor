#' Decorate an httr2 request with the package's shared policies
#'
#' Every outbound HTTP request made by an immor portal SHALL be piped
#' through `immor_request()` so that user-agent, per-host throttling,
#' retry policy, and (optionally) on-disk response caching apply
#' uniformly. Portals never call `httr2::req_user_agent()`,
#' `httr2::req_throttle()`, `httr2::req_retry()`, or
#' `httr2::req_cache()` directly.
#'
#' @param req An [httr2::request()] object.
#' @param delay Per-host delay in seconds enforced via
#'   [httr2::req_throttle()]. The default of `2` matches the
#'   package-wide floor; callers MAY only increase it (weck-aeby passes
#'   `10`).
#' @param cache Logical. When `TRUE`, an [httr2::req_cache()] decorator
#'   is applied before throttle and retry so cache hits skip both the
#'   throttle wait and the network. Defaults to `FALSE`; portal fetch
#'   methods pass through their own `cache` argument.
#' @param max_age TTL in seconds forwarded to [httr2::req_cache()].
#'   Ignored when `cache = FALSE`. Defaults to `Inf` (never expires from
#'   TTL alone; evictable via [immor_cache_clear()] or manual delete).
#'
#' @return A decorated [httr2::request()] ready for
#'   [httr2::req_perform()].
#'
#' @details
#' The `IMMOR_NO_CACHE` environment variable is a global kill switch.
#' Any truthy value (`"1"`, `"true"`, `"yes"`, case-insensitive) forces
#' the cache decorator off regardless of the `cache` argument. A
#' `cli::cli_inform()` fires exactly once per session on the first
#' overridden call so the user understands why cache flags appear
#' ineffective.
#'
#' On filesystem errors (permission denied, disk full, corrupt cache
#' entry) the cache decorator is dropped and the request falls through
#' to a live network call, with a one-off `cli::cli_warn()`. The package
#' fails open on the cache layer — correctness beats speed.
#'
#' @seealso [immor_cache_dir()], [immor_cache_clear()],
#'   [httr2::req_cache()].
#'
#' @examples
#' \dontrun{
#' httr2::request("https://flatfox.ch/api/v1/public-listing/") |>
#'   immor_request(cache = TRUE, max_age = 3600) |>
#'   httr2::req_perform()
#' }
#' @keywords internal
immor_request <- function(req, delay = 2, cache = FALSE, max_age = Inf) {
  pkg_version <- utils::packageVersion("immor")
  ua <- glue::glue("immor/{pkg_version} (R package)")

  if (isTRUE(cache) && immor_cache_disabled()) {
    immor_cache_inform_once(
      "kill_switch",
      c(
        "!" = "HTTP cache disabled by {.envvar IMMOR_NO_CACHE}.",
        "i" = "Unset the variable to re-enable caching."
      )
    )
    cache <- FALSE
  }

  if (isTRUE(cache)) {
    req <- tryCatch(
      httr2::req_cache(req, path = immor_cache_dir(), max_age = max_age),
      error = function(e) {
        immor_cache_inform_once(
          "fs_error",
          c(
            "!" = "HTTP cache unavailable ({conditionMessage(e)}).",
            "i" = "Falling back to uncached requests for this session."
          )
        )
        req
      }
    )
  }

  req |>
    httr2::req_user_agent(ua) |>
    httr2::req_throttle(rate = 1 / delay) |>
    httr2::req_retry(max_tries = 3, backoff = \(x) x * 2)
}
