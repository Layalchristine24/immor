# Package-local state for once-per-session notices.
cache_state <- new.env(parent = emptyenv())

#' On-disk HTTP cache directory
#'
#' Returns the directory used by [immor_request()] when caching is opted
#' in. The path follows the R user-directory convention via
#' [tools::R_user_dir()]. The directory is created lazily on first call
#' if it does not already exist.
#'
#' The location depends on the operating system:
#' - macOS: `~/Library/Caches/org.R-project.R/R/immor/`
#' - Linux: `$XDG_CACHE_HOME/R/immor/` or `~/.cache/R/immor/`
#' - Windows: `%LOCALAPPDATA%/R/cache/R/immor/`
#'
#' Users may safely delete the directory at any time; use
#' [immor_cache_clear()] for the programmatic equivalent.
#'
#' @return A length-1 character vector — the absolute path to the cache
#'   directory.
#'
#' @seealso [immor_cache_clear()] to purge the cache; [immor_fetch()] and
#'   [immor_request()] for the callers that write to it.
#'
#' @examples
#' immor_cache_dir()
#' @export
immor_cache_dir <- function() {
  path <- R_user_dir("immor", "cache")
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  path
}

#' Purge the on-disk HTTP cache
#'
#' Deletes every entry inside [immor_cache_dir()] without removing the
#' directory itself. Safe to call when no cache has been written yet.
#'
#' @return The path to the cache directory, invisibly.
#'
#' @seealso [immor_cache_dir()] for the directory path.
#'
#' @examples
#' \dontrun{
#' immor_cache_clear()
#' }
#' @export
immor_cache_clear <- function() {
  path <- R_user_dir("immor", "cache")
  if (!dir.exists(path)) {
    cli::cli_alert_info("Cache directory does not exist yet: {.path {path}}.")
    return(invisible(path))
  }
  entries <- list.files(path, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  if (length(entries) == 0) {
    cli::cli_alert_info("Cache is already empty: {.path {path}}.")
    return(invisible(path))
  }
  unlink(entries, recursive = TRUE, force = TRUE)
  cli::cli_alert_success(
    "Removed {length(entries)} entr{?y/ies} from {.path {path}}."
  )
  invisible(path)
}

# Truth table for the IMMOR_NO_CACHE kill switch. Case-insensitive.
immor_cache_disabled <- function() {
  val <- Sys.getenv("IMMOR_NO_CACHE", unset = "")
  tolower(val) %in% c("1", "true", "yes")
}

# Emit `cli::cli_inform()` at most once per session for a given `key`.
# `key` distinguishes reasons (e.g. "kill_switch", "fs_error").
immor_cache_inform_once <- function(key, message) {
  seen <- cache_state$informed %||% character()
  if (key %in% seen) {
    return(invisible())
  }
  cache_state$informed <- c(seen, key)
  cli::cli_inform(message)
  invisible()
}

# Reset the once-per-session flags. Test-only helper (not exported).
immor_cache_reset_notices <- function() {
  cache_state$informed <- character()
  invisible()
}
