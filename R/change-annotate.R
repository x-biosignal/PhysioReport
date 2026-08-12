utils::globalVariables(c("metric", "change", "classification", "mdc", "mcid"))

# Classification labels (stable English keys used programmatically downstream).
.CHANGE_LEVELS <- c("no change", "detectable (>MDC)",
                    "clinically meaningful (>MCID)")

#' Classify pre-to-post change against MDC and MCID thresholds
#'
#' Annotates a set of paired (pre, post) outcome scores against their Minimal
#' Detectable Change (MDC) and Minimal Clinically Important Difference (MCID)
#' thresholds, classifying each change as \code{"no change"} (within measurement
#' error), \code{"detectable (>MDC)"} (a real change that clears measurement
#' error) or \code{"clinically meaningful (>MCID)"}. Thresholds are compared to
#' the absolute change and are boundary-inclusive (a change exactly equal to the
#' MDC is \code{"detectable"}). The \code{direction} of benefit is tracked
#' separately so decrease-is-good metrics (pain, timed tests) are handled
#' correctly.
#'
#' @param pre,post Numeric vectors of pre- and post-intervention scores (one
#'   element per metric); may be named to label the metrics.
#' @param mdc,mcid Numeric MDC / MCID thresholds (positive), a scalar recycled
#'   across metrics or a vector matching \code{pre}. Obtain the MDC from
#'   \code{PhysioCore::mdc()} (or \code{PhysioMoCap::mdc()}); the MCID is the
#'   instrument's anchor-based value.
#' @param direction Benefit direction, \code{"increase"} (higher is better,
#'   default) or \code{"decrease"} (lower is better); a scalar applied to all
#'   metrics or a vector matching \code{pre}.
#' @return A \code{data.frame} of class \code{"change_annotation"} with columns
#'   \code{metric}, \code{pre}, \code{post}, \code{change} (signed
#'   \code{post - pre}), \code{improvement} (signed so positive = beneficial),
#'   \code{mdc}, \code{mcid}, \code{exceeds_mdc}, \code{exceeds_mcid},
#'   \code{improved}, \code{direction} and \code{classification}. A metric with a
#'   missing \code{pre} or \code{post} yields \code{NA} change and classification:
#'   missingness is propagated rather than silently reported as \code{"no
#'   change"}.
#' @references de Vet HCW et al. (2006). Minimally important change determined by
#'   a visual method. \emph{Qual Life Res}; Shrout & Fleiss (1979) for the SEM
#'   underlying MDC.
#' @seealso [plotChangeAnnotated()], \code{PhysioCore::mdc()}
#' @examples
#' annotateChange(pre = c(fma = 20, pain = 7),
#'                post = c(fma = 31, pain = 4),
#'                mdc = c(5.2, 1.0), mcid = c(9, 2),
#'                direction = c("increase", "decrease"))
#' @export
annotateChange <- function(pre, post, mdc, mcid, direction = "increase") {
  # capture metric names before as.numeric() strips them
  metric <- names(post)
  if (is.null(metric)) metric <- names(pre)
  pre <- as.numeric(pre)
  post <- as.numeric(post)
  n <- length(pre)
  if (n == 0L || length(post) != n) {
    stop("'pre' and 'post' must be non-empty vectors of the same length.",
         call. = FALSE)
  }
  # backfill unnamed OR blank elements (a partially-named vector such as
  # c(a = 3, 7) has names c("a", ""), which is not NULL) so no metric is "".
  default <- paste0("metric", seq_len(n))
  if (is.null(metric)) {
    metric <- default
  } else {
    blank <- is.na(metric) | metric == ""
    metric[blank] <- default[blank]
  }

  mdc <- .recycle_pos(mdc, n, "mdc")
  mcid <- .recycle_pos(mcid, n, "mcid")

  direction <- as.character(direction)
  if (!all(direction %in% c("increase", "decrease"))) {
    stop("'direction' must be 'increase' or 'decrease'.", call. = FALSE)
  }
  if (length(direction) == 1L) direction <- rep(direction, n)
  if (length(direction) != n) {
    stop("'direction' must be length 1 or match 'pre'.", call. = FALSE)
  }
  if (any(mcid < mdc)) {
    warning("some MCID thresholds are below their MDC; a change can then be ",
            "flagged clinically meaningful while within measurement error.",
            call. = FALSE)
  }

  change <- post - pre
  improvement <- ifelse(direction == "increase", change, -change)
  mag <- abs(change)
  classification <- ifelse(mag >= mcid, .CHANGE_LEVELS[3L],
                    ifelse(mag >= mdc,  .CHANGE_LEVELS[2L],
                                        .CHANGE_LEVELS[1L]))

  out <- data.frame(
    metric = metric, pre = pre, post = post, change = change,
    improvement = improvement, mdc = mdc, mcid = mcid,
    exceeds_mdc = mag >= mdc, exceeds_mcid = mag >= mcid,
    improved = improvement > 0, direction = direction,
    classification = factor(classification, levels = .CHANGE_LEVELS),
    stringsAsFactors = FALSE, row.names = NULL
  )
  class(out) <- c("change_annotation", "data.frame")
  out
}

