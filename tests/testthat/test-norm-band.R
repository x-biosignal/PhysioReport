test_that("normativeZScore is exact for a known scalar model", {
  m <- NormativeModel(mean = 1.30, sd = 0.15, source = "demo")
  expect_equal(normativeZScore(1.30 + 2 * 0.15, m), 2, tolerance = 1e-12)
  expect_equal(normativeZScore(1.30, m), 0, tolerance = 1e-12)
  # a scalar model recycles across a vector of observations
  expect_equal(normativeZScore(c(1.0, 1.3, 1.6), m),
               (c(1.0, 1.3, 1.6) - 1.3) / 0.15, tolerance = 1e-12)
})

test_that("waveform (101-pt) model returns per-timepoint z", {
  mu <- sin(seq(0, pi, length.out = 101))
  s <- rep(0.1, 101)
  wf <- NormativeModel(mean = mu, sd = s, time = 0:100)
  expect_equal(wf$kind, "waveform")
  z <- normativeZScore(mu + 2 * s, wf)
  expect_length(z, 101L)
  expect_true(all(abs(z - 2) < 1e-12))
  # length mismatch is an error
  expect_error(normativeZScore(mu[1:50], wf), "must match")
})

test_that("plotNormativeBand has 2 ribbons, 1 observed line, and a z annotation", {
  skip_if_not_installed("ggplot2")
  mu <- sin(seq(0, pi, length.out = 101))
  wf <- NormativeModel(mean = mu, sd = rep(0.1, 101), time = 0:100)
  obs <- mu + 0.1
  p <- expect_silent(plotNormativeBand(obs, wf))
  expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(geoms == "GeomRibbon"), 2L)         # 1SD + 2SD
  expect_equal(sum(geoms == "GeomLine"), 1L)           # single observed line
  expect_true(any(geoms %in% c("GeomLabel", "GeomText")))  # z annotation
  # annotate_z = FALSE drops the annotation layer
  p0 <- plotNormativeBand(obs, wf, annotate_z = FALSE)
  g0 <- vapply(p0$layers, function(l) class(l$geom)[1], character(1))
  expect_false(any(g0 %in% c("GeomLabel", "GeomText")))
  # bands controls the number of ribbon layers
  p1 <- plotNormativeBand(obs, wf, bands = c(1, 2, 3))
  g1 <- vapply(p1$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(g1 == "GeomRibbon"), 3L)
})

test_that("observed = NULL draws a corridor-only band (no observed line)", {
  skip_if_not_installed("ggplot2")
  mu <- sin(seq(0, pi, length.out = 101))
  wf <- NormativeModel(mean = mu, sd = rep(0.1, 101), time = 0:100)
  p <- expect_silent(plotNormativeBand(NULL, wf))
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(geoms == "GeomRibbon"), 2L)
  expect_equal(sum(geoms == "GeomLine"), 0L)                # no observed trace
  expect_false(any(geoms %in% c("GeomLabel", "GeomText")))  # no z annotation
  expect_silent(ggplot2::ggplot_build(p))
  # a scalar model has no x extent without time_axis
  expect_error(plotNormativeBand(NULL, NormativeModel(1.3, 0.15)), "time_axis")
  expect_s3_class(plotNormativeBand(NULL, NormativeModel(1.3, 0.15),
                                    time_axis = 0:100), "ggplot")
})

test_that("scalar corridor broadcasts across a plotted waveform", {
  skip_if_not_installed("ggplot2")
  m <- NormativeModel(mean = 1.30, sd = 0.15)
  p <- plotNormativeBand(rnorm(50, 1.3, 0.15), m)
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(geoms == "GeomRibbon"), 2L)
  expect_equal(sum(geoms == "GeomLine"), 1L)
})

