test_that("plotOutcomeRadar is a coord_polar radar with one vertex per domain", {
  skip_if_not_installed("ggplot2")
  prof <- c(pain = 3, balance = 7, gait = 6, strength = 5)
  p <- plotOutcomeRadar(prof)
  expect_s3_class(p, "ggplot")
  expect_s3_class(p$coordinates, "CoordPolar")
  # one radar vertex per domain
  expect_equal(nrow(p$data), length(prof))
  expect_equal(as.character(levels(p$data$domain)), names(prof))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("a reference polygon is drawn only when a reference is supplied", {
  skip_if_not_installed("ggplot2")
  prof <- c(pain = 3, balance = 7, gait = 6, strength = 5)
  ref <- c(pain = 5, balance = 8, gait = 8, strength = 8)

  p_no <- plotOutcomeRadar(prof)
  g_no <- vapply(p_no$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(g_no == "GeomPolygon"), 1L)          # just the profile

  p_ref <- plotOutcomeRadar(prof, reference = ref, normalize = "percent")
  g_ref <- vapply(p_ref$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(g_ref == "GeomPolygon"), 2L)         # reference + profile
  # percent scaling: value / reference * 100
  expect_equal(p_ref$data$value,
               unname(prof / ref * 100)[match(as.character(p_ref$data$domain),
                                              names(prof))],
               tolerance = 1e-9)
})

test_that("z-normalization centers the radar on the normative reference", {
  skip_if_not_installed("ggplot2")
  prof <- c(pain = 3, balance = 7, gait = 6, strength = 5)
  refdf <- data.frame(domain = names(prof), mean = c(5, 8, 8, 8),
                      sd = c(1, 2, 1, 1))
  p <- plotOutcomeRadar(prof, reference = refdf, normalize = "z")
  # z = (value - mean) / sd, domain-aligned
  idx <- match(as.character(p$data$domain), names(prof))
  expect_equal(p$data$value,
               unname(((prof - c(5, 8, 8, 8)) / c(1, 2, 1, 1))[idx]),
               tolerance = 1e-9)
  # the reference polygon is centered at z = 0
  ref_layer <- p$layers[[1]]
  expect_true(all(ref_layer$data$value == 0))
  expect_equal(p$labels$y, physioLabel("z_score"))
})

test_that("plotOutcomeRadar validates inputs and z-reference requirements", {
  prof <- c(pain = 3, balance = 7, gait = 6, strength = 5)
  expect_error(plotOutcomeRadar(c(a = 1, b = 2)), "at least 3")
  expect_error(plotOutcomeRadar(c(1, 2, 3)), "named")
  expect_error(plotOutcomeRadar(prof, domains = c("pain", "nope")), "missing")
  # z-normalization needs an sd (a named-numeric reference has none)
  expect_error(plotOutcomeRadar(prof, reference = prof, normalize = "z"),
               "sd")
  expect_error(plotOutcomeRadar(prof, normalize = "z"), "requires a 'reference'")
})

test_that("multi-timepoint overlay and the MSK adapter build", {
  skip_if_not_installed("ggplot2")
  m <- rbind(t0 = c(pain = 3, balance = 5, gait = 4, strength = 4),
             t1 = c(pain = 6, balance = 7, gait = 7, strength = 6))
  p <- plotOutcomeRadar(m)
  expect_equal(length(levels(p$data$series)), 2L)       # two overlaid polygons
  expect_silent(ggplot2::ggplot_build(p))

  # a MSKFunctionalOutcome is adapted to ROM/Strength/Function domains
  mock <- structure(
    list(aggregate = list(overall_rom = 80, overall_strength = 65,
                          overall_function = 72)),
    class = "MSKFunctionalOutcome")
  pm <- plotOutcomeRadar(mock)
  expect_equal(as.character(levels(pm$data$domain)),
               c("ROM", "Strength", "Function"))
  expect_silent(ggplot2::ggplot_build(pm))
})
