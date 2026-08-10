#' Construct a data.table row-by-row
#'
#' A row-wise table constructor in the spirit of `tibble::tribble()`. The
#' leading formula arguments (e.g. `~a, ~b`) name the columns; the remaining
#' arguments are filled in row by row. Adapted from `mlr3misc::rowwise_table()`.
#'
#' @param ... Column names as one-sided formulas, followed by the cell values
#'   in row-major order.
#' @param .key Optional character vector of key columns passed to
#'   [data.table::setkeyv()].
#'
#' @return A [data.table::data.table()].
#' @examples
#' rowwise_table(
#'   ~a, ~b,
#'   1,  "x",
#'   2,  "y"
#' )
#' @export
rowwise_table <- function(..., .key = NULL) {
  dots <- list(...)

  ncol <- 0L
  for (i in seq_along(dots)) {
    if (!inherits(dots[[i]], "formula")) {
      ncol <- i - 1L
      break
    }
  }
  if (ncol == 0L) {
    stop("No column names provided")
  }

  n <- length(dots) - ncol
  if (n %% ncol != 0L) {
    stop("Data is not rectangular")
  }

  tab <- lapply(seq_len(ncol), function(i) {
    simplify2array(dots[seq(from = ncol + i, to = length(dots), by = ncol)])
  })
  nms <- vapply(
    dots[seq_len(ncol)],
    function(x) attr(stats::terms(x), "term.labels"),
    character(1)
  )
  tab <- data.table::setnames(data.table::setDT(tab), nms)
  if (!is.null(.key)) {
    data.table::setkeyv(tab, .key)
  }
  tab
}
