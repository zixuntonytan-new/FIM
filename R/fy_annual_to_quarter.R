#' Expand fiscal-year annual data to quarterly observations
#'
#' @param df A tsibble indexed by an annual fiscal-year variable.
#'
#' @return A quarterly tsibble with each annual row repeated for four quarters.
#' @export
fy_annual_to_quarter <- function(df) {
  year <-
    df %>%
    tsibble::index_var()
  min <-
    df %>%
    select(rlang::enexpr(year)) %>%
    min()

  max <-
    df %>%
    select(rlang::enexpr(year)) %>%
    max()
  start <- tsibble::yearquarter(glue::glue('{min} Q1'), fiscal_start = 1)
  end <- tsibble::yearquarter(glue::glue('{max} Q4'), fiscal_start = 1)
  x <- seq(start, end, by = 1)

  df %>%
    as_tibble() %>%
    slice(rep(1:n(), each = 4)) %>%
    mutate(date = tsibble::yearquarter(x)) %>%
    relocate(date, .before = everything()) %>%
    tsibble::as_tsibble(index = date)
}
