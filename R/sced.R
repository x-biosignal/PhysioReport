utils::globalVariables(c("time", "value", "phase", "x", "xend", "ymin", "ymax",
                         "xmin", "xmax", "yy", "block"))

.sced_frame <- function(data, phase) {
  value <- as.numeric(data)
  phase <- as.character(phase)
  if (length(value) != length(phase)) {
    stop("'data' and 'phase' must have the same length.", call. = FALSE)
  }
  if (length(value) < 2L) {
    stop("need at least two observations.", call. = FALSE)
  }
  levs <- unique(phase)
  if (length(levs) < 2L) {
    stop("need at least two phases.", call. = FALSE)
  }
  data.frame(time = seq_along(value), value = value,
             phase = factor(phase, levels = levs), stringsAsFactors = FALSE)
}

# Split-middle trend (White & Haring): line through the median time/value of the
# first and second halves of a phase (the middle point is dropped when odd).
.split_middle <- function(t, v) {
  n <- length(v)
  if (n < 2L) return(NULL)
  h <- floor(n / 2L)
  i1 <- seq_len(h)
  i2 <- (n - h + 1L):n
  x1 <- stats::median(t[i1]); y1 <- stats::median(v[i1])
  x2 <- stats::median(t[i2]); y2 <- stats::median(v[i2])
  if (x2 == x1) return(NULL)
  slope <- (y2 - y1) / (x2 - x1)
  data.frame(x = c(min(t), max(t)),
             yy = c(y1 + slope * (min(t) - x1), y1 + slope * (max(t) - x1)))
}

#' Single-case (SCED) plot with phase overlays
#'
#' Plots a single-subject time series with SCED-standard overlays: shaded phase
#' panels, phase-change reference lines, per-phase mean lines, the baseline
#' \eqn{\pm}2SD band, and per-phase split-middle celeration (trend) lines.
#'
#' @param data Numeric vector of observations, in session order.
#' @param phase Vector of phase labels (e.g. \code{"A"}/\code{"B"}) the same
#'   length as \code{data}; phases are drawn in order of first appearance.
#' @param overlays Which overlays to draw: any of \code{"mean"} (per-phase mean
#'   lines), \code{"2SD"} (baseline mean \eqn{\pm}2SD band) and
#'   \code{"celeration"} (split-middle trend lines). Default: all three.
#' @return A \code{ggplot} object.
#' @references Kratochwill TR et al. (2010). Single-case designs technical
#'   documentation (What Works Clearinghouse).
#' @seealso [scedStats()]
#' @examples
#' plotSCED(c(2, 3, 2, 3, 6, 7, 8, 7), rep(c("A", "B"), each = 4))
#' @importFrom ggplot2 ggplot aes geom_rect geom_ribbon geom_vline geom_line
#'   geom_point geom_segment labs
#' @export
plotSCED <- function(data, phase, overlays = c("mean", "2SD", "celeration")) {
  df <- .sced_frame(data, phase)
  overlays <- match.arg(overlays, c("mean", "2SD", "celeration"),
                        several.ok = TRUE)
  pal <- PhysioCore::physioPalette(8)

  # group by CONTIGUOUS phase block, not by phase level, so a reversal (ABAB)
  # design shades / summarises each block separately instead of pooling the two
  # non-adjacent A blocks (and the two B blocks) into overlapping spans
  blk <- cumsum(c(1L, as.integer(df$phase)[-1] != as.integer(df$phase)[-nrow(df)]))
  blocks <- split(seq_len(nrow(df)), blk)
  ext <- do.call(rbind, lapply(seq_along(blocks), function(i) {
    rows <- blocks[[i]]; tt <- df$time[rows]
    data.frame(block = i, phase = as.character(df$phase[rows][1L]),
               xmin = min(tt) - 0.5, xmax = max(tt) + 0.5,
               mean = mean(df$value[rows]), stringsAsFactors = FALSE)
  }))
  chg <- which(diff(blk) != 0L)
  boundaries <- (df$time[chg] + df$time[chg + 1L]) / 2

  p <- ggplot2::ggplot(df, ggplot2::aes(x = time, y = value))
  # alternating per-block shading (behind everything)
  ext$fill <- rep(c("grey96", "grey88"), length.out = nrow(ext))
  for (i in seq_len(nrow(ext))) {
    p <- p + ggplot2::geom_rect(
      data = ext[i, ], inherit.aes = FALSE,
      ggplot2::aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
      fill = ext$fill[i], alpha = 0.6)
  }

  if ("2SD" %in% overlays) {
    base <- df$value[blocks[[1L]]]   # the initial baseline block
    m <- mean(base); s <- stats::sd(base)
    if (is.finite(s) && s > 0) {
      band <- data.frame(x = c(min(df$time) - 0.5, max(df$time) + 0.5),
                         ymin = m - 2 * s, ymax = m + 2 * s)
      p <- p + ggplot2::geom_ribbon(
        data = band, inherit.aes = FALSE,
        ggplot2::aes(x = x, ymin = ymin, ymax = ymax),
        fill = pal[3L], alpha = 0.18)
    }
  }

  p <- p +
    ggplot2::geom_vline(xintercept = boundaries, linetype = "dashed",
                        color = "grey40") +
    ggplot2::geom_line(color = pal[6L]) +
    ggplot2::geom_point(color = pal[6L], size = 1.8)

  if ("mean" %in% overlays) {
    means <- data.frame(x = ext$xmin, xend = ext$xmax, yy = ext$mean)
    p <- p + ggplot2::geom_segment(
      data = means, inherit.aes = FALSE,
      ggplot2::aes(x = x, xend = xend, y = yy, yend = yy),
      color = pal[2L], linewidth = 0.8)
  }

  if ("celeration" %in% overlays) {
    cel <- do.call(rbind, lapply(seq_along(blocks), function(i) {
      rows <- blocks[[i]]
      line <- .split_middle(df$time[rows], df$value[rows])
      if (is.null(line)) return(NULL)
      line$block <- i
      line
    }))
    if (!is.null(cel)) {
      p <- p + ggplot2::geom_line(
        data = cel, inherit.aes = FALSE,
        ggplot2::aes(x = x, y = yy, group = block),
        color = pal[7L], linetype = "solid", linewidth = 0.7)
    }
  }

  p + ggplot2::labs(x = physioLabel("session"), y = physioLabel("value")) +
    reportTheme()
}

