#' Ensure type stability for data frame columns
#'
#' Casts columns in a data frame to specified types, with
#' error handling and informative error messages.
#'
#' @param .data A data frame whose columns should be cast
#'   to specified types.
#' @param ... Named arguments specifying the desired type
#'   for each column. Values should be prototype objects
#'   (e.g., `character()`, `integer()`, `numeric()`).
#' @param .default Optional default type to apply to columns
#'   not explicitly specified in `...`.
#' @param .call The call environment for error reporting.
#'
#' @return A tibble with columns cast to the specified types.
#'
#' @examples
#' df <- data.frame(
#'   x = 1:3,
#'   y = c(TRUE, FALSE, TRUE)
#' )
#' ensure_type(df, x = integer(), y = logical())
#' @export
#' @autoglobal
ensure_type <- function(
  .data,
  ...,
  .default = NULL,
  .call = rlang::caller_env()
) {
  rlang::try_fetch(
    try_ensure_type(.data, ..., .default = {{ .default }}),
    error = function(e) {
      cli::cli_abort(
        call = .call,
        "Type stability violated",
        parent = e
      )
    }
  )
}

#' @autoglobal
try_ensure_type <- function(
  .data,
  ...,
  .default = NULL,
  .call = rlang::caller_env()
) {
  default <- rlang::enquo(.default)
  types <- tibble::tibble(...)
  names <- names(types)

  if (!rlang::quo_is_null(default)) {
    missing <- setdiff(colnames(.data), names)
    if (length(missing) > 0) {
      default_type <- rlang::eval_tidy(default)
      for (col in missing) {
        types[[col]] <- default_type
      }
      names <- c(names, missing)
    }
  }

  if (!all(names %in% names(.data))) {
    cli::cli_abort(
      call = .call,
      c(
        "Columns missing",
        i = "Columns {.var {setdiff(names, names(.data))}} not found in data"
      )
    )
  }

  out <- .data[names]
  for (i in seq_along(out)) {
    out[[i]] <- vctrs::vec_cast(
      out[[i]],
      types[[i]],
      x_arg = names[[i]],
      call = .call
    )
  }

  out |>
    tibble::as_tibble()
}
