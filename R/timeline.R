utils::globalVariables(c("time", "value", "metric", "start", "end",
                         "classification", "xmin", "xmax", "ymin", "ymax"))

.req_cols <- function(df, cols, nm) {
  if (!is.data.frame(df)) {
    stop(sprintf("'%s' must be a data.frame.", nm), call. = FALSE)
  }
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0) {
    stop(sprintf("'%s' is missing column(s): %s.", nm,
                 paste(miss, collapse = ", ")), call. = FALSE)
  }
  invisible(df)
}

# Per-metric threshold: an unnamed scalar applied to every metric, or a value
# keyed by metric name (which must then cover the metric — falling back to the
# first value would silently apply the wrong metric's threshold).
.timeline_thr <- function(x, metric, nm) {
  nms <- names(x)
  if (is.null(nms) || all(!nzchar(nms))) {
    return(as.numeric(x)[1L])
  }
  if (!metric %in% nms) {
    stop(sprintf("'%s' is named but has no threshold for metric '%s'.",
                 nm, metric), call. = FALSE)
  }
  as.numeric(x[nms == metric][1L])
}

.timeline_class_cols <- function() {
  stats::setNames(PhysioCore::physioPalette(8)[c(2L, 7L)], .CHANGE_LEVELS[2:3])
}

