# Package-local state for once-per-session notices.
cache_state <- new.env(parent = emptyenv())

#' On-disk cache directory
#'
#' Returns the directory used by [immor_fetch()] to store its DuckDB
#' cache when `cache = TRUE`. The path follows the R user-directory
#' convention via [tools::R_user_dir()]. The directory is created
#' lazily on first call if it does not already exist.
#'
#' The location depends on the operating system:
#' - macOS: `~/Library/Caches/org.R-project.R/R/immor/`
#' - Linux: `$XDG_CACHE_HOME/R/immor/` or `~/.cache/R/immor/`
#' - Windows: `%LOCALAPPDATA%/R/cache/R/immor/`
#'
#' The DuckDB file lives inside this directory at
#' [immor_cache_db_path()]. Users may safely delete the directory at
#' any time; use [immor_cache_clear()] for the programmatic equivalent.
#'
#' @return A length-1 character vector — the absolute path to the cache
#'   directory.
#'
#' @seealso [immor_cache_clear()] to purge the cache;
#'   [immor_cache_db_path()] for the DuckDB file location;
#'   [immor_fetch()] for the caller.
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

#' Path to the DuckDB cache file
#'
#' @return A length-1 character vector — the absolute path to the
#'   `.duckdb` file that stores cached listings. The file is created
#'   the first time [immor_fetch()] writes a cache entry.
#'
#' @seealso [immor_cache_dir()], [immor_cache_clear()].
#'
#' @examples
#' immor_cache_db_path()
#' @export
immor_cache_db_path <- function() {
  file.path(immor_cache_dir(), "immor.duckdb")
}

#' Purge the on-disk cache
#'
#' Deletes the DuckDB file so subsequent [immor_fetch()] calls scrape
#' fresh data. Safe to call when no cache has been written yet.
#'
#' @return The path to the removed DuckDB file, invisibly.
#'
#' @seealso [immor_cache_dir()], [immor_cache_db_path()].
#'
#' @examples
#' \dontrun{
#' immor_cache_clear()
#' }
#' @export
immor_cache_clear <- function() {
  db_path <- immor_cache_db_path()
  wal_path <- paste0(db_path, ".wal")

  removed <- character()
  for (p in c(db_path, wal_path)) {
    if (file.exists(p)) {
      unlink(p, force = TRUE)
      removed <- c(removed, p)
    }
  }

  if (length(removed) == 0) {
    cli::cli_alert_info("Cache is already empty: {.path {db_path}}.")
  } else {
    cli::cli_alert_success(
      "Removed cache file{?s}: {.path {removed}}."
    )
  }
  invisible(db_path)
}

# Truth table for the IMMOR_NO_CACHE kill switch. Case-insensitive.
immor_cache_disabled <- function() {
  val <- Sys.getenv("IMMOR_NO_CACHE", unset = "")
  tolower(val) %in% c("1", "true", "yes")
}

# Emit `cli::cli_inform()` at most once per session for a given `key`.
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

# Compute a stable cache key from the fetch call's shape. Query is
# passed as an S3 object; hashing it directly is fine because it's
# constructed by `immor_query()` (currently no-arg — but future
# arguments become part of the key automatically).
immor_cache_key <- function(portals, max_pages, query) {
  rlang::hash(list(
    portals = sort(portals),
    max_pages = as.integer(max_pages),
    query = unclass(query)
  ))
}

# Open a connection to the DuckDB cache. Read-only when possible so
# concurrent read sessions don't collide; caller is responsible for
# disconnecting.
immor_cache_connect <- function(read_only = FALSE) {
  dbConnect(
    duckdb(),
    dbdir = immor_cache_db_path(),
    read_only = read_only
  )
}

# Look up a cached fetch result. Returns a tibble stripped of cache
# metadata, or NULL on miss / stale / error.
immor_cache_read <- function(key, max_age) {
  db_path <- immor_cache_db_path()
  if (!file.exists(db_path)) {
    return(NULL)
  }

  con <- tryCatch(
    immor_cache_connect(read_only = TRUE),
    error = function(e) NULL
  )
  if (is.null(con)) {
    return(NULL)
  }
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  if (!dbExistsTable(con, "immor_listings")) {
    return(NULL)
  }

  meta <- tryCatch(
    dbGetQuery(
      con,
      paste(
        "SELECT DISTINCT cache_key, cached_at",
        "FROM immor_listings",
        "WHERE cache_key = ?",
        "ORDER BY cached_at DESC",
        "LIMIT 1"
      ),
      params = list(key)
    ),
    error = function(e) NULL
  )
  if (is.null(meta) || nrow(meta) == 0) {
    return(NULL)
  }

  age <- as.numeric(difftime(Sys.time(), meta$cached_at[[1]], units = "secs"))
  if (is.finite(max_age) && age > max_age) {
    return(NULL)
  }

  rows <- tryCatch(
    dbGetQuery(
      con,
      paste(
        "SELECT * EXCLUDE (cache_key, cached_at)",
        "FROM immor_listings",
        "WHERE cache_key = ? AND cached_at = ?"
      ),
      params = list(key, meta$cached_at[[1]])
    ),
    error = function(e) NULL
  )
  if (is.null(rows) || nrow(rows) == 0) {
    return(NULL)
  }

  cli::cli_alert_info(
    "Cache hit: {nrow(rows)} listing{?s} (cached {round(age)}s ago)."
  )
  tibble::as_tibble(rows)
}

# Persist a fetch result. Silent no-op on failure (fail-open).
immor_cache_write <- function(key, listings) {
  if (nrow(listings) == 0) {
    return(invisible())
  }
  con <- tryCatch(
    immor_cache_connect(read_only = FALSE),
    error = function(e) {
      immor_cache_inform_once(
        "fs_error",
        c(
          "!" = "Cache unavailable ({conditionMessage(e)}).",
          "i" = "Continuing without cache write."
        )
      )
      NULL
    }
  )
  if (is.null(con)) {
    return(invisible())
  }
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  augmented <- dplyr::mutate(
    listings,
    cache_key = key,
    cached_at = Sys.time(),
    .before = 1
  )

  tryCatch(
    dbWriteTable(
      con,
      "immor_listings",
      augmented,
      append = dbExistsTable(con, "immor_listings")
    ),
    error = function(e) {
      immor_cache_inform_once(
        "fs_error",
        c(
          "!" = "Cache write failed ({conditionMessage(e)}).",
          "i" = "Continuing without cache."
        )
      )
    }
  )
  invisible()
}
