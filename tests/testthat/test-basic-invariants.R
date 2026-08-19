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

test_that("annual_to_quarter creates four unique quarters for each annual input", {
  skip_if_not_installed("tsibble")
  library(tsibble)

  annual <- tsibble::as_tsibble(
    data.frame(year = c(2020, 2021), value = c(10, 20)),
    index = year
  )
  result <- annual_to_quarter(annual)

  expect_equal(nrow(result), 8)
  expect_equal(result$value, rep(c(10, 20), each = 4))
  expect_false(anyDuplicated(result$date))
  expect_equal(table(format(result$date, "%Y")), c("2020" = 4, "2021" = 4))
})