# Session-to-session MDC/MCID crossings per metric, as marker rows.
.timeline_crossings <- function(outcomes, mdc, mcid) {
  if (is.null(mdc) || is.null(mcid)) return(NULL)
  parts <- lapply(split(outcomes, outcomes$metric), function(df) {
    df <- df[order(df$time), , drop = FALSE]
    if (nrow(df) < 2L) return(NULL)
    m <- df$metric[1L]
    ann <- annotateChange(df$value[-nrow(df)], df$value[-1L],
                          mdc = .timeline_thr(mdc, m, "mdc"),
                          mcid = .timeline_thr(mcid, m, "mcid"))
    # a missing pre/post value yields an NA classification (annotateChange
    # propagates missingness); drop those so `keep` is a clean logical - an NA
    # in `keep` both crashes any()/if() and injects phantom NA marker rows
    keep <- !is.na(ann$classification) &
      as.character(ann$classification) != .CHANGE_LEVELS[1L]
    if (!any(keep)) return(NULL)
    data.frame(time = df$time[-1L][keep], metric = m,
               value = df$value[-1L][keep],
               classification = as.character(ann$classification)[keep],
               stringsAsFactors = FALSE)
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (length(parts) == 0L) return(NULL)
  out <- do.call(rbind, parts)
  out$classification <- factor(out$classification, levels = .CHANGE_LEVELS[2:3])
  rownames(out) <- NULL
  out
}

#' Longitudinal patient timeline (swimlane)
#'
#' Draws a longitudinal rehabilitation timeline: each outcome measure is a
#' stacked lane showing its trajectory across sessions, intervention periods are
#' shaded spans across all lanes, and points where the session-to-session change
#' crosses the Minimal Detectable Change / Minimal Clinically Important Difference
#' are marked (via \code{\link{annotateChange}}).
#'
#' @param sessions A \code{data.frame} of session timepoints with a \code{time}
#'   column (numeric or \code{Date}) and an optional \code{label}; drawn as light
#'   session reference lines.
#' @param interventions Optional \code{data.frame} of intervention periods with
#'   \code{start} and \code{end} columns (and an optional \code{label}); drawn as
#'   shaded spans behind every lane.
#' @param outcomes A long \code{data.frame} of outcome measurements with columns
#'   \code{time}, \code{metric} and \code{value} (one lane per \code{metric}).
#' @param mdc,mcid Optional MDC / MCID thresholds used to flag crossings: a
#'   scalar applied to all metrics, or a value named by metric. Both must be
#'   supplied to draw crossing markers.
#' @return A \code{ggplot} object (faceted, one lane per metric).
#' @seealso [annotateChange()], [as.timelineData()]
#' @examples
#' sessions <- data.frame(time = 1:5)
#' outcomes <- data.frame(time = rep(1:5, 2),
#'   metric = rep(c("gait_speed", "fma"), each = 5),
#'   value = c(0.6, 0.7, 0.9, 1.0, 1.1, 20, 22, 28, 30, 33))
#' longitudinalTimeline(sessions, outcomes = outcomes,
#'   mdc = c(gait_speed = 0.1, fma = 5), mcid = c(gait_speed = 0.15, fma = 9))
#' @importFrom ggplot2 ggplot aes geom_rect geom_vline geom_line geom_point
#'   scale_color_manual facet_wrap labs
#' @export
longitudinalTimeline <- function(sessions, interventions = NULL, outcomes,
                                 mdc = NULL, mcid = NULL) {
  .req_cols(sessions, "time", "sessions")
  .req_cols(outcomes, c("time", "metric", "value"), "outcomes")
  outcomes <- as.data.frame(outcomes)
  outcomes$metric <- as.character(outcomes$metric)

  crossings <- .timeline_crossings(outcomes, mdc, mcid)
  traj_col <- PhysioCore::physioPalette(8)[6L]

  p <- ggplot2::ggplot(outcomes, ggplot2::aes(x = time, y = value))
  if (!is.null(interventions)) {
    .req_cols(interventions, c("start", "end"), "interventions")
    p <- p + ggplot2::geom_rect(
      data = interventions,
      ggplot2::aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE, alpha = 0.15,
      fill = PhysioCore::physioPalette(8)[3L])
  }
  p <- p +
    ggplot2::geom_vline(xintercept = sessions$time, color = "grey90") +
    ggplot2::geom_line(color = traj_col) +
    ggplot2::geom_point(color = traj_col, size = 1.8)
  if (!is.null(crossings)) {
    p <- p + ggplot2::geom_point(
      data = crossings,
      ggplot2::aes(x = time, y = value, color = classification),
      size = 3.2) +
      ggplot2::scale_color_manual(values = .timeline_class_cols(),
                                  drop = FALSE, name = NULL)
  }
  p +
    ggplot2::facet_wrap(~ metric, ncol = 1L, scales = "free_y") +
    ggplot2::labs(x = physioLabel("time"), y = physioLabel("value")) +
    reportTheme()
}

#' Adapt a longitudinal tracker to timeline data
#'
#' Converts a longitudinal-tracking result into the \code{sessions} / \code{outcomes}
#' data frames consumed by \code{\link{longitudinalTimeline}}.
#'
#' @param x A tracker object (e.g. a \code{MSKLongitudinalTracker} from
#'   \code{PhysioMSKNet::mskLongitudinalTracker()}).
#' @param ... Unused.
#' @return A list with \code{sessions} and \code{outcomes} data frames.
#' @seealso [longitudinalTimeline()]
#' @export
as.timelineData <- function(x, ...) UseMethod("as.timelineData")

#' @rdname as.timelineData
#' @export
as.timelineData.default <- function(x, ...) {
  stop("no as.timelineData() method for class '",
       paste(class(x), collapse = "/"), "'.", call. = FALSE)
}

#' @rdname as.timelineData
#' @export
as.timelineData.MSKLongitudinalTracker <- function(x, ...) {
  mt <- x$metrics_table
  if (!is.data.frame(mt) ||
      !all(c("timepoint", "muscle", "metric_name", "value") %in% names(mt))) {
    stop("tracker$metrics_table must have columns timepoint, muscle, ",
         "metric_name, value.", call. = FALSE)
  }
  labs <- x$timepoint_labels
  if (is.null(labs)) labs <- unique(mt$timepoint)
  outcomes <- data.frame(
    time = match(mt$timepoint, labs),
    metric = paste(mt$muscle, mt$metric_name),
    value = as.numeric(mt$value),
    stringsAsFactors = FALSE)
  sessions <- data.frame(time = seq_along(labs), label = labs,
                         stringsAsFactors = FALSE)
  list(sessions = sessions, outcomes = outcomes)
}
