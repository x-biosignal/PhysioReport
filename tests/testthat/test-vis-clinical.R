test_that("plotBlandAltman h-line intercepts equal the blandAltman statistics", {
  skip_if_not_installed("ggplot2")
  x <- c(1, 2, 3, 4, 5)
  y <- c(1.1, 1.9, 3.2, 3.8, 5.1)
  ba <- PhysioCore::blandAltman(x, y)

  p <- plotBlandAltman(x, y)
  expect_s3_class(p, "ggplot")

  hlines <- Filter(function(l) inherits(l$geom, "GeomHline"), p$layers)
  yints <- sort(unname(vapply(hlines, function(l) l$data$yintercept, numeric(1))))
  expect_equal(
    yints,
    sort(unname(c(ba$bias, ba$lower_loa, ba$upper_loa))),
    tolerance = 1e-8
  )
})
