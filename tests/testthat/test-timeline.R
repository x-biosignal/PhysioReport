make_timeline <- function() {
  list(
    sessions = data.frame(time = 1:5),
    outcomes = data.frame(
      time = rep(1:5, 2),
      metric = rep(c("gait_speed", "fma"), each = 5),
      value = c(0.6, 0.7, 0.9, 1.0, 1.1, 20, 22, 28, 30, 33)),
    mdc = c(gait_speed = 0.1, fma = 5),
    mcid = c(gait_speed = 0.15, fma = 9))
}

# the crossing-marker layer is the one whose data carries a classification
.cross_layer_data <- function(p) {
  i <- which(vapply(p$layers,
    function(l) is.data.frame(l$data) && "classification" %in% names(l$data),
    logical(1)))
  if (length(i) == 0L) return(NULL)
  p$layers[[i[1]]]$data
}

test_that("longitudinalTimeline returns a faceted ggplot", {
  skip_if_not_installed("ggplot2")
  d <- make_timeline()
  p <- longitudinalTimeline(d$sessions, outcomes = d$outcomes,
                            mdc = d$mdc, mcid = d$mcid)
  expect_s3_class(p, "ggplot")
  expect_s3_class(p$facet, "FacetWrap")
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("crossing-marker count matches annotateChange on the same series", {
  skip_if_not_installed("ggplot2")
  d <- make_timeline()
  p <- longitudinalTimeline(d$sessions, outcomes = d$outcomes,
                            mdc = d$mdc, mcid = d$mcid)
  markers <- .cross_layer_data(p)
  n_markers <- if (is.null(markers)) 0L else nrow(markers)

  expected <- sum(vapply(split(d$outcomes, d$outcomes$metric), function(df) {
    df <- df[order(df$time), ]
    ann <- annotateChange(df$value[-nrow(df)], df$value[-1],
                          mdc = d$mdc[[df$metric[1]]],
                          mcid = d$mcid[[df$metric[1]]])
    sum(as.character(ann$classification) != "no change")
  }, integer(1)))

  expect_equal(n_markers, expected)
  # no thresholds -> no crossing markers
  p0 <- longitudinalTimeline(d$sessions, outcomes = d$outcomes)
  expect_null(.cross_layer_data(p0))
})

test_that("intervention spans render at the given x-ranges and lanes stack", {
  skip_if_not_installed("ggplot2")
  d <- make_timeline()
  interv <- data.frame(start = c(1.5, 3.0), end = c(2.5, 4.0),
                       label = c("A", "B"))
  p <- longitudinalTimeline(d$sessions, interventions = interv,
                            outcomes = d$outcomes, mdc = d$mdc, mcid = d$mcid)
  rect <- p$layers[[which(vapply(p$layers,
    function(l) is.data.frame(l$data) && "start" %in% names(l$data),
    logical(1)))[1]]]$data
  expect_equal(rect$start, interv$start)
  expect_equal(rect$end, interv$end)
  # one lane (panel) per metric, stacked vertically (ncol = 1)
  built <- ggplot2::ggplot_build(p)
  expect_equal(length(unique(built$layout$layout$PANEL)),
               length(unique(d$outcomes$metric)))
})

test_that("longitudinalTimeline validates its inputs", {
  d <- make_timeline()
  expect_error(longitudinalTimeline(data.frame(x = 1), outcomes = d$outcomes),
               "sessions.*time")
  expect_error(longitudinalTimeline(d$sessions,
               outcomes = data.frame(time = 1, value = 2)), "metric")
  expect_error(longitudinalTimeline(d$sessions, interventions = data.frame(x = 1),
               outcomes = d$outcomes, mdc = 1, mcid = 2), "start")
  # a named threshold vector missing a metric must error, not silently use the
  # wrong metric's threshold
  expect_error(longitudinalTimeline(d$sessions, outcomes = d$outcomes,
               mdc = c(gait_speed = 0.1), mcid = c(gait_speed = 0.15)),
               "no threshold for metric")
  # an unnamed scalar applies to every metric
  expect_s3_class(longitudinalTimeline(d$sessions, outcomes = d$outcomes,
               mdc = 1, mcid = 2), "ggplot")
})

test_that("a missing (dropped-visit) outcome value degrades gracefully", {
  skip_if_not_installed("ggplot2")
  sessions <- data.frame(time = 1:4)
  # a dropped visit (NA) must neither crash nor inject phantom crossing markers
  outcomes <- data.frame(time = 1:4, metric = "fma", value = c(20, NA, 30, 40))
  p <- expect_silent(longitudinalTimeline(sessions, outcomes = outcomes,
                                          mdc = 2, mcid = 5))
  expect_s3_class(p, "ggplot")
  markers <- .cross_layer_data(p)
  # only the genuine 30 -> 40 crossing; the NA-adjacent changes are unclassifiable
  expect_equal(nrow(markers), 1L)
  expect_false(any(is.na(markers$time)))
  expect_false(any(is.na(markers$classification)))

  # a series whose only change involves NA yields no markers, not an error
  out2 <- data.frame(time = 1:2, metric = "x", value = c(NA, 30))
  expect_s3_class(longitudinalTimeline(data.frame(time = 1:2), outcomes = out2,
                                       mdc = 2, mcid = 5), "ggplot")
})

test_that("as.timelineData adapts an MSKLongitudinalTracker", {
  skip_if_not_installed("PhysioMSKNet")
  set.seed(1)
  emg <- function() matrix(abs(stats::rnorm(4 * 200)), nrow = 200)
  tr <- PhysioMSKNet::mskLongitudinalTracker(
    list(T0 = emg(), T1 = emg(), T2 = emg()), metrics = "rms")
  td <- as.timelineData(tr)
  expect_named(td, c("sessions", "outcomes"))
  expect_equal(nrow(td$sessions), 3L)                      # T0/T1/T2
  expect_true(all(c("time", "metric", "value") %in% names(td$outcomes)))
  expect_true(all(td$outcomes$time %in% seq_len(3)))
  expect_s3_class(longitudinalTimeline(td$sessions, outcomes = td$outcomes),
                  "ggplot")
})

test_that("as.timelineData rejects unknown objects", {
  expect_error(as.timelineData(list(1, 2)), "no as.timelineData")
})
