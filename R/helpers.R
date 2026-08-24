#' Title
#'
#' @param df 
#'
#' @return
#' @export
#'
#' @examples
format_tsibble <- function(df){
  df %>%
    mutate(date = tsibble::yearquarter(date)) %>%
    relocate(id, .before = date) %>%
    tsibble::as_tsibble(key = id, index = date)
}

fiscal_to_calendar <- function(df){
  index <-
    df %>%
    index_var()  
  index <- rlang::ensym(index)
  df %>%
    mutate("{{index}}" := {{index}} - 1)
    
}  

monthly_to_quarterly <- function(df){
  df %>%
    mutate(yq = tsibble::yearquarter(date)) %>%
    as_tsibble(index = date) %>%
    select(date, yq, everything()) %>%
    index_by(yq) %>%
    mutate(
      across(
        .cols = where(is.numeric), 
        .fns = ~ mean(.x, na.rm = TRUE)
      )
    ) %>%
    filter(row_number()== n()) %>%
    ungroup() %>%
    select(-yq)
}