.sced_est <- function(res) as.numeric(res@estimate)

#' Single-case (SCED) effect-size summary
#'
#' Summarises the nonoverlap / trend effect sizes for a two-phase (A/B) single-
#' case series, delegating to the peer-reviewed estimators in
#' \pkg{PhysioClinStats}: the Percentage of Non-overlapping Data (as a
#' percentage), the Nonoverlap of All Pairs, and the baseline-trend-corrected
#' Tau-U in its bounded tau-b (\code{"scan"}) form.
#'
#' @param data Numeric vector of observations, in session order.
#' @param phase Vector of phase labels the same length as \code{data}; the first
#'   two phases (in order of appearance) are taken as A (baseline) and B
#'   (intervention).
#' @param improvement \code{"increase"} (default) if higher scores are better, or
#'   \code{"decrease"} if lower scores are the goal.
#' @return A \code{data.frame} of class \code{"sced_stats"} with columns
#'   \code{metric} and \code{estimate} (PND in \[0, 100\], NAP in \[0, 1\], Tau-U
#'   in \[-1, 1\]).
#' @references Parker RI, Vannest KJ (2011). Tau-U. Behavior Therapy; Scruggs et
#'   al. (1987) PND; Parker & Vannest (2009) NAP.
#' @seealso [plotSCED()], \code{PhysioClinStats::scedTauU()}
#' @examples
#' \dontrun{
#' scedStats(c(2, 3, 2, 3, 6, 7, 8, 7), rep(c("A", "B"), each = 4))
#' }
#' @export
scedStats <- function(data, phase, improvement = c("increase", "decrease")) {
  improvement <- match.arg(improvement)
  if (!requireNamespace("PhysioClinStats", quietly = TRUE)) {
    stop("scedStats() requires the 'PhysioClinStats' package.", call. = FALSE)
  }
  df <- .sced_frame(data, phase)
  levs <- levels(df$phase)
  A <- df$value[df$phase == levs[1L]]
  B <- df$value[df$phase == levs[2L]]

  pnd <- .sced_est(PhysioClinStats::scedPND(A, B, improvement = improvement))
  nap <- .sced_est(PhysioClinStats::scedNAP(A, B, improvement = improvement))
  # the "scan" tau-b convention (S/D) keeps Tau-U bounded in [-1, 1]; the default
  # "parker" (S/(m*n)) can exceed +/-1 when a baseline trend runs counter to
  # improvement, which would break the documented range for a report table
  tau_u <- .sced_est(PhysioClinStats::scedTauU(A, B, improvement = improvement,
                                               method = "scan"))

  out <- data.frame(
    metric = c("PND", "NAP", "Tau-U"),
    estimate = c(pnd * 100, nap, tau_u),
    stringsAsFactors = FALSE)
  class(out) <- c("sced_stats", "data.frame")
  out
}

#' @export
print.sced_stats <- function(x, ...) {
  cat("<sced_stats>\n")
  y <- x
  class(y) <- "data.frame"
  print(y, row.names = FALSE)
  invisible(x)
}