.recycle_pos <- function(v, n, nm) {
  v <- as.numeric(v)
  if (length(v) == 1L) v <- rep(v, n)
  if (length(v) != n) {
    stop(sprintf("'%s' must be length 1 or match 'pre'.", nm), call. = FALSE)
  }
  if (any(!is.finite(v)) || any(v <= 0)) {
    stop(sprintf("'%s' must be finite and positive.", nm), call. = FALSE)
  }
  v
}

#' @export
print.change_annotation <- function(x, ...) {
  cat("<change_annotation>", nrow(x), "metric(s)\n")
  # subsetting keeps the "change_annotation" subclass, so drop it before the
  # inner print() to avoid dispatching back into this method (infinite
  # recursion); intersect the summary columns with those actually present so a
  # column-subset (which also keeps the subclass) prints instead of erroring.
  y <- x
  class(y) <- "data.frame"
  cols <- intersect(c("metric", "change", "mdc", "mcid", "classification"),
                    names(y))
  print(y[, cols, drop = FALSE], row.names = FALSE)
  invisible(x)
}

#' Forest-style plot of annotated pre-to-post changes
#'
#' Draws one row per metric showing the signed change as a point, with the
#' \eqn{\pm}MDC and \eqn{\pm}MCID thresholds as symmetric reference bands around
#' the no-change line, coloured by the change classification.
#'
#' @param changes A \code{"change_annotation"} object from
#'   \code{\link{annotateChange}}.
#' @return A \code{ggplot} object.
#' @seealso [annotateChange()]
#' @examples
#' \donttest{
#' ch <- annotateChange(c(fma = 20, pain = 7), c(fma = 31, pain = 4),
#'                      mdc = c(5.2, 1.0), mcid = c(9, 2),
#'                      direction = c("increase", "decrease"))
#' plotChangeAnnotated(ch)
#' }
#' @importFrom ggplot2 ggplot aes geom_vline geom_segment geom_point
#'   scale_color_manual labs
#' @export
plotChangeAnnotated <- function(changes) {
  if (!inherits(changes, "change_annotation")) {
    stop("'changes' must be a change_annotation (from annotateChange()).",
         call. = FALSE)
  }
  df <- as.data.frame(changes)
  df$metric <- factor(df$metric, levels = rev(unique(df$metric)))

  cols <- stats::setNames(
    c("grey60", PhysioCore::physioPalette(8)[c(2L, 7L)]), .CHANGE_LEVELS)

  # +/-MDC and +/-MCID reference bands as horizontal segments per metric
  # (geom_segment is orientation-stable across ggplot2 versions, unlike the
  # soft-deprecated geom_errorbarh). MCID (wider, lighter) first, MDC on top.
  ggplot2::ggplot(df, ggplot2::aes(y = metric)) +
    ggplot2::geom_vline(xintercept = 0, color = "grey40") +
    ggplot2::geom_segment(ggplot2::aes(x = -mcid, xend = mcid, yend = metric),
                          color = "grey80", linewidth = 3) +
    ggplot2::geom_segment(ggplot2::aes(x = -mdc, xend = mdc, yend = metric),
                          color = "grey55", linewidth = 1.5) +
    ggplot2::geom_point(ggplot2::aes(x = change, color = classification),
                        size = 3.5) +
    ggplot2::scale_color_manual(values = cols, drop = FALSE) +
    ggplot2::labs(x = physioLabel("change"), y = NULL, color = NULL,
                  title = "Change vs MDC / MCID") +
    reportTheme()
}