test_that("stratified table model resolves by covariates", {
  tab <- data.frame(
    sex  = rep(c("M", "F"), each = 2),
    age  = rep(c(20, 60), times = 2),
    mean = c(1.4, 1.2, 1.35, 1.15),
    sd   = c(0.12, 0.14, 0.11, 0.13)
  )
  m <- NormativeModel(tab, by = c("age", "sex"), source = "table demo")
  expect_equal(m$kind, "table")
  # exact stratum
  expect_equal(normativeZScore(1.4, m, age = 20, sex = "M"), 0, tolerance = 1e-12)
  # nearest-age match (55 -> 60)
  expect_equal(normativeZScore(1.15 + 0.13, m, age = 55, sex = "F"), 1,
               tolerance = 1e-12)
  # a table missing mean/sd is rejected
  expect_error(NormativeModel(data.frame(age = 1, mu = 2)), "'mean' and 'sd'")
})

test_that("lookup-function model is queried with strata", {
  fn <- function(age = NULL, sex = NULL, task = NULL) {
    list(mean = if (identical(sex, "F")) 1.2 else 1.4, sd = 0.1)
  }
  m <- NormativeModel(fn, source = "fn demo")
  expect_equal(m$kind, "function")
  expect_equal(normativeZScore(1.5, m, sex = "M"), 1, tolerance = 1e-12)
  expect_equal(normativeZScore(1.3, m, sex = "F"), 1, tolerance = 1e-12)
})

test_that("constructor validates numeric mean/sd", {
  expect_error(NormativeModel(1.3), "'sd' is required")
  expect_error(NormativeModel(1.3, sd = 0), "positive")
  expect_error(NormativeModel(1.3, sd = -1), "positive")
  expect_error(NormativeModel(c(1, 2, 3), sd = c(0.1, 0.2)), "same length")
  expect_error(NormativeModel(c(1, 2), sd = 0.1, time = 1:3), "'time' must match")
})

test_that("print.NormativeModel reports the model kind", {
  expect_output(print(NormativeModel(1.3, 0.1)), "scalar")
  expect_output(print(NormativeModel(1:5, 1, time = 1:5)), "waveform")
})

# --- adversarial-review regressions (WS9-03) --------------------------------

test_that("a lookup fn returning unequal mean/sd lengths is rejected, not recycled", {
  # was: (value - mean) / sd silently recycled the shorter sd -> wrong z
  fn <- function(age = NULL, sex = NULL, task = NULL) {
    list(mean = c(1, 2, 3, 4), sd = c(1, 2))
  }
  m <- NormativeModel(fn)
  expect_error(normativeZScore(c(0, 0, 0, 0), m), "same length")
})

test_that("under-specified waveform strata do not interleave into a garbage corridor", {
  # per-age waveform; querying WITHOUT age must not concatenate both ages
  tab <- data.frame(
    age  = rep(c(20, 60), each = 3),
    time = rep(c(0, 50, 100), 2),
    mean = c(1, 2, 3, 10, 20, 30),
    sd   = rep(0.1, 6)
  )
  m <- NormativeModel(tab, by = "age")
  expect_warning(z <- normativeZScore(rep(2, 3), m), "disambiguate")
  expect_length(z, 3L)                                   # one 3-pt waveform, not 6
  # specifying the stratum is unambiguous (no warning)
  expect_silent(z20 <- normativeZScore(c(1, 2, 3), m, age = 20))
  expect_equal(z20, c(0, 0, 0), tolerance = 1e-12)
})

test_that("non-finite / non-numeric resolved norms error clearly", {
  # NA mean in a table -> clear error, not a silent NA z
  na_tab <- data.frame(age = c(20, 60), mean = c(1, NA), sd = c(0.1, 0.2))
  expect_error(normativeZScore(1.0, NormativeModel(na_tab, by = "age"), age = 60),
               "finite")
  # character mean column -> domain error, not an opaque operator error
  chr_tab <- data.frame(age = c(20, 60), mean = c("lo", "hi"), sd = c(0.1, 0.1))
  expect_error(normativeZScore(1.0, NormativeModel(chr_tab, by = "age"), age = 20),
               "numeric")
})

test_that("all-NA observed annotates z as NA without a max() warning", {
  skip_if_not_installed("ggplot2")
  m <- NormativeModel(1.30, 0.15)
  p <- expect_silent(plotNormativeBand(rep(NA_real_, 5), m))
  lab <- p$layers[[which(vapply(p$layers,
    function(l) inherits(l$geom, "GeomLabel"), logical(1)))]]$aes_params$label
  expect_match(as.character(lab), "NA")
})
