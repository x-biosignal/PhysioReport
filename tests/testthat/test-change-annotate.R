test_that("change is classified against MDC and MCID with inclusive boundaries", {
  ch <- annotateChange(
    pre  = c(a = 0, b = 0, c = 0, d = 0),
    post = c(a = 4.9, b = 5.0, c = 7, d = 12),  # mdc = 5, mcid = 10
    mdc = 5, mcid = 10, direction = "increase")

  cl <- as.character(ch$classification)
  expect_equal(cl[1], "no change")                       # 4.9 < MDC
  expect_equal(cl[2], "detectable (>MDC)")               # 5.0 == MDC (inclusive)
  expect_equal(cl[3], "detectable (>MDC)")               # MDC <= 7 < MCID
  expect_equal(cl[4], "clinically meaningful (>MCID)")   # 12 >= MCID
  # change exactly equal to MCID is boundary-inclusive too
  ch2 <- annotateChange(0, 10, mdc = 5, mcid = 10)
  expect_equal(as.character(ch2$classification), "clinically meaningful (>MCID)")

  expect_equal(ch$change, c(4.9, 5.0, 7, 12))
  expect_equal(ch$exceeds_mdc, c(FALSE, TRUE, TRUE, TRUE))
  expect_equal(ch$exceeds_mcid, c(FALSE, FALSE, FALSE, TRUE))
})

test_that("direction handling is correct for decrease-is-good metrics", {
  # pain 7 -> 4 is a 3-point drop; with direction 'decrease' that is a
  # beneficial change of +3 that clears MCID = 2
  ch <- annotateChange(c(pain = 7), c(pain = 4), mdc = 1, mcid = 2,
                       direction = "decrease")
  expect_equal(ch$change, -3)
  expect_equal(ch$improvement, 3)
  expect_true(ch$improved)
  expect_equal(as.character(ch$classification), "clinically meaningful (>MCID)")

  # the same raw change is a deterioration for an increase-is-good metric
  ch_inc <- annotateChange(c(x = 7), c(x = 4), mdc = 1, mcid = 2,
                           direction = "increase")
  expect_equal(ch_inc$improvement, -3)
  expect_false(ch_inc$improved)
  # magnitude-based classification is unchanged by direction
  expect_equal(as.character(ch_inc$classification),
               as.character(ch$classification))

  # per-metric direction vector
  chv <- annotateChange(c(a = 0, b = 10), c(a = 10, b = 0),
                        mdc = 1, mcid = 2,
                        direction = c("increase", "decrease"))
  expect_true(all(chv$improved))
})

test_that("annotateChange validates thresholds and lengths", {
  expect_error(annotateChange(1:3, 1:2, mdc = 1, mcid = 2), "same length")
  expect_error(annotateChange(numeric(0), numeric(0), mdc = 1, mcid = 2),
               "non-empty")
  expect_error(annotateChange(0, 5, mdc = 0, mcid = 2), "positive")
  expect_error(annotateChange(0, 5, mdc = 1, mcid = -1), "positive")
  expect_error(annotateChange(c(0, 0), 1, mdc = 1, mcid = 2), "same length")
  expect_error(annotateChange(0, 5, mdc = c(1, 2), mcid = 2), "length 1 or match")
  expect_error(annotateChange(0, 5, mdc = 1, mcid = 2, direction = "up"),
               "increase")
  # MCID below MDC warns
  expect_warning(annotateChange(0, 5, mdc = 3, mcid = 1), "within measurement")
})

test_that("plotChangeAnnotated draws MDC and MCID reference geoms", {
  skip_if_not_installed("ggplot2")
  ch <- annotateChange(c(a = 0, b = 0, c = 0), c(a = 3, b = 7, c = 12),
                       mdc = 5, mcid = 10)
  # Construction and build must succeed and yield the right geoms. We do not
  # assert strict silence: some ggplot2 releases emit benign, version-dependent
  # deprecation warnings even for geoms used in their current (non-deprecated)
  # form. Correctness is verified structurally below.
  p <- suppressWarnings(plotChangeAnnotated(ch))
  expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], character(1))
  expect_equal(sum(geoms == "GeomSegment"), 2L)   # +/-MDC and +/-MCID bands
  expect_true(any(geoms == "GeomPoint"))          # the change markers
  expect_true(any(geoms == "GeomVline"))          # no-change reference
  expect_no_error(suppressWarnings(ggplot2::ggplot_build(p)))
  expect_error(plotChangeAnnotated(list()), "change_annotation")
})

test_that("print.change_annotation summarises the metrics", {
  ch <- annotateChange(c(fma = 20), c(fma = 31), mdc = 5.2, mcid = 9)
  expect_output(print(ch), "change_annotation")
  expect_output(print(ch), "fma")
})

test_that("printing a column-subset terminates instead of erroring", {
  # `[` keeps the change_annotation subclass, so print dispatches back into the
  # method; it must not assume the full column schema is present
  ch <- annotateChange(c(fma = 20, pain = 7), c(fma = 31, pain = 4),
                       mdc = c(5.2, 1), mcid = c(9, 2),
                       direction = c("increase", "decrease"))
  expect_output(print(ch[, c("metric", "change")]), "fma")
  expect_output(print(ch["metric"]), "pain")
  expect_output(print(ch[ch$improved, ]), "change_annotation")
})

test_that("partially-named pre/post backfill blank metric labels", {
  ch <- annotateChange(c(0, 0), c(a = 3, 7), mdc = 5, mcid = 10)
  expect_equal(ch$metric, c("a", "metric2"))          # not c("a", "")
  expect_false(any(ch$metric == ""))
  # fully unnamed still gets metric1..n
  ch2 <- annotateChange(c(0, 0), c(3, 7), mdc = 5, mcid = 10)
  expect_equal(ch2$metric, c("metric1", "metric2"))
})
