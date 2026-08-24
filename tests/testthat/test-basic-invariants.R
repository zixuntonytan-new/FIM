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
