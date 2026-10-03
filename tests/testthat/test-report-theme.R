test_that("reportTheme returns a ggplot2 theme", {
  skip_if_not_installed("ggplot2")
  expect_s3_class(reportTheme(), "theme")
})
