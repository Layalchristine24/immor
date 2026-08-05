#' Decorate an httr2 request with the package's shared policies
#'
#' Every outbound HTTP request made by an immor portal SHALL be piped
#' through `immor_request()` so that user-agent, per-host throttling,
#' and retry-with-backoff apply uniformly. Portals never call
#' `httr2::req_user_agent()`, `httr2::req_throttle()`, or
#' `httr2::req_retry()` directly.
#'
#' Response caching lives at the [immor_fetch()] umbrella level, not
#' here — see [immor_cache_dir()].
#'
#' @param req An [httr2::request()] object.
#' @param delay Per-host delay in seconds enforced via
#'   [httr2::req_throttle()]. Defaults to `2`; callers MAY only
#'   increase it (weck-aeby passes `10`).
#'
#' @return A decorated [httr2::request()] ready for
#'   [httr2::req_perform()].
#'
#' @seealso [httr2::req_user_agent()], [httr2::req_throttle()],
#'   [httr2::req_retry()], [immor_cache_dir()].
#'
#' @examples
#' \dontrun{
#' httr2::request("https://flatfox.ch/api/v1/public-listing/") |>
#'   immor_request() |>
#'   httr2::req_perform()
#' }
#' @keywords internal
immor_request <- function(req, delay = 2) {
  pkg_version <- utils::packageVersion("immor")
  ua <- glue::glue("immor/{pkg_version} (R package)")

  req |>
    httr2::req_user_agent(ua) |>
    httr2::req_throttle(rate = 1 / delay) |>
    httr2::req_retry(max_tries = 3, backoff = \(x) x * 2)
}
