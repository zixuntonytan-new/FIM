# data_import.R
#
# This module contains functions that import all data used in the FIM. 
# It includes chunk names  that
# are used in the technical walkthrough in docs/technical_documentation. Thus,
# it's essential to be careful when editing chunk names to avoid causing an error
# in docs/technical_documentation/index.Rmd

# This section is meant to import the required data series line-by-line. Eventually,
# all data imports will be done here.

# CBO projections
import_projections <- function() { # to load to memory, run load("data/projections.rda")
  x <- fim::projections 
  return(x)
}

# BEA National Accounts
import_national_accounts <- function() { # to load to memory, run load("data/national_accounts.rda")
  x <- fim::national_accounts
  return(x)
}

# Forecast spreadsheet
import_forecast <- function(forecast_path = 'data/forecast.xlsx') {
  readxl::read_xlsx(forecast_path, sheet = 'forecast') %>%
    select(-name) %>%
    pivot_longer(-variable, names_to = 'date') %>%
    pivot_wider(names_from = 'variable', values_from = 'value') %>%
    mutate(date = yearquarter(date)) %>%
    as_tsibble(index = date)
}

# Historical overrides
import_historical_overrides <- function(forecast_path = 'data/forecast.xlsx') {
  readxl::read_xlsx(forecast_path, sheet = 'historical overrides') %>%
    select(-name) %>%
    pivot_longer(-variable, names_to = 'date') %>%
    pivot_wider(names_from = 'variable', values_from = 'value') %>%
    mutate(date = yearquarter(date))
}

# Deflator overrides
import_deflator_overrides <- function(forecast_path = 'data/forecast.xlsx') {
  readxl::read_xlsx(forecast_path,
                    sheet = 'deflators_override') %>% # Read in overrides for deflators
    select(-name) %>% # Remove longer name since we don't need it
    pivot_longer(-variable,
                 names_to = 'date') %>% # Reshape so that variables are columns and dates are rows
    pivot_wider(names_from = 'variable',
                values_from = 'value') %>% 
    mutate(date = yearquarter(date))
}

# Policy adjustment from the Uncertainty worksheet
import_uncertainty_component <- function(
    forecast_path = 'data/forecast.xlsx',
    component_name
) {
  uncertainty_sheet <- readxl::read_xlsx(
    forecast_path,
    sheet = 'Uncertainty',
    col_names = FALSE
  )

  component_row <- which(uncertainty_sheet[[2]] == component_name)
  if (length(component_row) != 1) {
    stop(glue::glue(
      "Expected exactly one '{component_name}' row in the Uncertainty sheet of {forecast_path}."
    ))
  }

  # The worksheet stores years, quarters, and policy paths in rows 6, 7, and
  # the named component row, respectively. Columns A:C are labels/spacers.
  component_data <- tibble(
    year = unlist(uncertainty_sheet[6, -(1:3)], use.names = FALSE),
    quarter = unlist(uncertainty_sheet[7, -(1:3)], use.names = FALSE),
    data_series = suppressWarnings(as.numeric(unlist(
      uncertainty_sheet[component_row, -(1:3)],
      use.names = FALSE
    )))
  ) %>%
    fill(year) %>%
    filter(!is.na(quarter)) %>%
    mutate(date = yearquarter(paste(year, quarter))) %>%
    select(date, data_series)

  component_data %>%
    coalesce_join(create_placeholder_nas(start = '1970-01-01'), by = 'date') %>%
    arrange(date) %>%
    mutate(across(everything(), ~ replace_na(., 0)))
}

## Create a data frame of appropriate length populated by NAs
create_placeholder_nas <- function(col_name = "data_series",
                                   start = "2022-10-01",
                                   end = "2034-07-01") {
  dates <- yearquarter(seq(ymd(start), ymd(end), by = "quarter"))
  tsibble(date = dates, !!sym(col_name) := NA, index = date)
}
