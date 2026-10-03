ab_series <- function() list(value = c(2, 3, 2, 3, 6, 7, 8, 7),
                             phase = rep(c("A", "B"), each = 4))

test_that("plotSCED returns a ggplot with phase vlines and a 2SD band", {
  skip_if_not_installed("ggplot2")
  d <- ab_series()
  p <- plotSCED(d$value, d$phase)
  expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true(any(geoms == "GeomVline"))     # phase-change boundary
  expect_true(any(geoms == "GeomRibbon"))    # baseline 2SD band
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plotSCED overlays are individually selectable", {
  skip_if_not_installed("ggplot2")
  d <- ab_series()
  p_mean <- plotSCED(d$value, d$phase, overlays = "mean")
  g <- vapply(p_mean$layers, function(l) class(l$geom)[1], character(1))
  expect_true(any(g == "GeomSegment"))       # per-phase mean lines
  expect_false(any(g == "GeomRibbon"))       # 2SD band suppressed
  # celeration-only and an ABAB design both build
  expect_s3_class(plotSCED(d$value, d$phase, overlays = "celeration"), "ggplot")
  expect_s3_class(
    plotSCED(1:8, rep(c("A", "B", "A", "B"), each = 2)), "ggplot")
})

test_that("plotSCED validates its inputs", {
  expect_error(plotSCED(1:3, c("A", "B")), "same length")
  expect_error(plotSCED(c(1, 2), c("A", "A")), "two phases")
  expect_error(plotSCED(1, "A"), "two observations")
})

test_that("scedStats reproduces the peer-reviewed estimators (perfect separation)", {
  skip_if_not_installed("PhysioClinStats")
  d <- ab_series()
  st <- scedStats(d$value, d$phase)
  expect_s3_class(st, "sced_stats")
  expect_equal(st$estimate[st$metric == "PND"], 100, tolerance = 1e-9)
  expect_equal(st$estimate[st$metric == "NAP"], 1, tolerance = 1e-9)
  tau <- st$estimate[st$metric == "Tau-U"]
  expect_true(tau >= -1 && tau <= 1)
  # single-sourced: matches a direct PhysioClinStats call
  expect_equal(
    st$estimate[st$metric == "NAP"],
    as.numeric(PhysioClinStats::scedNAP(c(2, 3, 2, 3), c(6, 7, 8, 7))@estimate),
    tolerance = 1e-9)
  expect_output(print(st), "sced_stats")
})

test_that("scedStats keeps Tau-U bounded in [-1, 1] under a counter-trend baseline", {
  skip_if_not_installed("PhysioClinStats")
  # a declining baseline running counter to an increasing intervention makes the
  # unbounded 'parker' Tau-U exceed 1; scedStats uses the bounded 'scan' tau-b
  st <- scedStats(c(8, 5, 3, 2, 9, 10, 11, 12), rep(c("A", "B"), each = 4))
  tau <- st$estimate[st$metric == "Tau-U"]
  expect_true(tau >= -1 && tau <= 1)
})

test_that("plotSCED shades each contiguous block of a reversal (ABAB) design", {
  skip_if_not_installed("ggplot2")
  p <- plotSCED(1:8, rep(c("A", "B", "A", "B"), each = 2))
  b <- ggplot2::ggplot_build(p)
  # the per-block shading rects are the finite-width rects
  rects <- do.call(rbind, lapply(b$data, function(d) {
    if (!all(c("xmin", "xmax") %in% names(d))) return(NULL)
    d[is.finite(d$xmin) & is.finite(d$xmax) & (d$xmax - d$xmin) < 10,
      c("xmin", "xmax")]
  }))
  rects <- unique(rects)
  expect_equal(nrow(rects), 4L)                       # 4 blocks, not 2 levels
  rects <- rects[order(rects$xmin), ]
  expect_false(any(rects$xmin[-1] < rects$xmax[-nrow(rects)]))  # no overlap
})

test_that("scedStats handles decrease-is-good metrics", {
  skip_if_not_installed("PhysioClinStats")
  # lower is better: baseline high, intervention low -> perfect nonoverlap
  st <- scedStats(c(8, 7, 8, 7, 2, 3, 2, 1), rep(c("A", "B"), each = 4),
                  improvement = "decrease")
  expect_equal(st$estimate[st$metric == "PND"], 100, tolerance = 1e-9)
  expect_equal(st$estimate[st$metric == "NAP"], 1, tolerance = 1e-9)
})
