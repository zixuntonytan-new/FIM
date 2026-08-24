test_that("millions_to_billions changes only designated fiscal columns", {
  values <- data.frame(
    gftfbusx = 2500,
    gfeghhx = 1000,
    untouched = 7
  )

  result <- millions_to_billions(values)

  expect_equal(result$gftfbusx, 2.5)
  expect_equal(result$gfeghhx, 1)
  expect_equal(result$untouched, 7)
})

test_that("annual_to_quarter maps fiscal annual values to dated quarters", {
  skip_if_not_installed("tsibble")

  annual <- tsibble::as_tsibble(
    data.frame(year = c(2020, 2021), value = c(10, 20)),
    index = year
  )
  result <- annual_to_quarter(annual, year)

  expect_equal(nrow(result), 8)
  expect_equal(result$value, rep(c(10, 20), each = 4))
  expect_identical(anyDuplicated(result$date), 0L)
  expect_equal(
    result$date,
    as.Date(c(
      "2019-12-31", "2020-03-31", "2020-06-30", "2020-09-30",
      "2020-12-31", "2021-03-31", "2021-06-30", "2021-09-30"
    ))
  )
})

test_that("fy_annual_to_quarter expands each fiscal annual row four times", {
  skip_if_not_installed("tsibble")

  annual <- tsibble::as_tsibble(
    data.frame(fy = c(2020, 2021), value = c(10, 20)),
    index = fy
  )
  result <- fy_annual_to_quarter(annual)

  expect_equal(nrow(result), 8)
  expect_equal(result$value, rep(c(10, 20), each = 4))
  expect_identical(anyDuplicated(result$date), 0L)
  expect_equal(
    as.Date(result$date),
    as.Date(c(
      "2020-01-01", "2020-04-01", "2020-07-01", "2020-10-01",
      "2021-01-01", "2021-04-01", "2021-07-01", "2021-10-01"
    ))
  )
})

test_that("CBO preparation calls the fiscal-year expansion helper", {
  lines <- readLines(file.path("data-raw", "projections.R"))
  active_lines <- lines[!grepl("^\\s*#", lines)]

  expect_equal(sum(grepl("\\bfy_annual_to_quarter\\(", active_lines)), 2L)
  expect_false(any(grepl("(?<!fy_)annual_to_quarter\\(", active_lines, perl = TRUE)))
})
