# --- synthetic gait fixture ---------------------------------------------------

make_gait_norm <- function(np = 101, n_subj = 30) {
  vars <- c("pelvic_tilt", "pelvic_obliquity", "pelvic_rotation",
            "hip_flexion", "hip_adduction", "hip_rotation",
            "knee_flexion", "ankle_dorsiflexion", "foot_progression")
  pct <- seq(0, 100, length.out = np)
  mn <- t(vapply(seq_along(vars),
                 function(i) sin(2 * pi * (pct / 100) + i * 0.3) * 15,
                 numeric(np)))
  rownames(mn) <- vars
  sd <- matrix(3, length(vars), np, dimnames = list(vars, NULL))
  feat <- t(vapply(seq_len(n_subj),
                   function(s) as.vector(t(mn)) + stats::rnorm(length(vars) * np, 0, 3),
                   numeric(length(vars) * np)))
  list(variables = vars, mean = mn, sd = sd, cycle_length = np,
       percent = pct, features = feat)
}

make_gait_pe <- function(norm, dev = 0) {
  vars <- norm$variables
  np <- ncol(norm$mean)
  stats::setNames(lapply(vars, function(v) {
    list(left = norm$mean[v, ] + stats::rnorm(np, 0, 1),
         right = norm$mean[v, ] + dev + stats::rnorm(np, 0, 1))
  }), vars)
}

# --- gaitIndexDashboard -------------------------------------------------------

test_that("gaitIndexDashboard returns a coloured bar panel", {
  skip_if_not_installed("ggplot2")
  p <- gaitIndexDashboard(gdi = 82, gps = 8.4,
                          map = c(pelvis = 3, hip = 9, knee = 12, ankle = 6))
  expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_true(any(geoms == "GeomCol"))
  expect_silent(ggplot2::ggplot_build(p))
  expect_match(p$labels$subtitle, "GDI = 82")
  expect_error(gaitIndexDashboard(90, 5, numeric(0)), "at least one")
})

test_that("gaitIndexDashboard accepts index objects", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("PhysioMoCap")
  set.seed(1)
  norm <- make_gait_norm()
  kin <- norm$mean[norm$variables, ] + 2
  map <- PhysioMoCap::movementAnalysisProfile(kin, norm)
  gdi <- PhysioMoCap::gaitDeviationIndex(kin, norm)
  p <- gaitIndexDashboard(gdi, map, map)
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
})

# --- clinicalGaitReport -------------------------------------------------------

test_that("clinicalGaitReport composes a multi-panel patchwork with an index panel", {
  skip_if_not_installed("patchwork")
  skip_if_not_installed("PhysioMoCap")
  set.seed(42)
  norm <- make_gait_norm()
  pe <- make_gait_pe(norm)

  rep <- clinicalGaitReport(pe, norm)
  expect_s3_class(rep, "patchwork")
  # panel count = n waveform panels (one per variable) + 1 index panel
  n_panels <- length(rep$patches$plots) + 1L
  expect_equal(n_panels, length(norm$variables) + 1L)
  # renders end-to-end without error
  expect_silent(patchwork::patchworkGrob(rep))

  # indices = FALSE drops the dashboard panel
  rep0 <- clinicalGaitReport(pe, norm, indices = FALSE)
  expect_equal(length(rep0$patches$plots) + 1L, length(norm$variables))
})

test_that("each waveform panel has a normative ribbon and both L/R traces", {
  skip_if_not_installed("ggplot2")
  set.seed(7)
  norm <- make_gait_norm()
  pe <- make_gait_pe(norm)
  x <- norm$percent
  v <- "knee_flexion"
  panel <- .gait_waveform_panel(v, norm$mean[v, ], norm$sd[v, ],
                                pe[[v]]$left, pe[[v]]$right, x,
                                events = c(60))
  geoms <- vapply(panel$layers, function(l) class(l$geom)[1], character(1))
  expect_gte(sum(geoms == "GeomRibbon"), 1L)              # normative corridor
  expect_true(any(geoms == "GeomVline"))                  # event marker
  line <- panel$layers[[which(geoms == "GeomLine")[1]]]
  expect_setequal(unique(line$data$side), c("Left", "Right"))
  expect_equal(panel$labels$title, v)
})

test_that("clinicalGaitReport validates inputs", {
  skip_if_not_installed("patchwork")
  norm <- make_gait_norm()
  set.seed(1); pe <- make_gait_pe(norm)
  expect_error(clinicalGaitReport(list(), norm), "named list")
  expect_error(clinicalGaitReport(pe, list(variables = "x")), "gait_norm")
  # no common variables
  pe_other <- stats::setNames(pe, paste0("z", seq_along(pe)))
  expect_error(clinicalGaitReport(pe_other, norm), "common")
})

test_that("gaitIndexDashboard reports a per-side GDI vector", {
  skip_if_not_installed("ggplot2")
  p <- gaitIndexDashboard(gdi = c(L = 298, R = 126), gps = 8.3,
                          map = c(hip = 25, knee = 25, ankle = 3))
  expect_match(p$labels$subtitle, "L 298 / R 126")
})

test_that("gait indices score each limb, not the L/R-averaged waveform", {
  skip_if_not_installed("PhysioMoCap")
  set.seed(1)
  norm <- make_gait_norm()
  # healthy left (= normative mean); pathological right (+25 deg on two joints)
  pe <- stats::setNames(lapply(norm$variables, function(v) {
    r <- norm$mean[v, ]
    if (v %in% c("hip_flexion", "knee_flexion")) r <- r + 25
    list(left = norm$mean[v, ], right = r)
  }), norm$variables)

  idx <- .gait_index_panel(pe, norm)
  d <- idx$data
  # worst-side GVS surfaces the affected limb's full 25 deg deviation (not 12.5)
  expect_equal(d$value[d$label == "hip_flexion"], 25, tolerance = 1e-6)
  expect_equal(d$value[d$label == "knee_flexion"], 25, tolerance = 1e-6)
  # overall GPS is the bilateral RMS of all 18 per-side GVS (9 left = 0, 9 right
  # of which two are 25), not the halved average of the two limbs' waveforms
  gps <- d$value[d$kind == "GPS"]
  expect_equal(gps, sqrt((25^2 + 25^2) / 18), tolerance = 1e-6)
  # per-side GDI distinguishes the pathological right limb
  expect_match(idx$labels$subtitle, "L .* / R ")
})

test_that("clinicalGaitReport snapshot is stable", {
  # vdiffr visual snapshots are not portable across CI runners (font/graphics
  # backends differ), so run this as a local visual-regression check only.
  skip_on_ci()
  skip_if_not_installed("vdiffr")
  skip_if_not_installed("patchwork")
  skip_if_not_installed("PhysioMoCap")
  set.seed(42)
  norm <- make_gait_norm()
  pe <- make_gait_pe(norm)
  vdiffr::expect_doppelganger("clinical-gait-report",
                              clinicalGaitReport(pe, norm))
})
