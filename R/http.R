immor_request <- function(req, delay = 2) {
  pkg_version <- utils::packageVersion("immor")
  ua <- glue::glue("immor/{pkg_version} (R package)")

  req |>
    httr2::req_user_agent(ua) |>
    httr2::req_throttle(rate = 1 / delay) |>
    httr2::req_retry(max_tries = 3, backoff = \(x) x * 2)
}
