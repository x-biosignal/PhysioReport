utils::globalVariables(c("x", "ymin", "ymax", "med", "obs"))

# NULL-coalescing helper (base R gained %||% only in 4.4; define locally so the
# package works on the declared R (>= 4.2) floor).
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

#' Normative reference model (mean / SD corridor)
#'
#' Builds a reusable description of a normative reference — the expected
#' \code{mean} and \code{sd} of a measurement, optionally stratified by covariates
#' such as age, sex or task. A model can be
#' \emph{scalar} (one mean/sd), a \emph{waveform} (per-timepoint mean/sd vectors,
#' e.g. a 101-point gait-cycle corridor), a stratified \emph{table}
#' (a \code{data.frame} with the strata columns plus \code{mean}/\code{sd} and an
#' optional \code{time} column), or a \emph{lookup function}
#' \code{function(age, sex, task)} returning a \code{list(mean, sd, time)}. The
#' table/function forms let a normative database drive the model; when no database
#' is available an inline scalar/waveform/table spec degrades gracefully to the
#' same interface.
#'
#' @param mean Numeric scalar or vector (the reference mean / waveform), OR a
#'   \code{data.frame} of stratified norms (must contain \code{mean} and
#'   \code{sd} columns, plus the \code{by} strata columns and an optional
#'   \code{time} column), OR a lookup \code{function(age, sex, task)} returning
#'   \code{list(mean=, sd=, time=)}.
#' @param sd Numeric scalar or vector of the same length as \code{mean} (recycled
#'   from length 1). Required for the numeric form; ignored for the table /
#'   function forms.
#' @param by Character vector naming the stratification columns/arguments
#'   (default \code{c("age", "sex", "task")}); for a \code{data.frame} the
#'   defaults are narrowed to the columns actually present.
#' @param source Optional character string describing the normative source
#'   (citation), used as the default plot title.
#' @param time Optional numeric vector (same length as \code{mean}) giving the
#'   x-axis (e.g. % gait cycle) for a waveform model.
#' @return An object of class \code{"NormativeModel"}.
#' @seealso [normativeZScore()], [plotNormativeBand()]
#' @examples
#' # scalar norm (e.g. comfortable gait speed for a stratum)
#' m <- NormativeModel(mean = 1.30, sd = 0.15, source = "Bohannon 1997")
#' normativeZScore(1.00, m)
#'
#' # waveform norm (101-point knee-flexion corridor)
#' wf <- NormativeModel(mean = sin(seq(0, pi, length.out = 101)),
#'                      sd = rep(0.1, 101), time = 0:100)
#' @export
NormativeModel <- function(mean, sd = NULL, by = c("age", "sex", "task"),
                           source = NULL, time = NULL) {
  if (is.function(mean)) {
    model <- list(kind = "function", fn = mean, by = by, source = source)
  } else if (is.data.frame(mean)) {
    tab <- mean
    if (!all(c("mean", "sd") %in% names(tab))) {
      stop("a normative table must contain 'mean' and 'sd' columns",
           call. = FALSE)
    }
    by <- intersect(by, names(tab))
    model <- list(kind = "table", table = tab, by = by,
                  has_time = "time" %in% names(tab), source = source)
  } else {
    mean <- as.numeric(mean)
    if (is.null(sd)) {
      stop("'sd' is required for a numeric normative model", call. = FALSE)
    }
    sd <- as.numeric(sd)
    if (length(sd) == 1L) sd <- rep(sd, length(mean))
    if (length(sd) != length(mean)) {
      stop("'mean' and 'sd' must have the same length", call. = FALSE)
    }
    if (length(mean) == 0L || any(!is.finite(mean))) {
      stop("'mean' must be finite and non-empty", call. = FALSE)
    }
    if (any(!is.finite(sd)) || any(sd <= 0)) {
      stop("'sd' must be finite and positive", call. = FALSE)
    }
    if (!is.null(time) && length(time) != length(mean)) {
      stop("'time' must match the length of 'mean'", call. = FALSE)
    }
    kind <- if (length(mean) > 1L) "waveform" else "scalar"
    model <- list(kind = kind, mean = mean, sd = sd, time = time,
                  source = source)
  }
  structure(model, class = "NormativeModel")
}

# Resolve a model + requested strata to a concrete list(mean, sd, time). All
# forms are validated at the end (finite numeric mean, finite positive sd, equal
# length) so the table / function paths cannot bypass the invariants the numeric
# constructor enforces.
.resolveNorm <- function(model, age = NULL, sex = NULL, task = NULL) {
  out <- if (model$kind %in% c("scalar", "waveform")) {
    list(mean = model$mean, sd = model$sd, time = model$time)
  } else if (model$kind == "function") {
    o <- model$fn(age = age, sex = sex, task = task)
    if (!is.list(o) || !all(c("mean", "sd") %in% names(o))) {
      stop("normative lookup function must return list(mean=, sd=[, time=])",
           call. = FALSE)
    }
    list(mean = o$mean, sd = o$sd, time = if (!is.null(o$time)) o$time)
  } else {
    # table: filter by each requested stratum (exact for categorical, nearest
    # for numeric such as age); a retained 'time' column marks a waveform.
    tab <- model$table
    strata <- list(age = age, sex = sex, task = task)
    for (col in model$by) {
      val <- strata[[col]]
      if (is.null(val)) next
      if (is.numeric(tab[[col]])) {
        nearest <- tab[[col]][which.min(abs(tab[[col]] - val))]
        tab <- tab[tab[[col]] == nearest, , drop = FALSE]
      } else {
        tab <- tab[as.character(tab[[col]]) == as.character(val), , drop = FALSE]
      }
    }
    if (nrow(tab) == 0L) {
      stop("no normative rows match the requested strata", call. = FALSE)
    }
    if (isTRUE(model$has_time)) {
      # under-specified strata leave several waveforms interleaved (duplicate
      # timepoints); collapse to the first group rather than return garbage.
      if (anyDuplicated(tab$time)) {
        if (length(model$by) == 0L) {
          stop("normative waveform table has duplicate timepoints",
               call. = FALSE)
        }
        grp <- do.call(paste, c(tab[, model$by, drop = FALSE], sep = "\r"))
        warning("multiple normative waveforms match the strata; using the ",
                "first (specify strata to disambiguate)", call. = FALSE)
        tab <- tab[grp == grp[1L], , drop = FALSE]
      }
      tab <- tab[order(tab$time), , drop = FALSE]
      list(mean = tab$mean, sd = tab$sd, time = tab$time)
    } else {
      if (nrow(tab) > 1L) {
        warning("multiple normative rows match the strata; using the first",
                call. = FALSE)
      }
      list(mean = tab$mean[1L], sd = tab$sd[1L], time = NULL)
    }
  }
  mn <- out$mean
  sdv <- out$sd
  if (!is.numeric(mn) || length(mn) == 0L || any(!is.finite(mn))) {
    stop("resolved normative 'mean' must be finite and numeric", call. = FALSE)
  }
  if (!is.numeric(sdv) || any(!is.finite(sdv)) || any(sdv <= 0)) {
    stop("resolved normative 'sd' must be finite and positive", call. = FALSE)
  }
  if (length(mn) != length(sdv)) {
    stop(sprintf(
      "resolved normative 'mean' (%d) and 'sd' (%d) must have the same length",
      length(mn), length(sdv)), call. = FALSE)
  }
  list(mean = as.numeric(mn), sd = as.numeric(sdv),
       time = if (!is.null(out$time)) as.numeric(out$time))
}

#' @export
print.NormativeModel <- function(x, ...) {
  cat("<NormativeModel>\n")
  cat("  kind:  ", x$kind, "\n", sep = "")
  if (x$kind == "scalar") {
    cat(sprintf("  mean = %.4g, sd = %.4g\n", x$mean, x$sd))
  } else if (x$kind == "waveform") {
    cat("  length:", length(x$mean), "point(s)\n")
  } else if (x$kind == "table") {
    cat("  strata:", paste(x$by, collapse = ", "),
        if (isTRUE(x$has_time)) "(waveform)" else "", "\n")
    cat("  rows:  ", nrow(x$table), "\n")
  } else if (x$kind == "function") {
    cat("  strata:", paste(x$by, collapse = ", "), "(lookup function)\n")
  }
  if (!is.null(x$source)) cat("  source:", x$source, "\n")
  invisible(x)
}

#' Normative z-score of an observation
#'
#' Standardizes an observed value (or waveform) against a
#' \code{\link{NormativeModel}}: \eqn{z = (value - mean) / sd}, element-wise. A
#' scalar model recycles across a vector of observations; a waveform model
#' returns a per-timepoint z of the same length as the observation.
#'
#' @param value Numeric observation. A scalar, a vector of scalars (scored
#'   against a scalar model), or a waveform matching a waveform model's length.
#' @param model A \code{\link{NormativeModel}}.
#' @param age,sex,task Optional strata forwarded to the model to select the
#'   applicable norm.
#' @return Numeric z-score(s), matching the length of \code{value} (or the
#'   waveform length).
#' @seealso [NormativeModel()], [plotNormativeBand()]
#' @examples
#' m <- NormativeModel(mean = 1.30, sd = 0.15)
#' normativeZScore(c(1.00, 1.30, 1.60), m)
#' @export
normativeZScore <- function(value, model, age = NULL, sex = NULL, task = NULL) {
  stopifnot(inherits(model, "NormativeModel"))
  ref <- .resolveNorm(model, age, sex, task)
  mn <- ref$mean
  sdv <- ref$sd
  if (any(!is.finite(sdv)) || any(sdv <= 0)) {
    stop("normative 'sd' must be finite and positive", call. = FALSE)
  }
  value <- as.numeric(value)
  if (length(mn) != 1L && length(value) != length(mn)) {
    stop(sprintf(
      "'value' length (%d) must match the waveform model length (%d)",
      length(value), length(mn)), call. = FALSE)
  }
  (value - mn) / sdv
}

#' Plot an observation against a normative band
#'
#' Draws a normative corridor as graded \eqn{\pm1}SD and \eqn{\pm2}SD ribbons
#' around the reference median, overlays the observed trajectory, and annotates
#' the z-score. Uses the ecosystem colorblind-safe palette and report theme.
#'
#' @param observed Numeric observation (a waveform, or a scalar broadcast across
#'   the corridor). \code{NULL} draws just the corridor (no observed line and no
#'   z annotation), so callers can overlay their own traces (e.g. left/right);
#'   for a scalar model this requires \code{time_axis} to set the x extent.
#' @param model A \code{\link{NormativeModel}}.
#' @param bands Numeric vector of SD multiples to shade (default
#'   \code{c(1, 2)}); one \code{geom_ribbon} layer per band, widest drawn first.
#' @param time_axis Optional numeric x-axis; defaults to the model's \code{time}
#'   or the sample index.
#' @param annotate_z Logical; if \code{TRUE} (default) annotate the (max
#'   absolute) z-score.
#' @param age,sex,task Optional strata forwarded to the model.
#' @param ... Currently unused (reserved for future styling arguments).
#' @return A \code{ggplot} object.
#' @seealso [NormativeModel()], [normativeZScore()]
#' @examples
#' \donttest{
#' wf <- NormativeModel(mean = sin(seq(0, pi, length.out = 101)),
#'                      sd = rep(0.1, 101), time = 0:100)
#' obs <- sin(seq(0, pi, length.out = 101)) + rnorm(101, 0, 0.05)
#' plotNormativeBand(obs, wf)
#' }
#' @importFrom ggplot2 ggplot aes geom_ribbon geom_path geom_line annotate labs
#' @export
plotNormativeBand <- function(observed = NULL, model, bands = c(1, 2),
                              time_axis = NULL, annotate_z = TRUE,
                              age = NULL, sex = NULL, task = NULL, ...) {
  stopifnot(inherits(model, "NormativeModel"))
  ref <- .resolveNorm(model, age, sex, task)
  mn <- ref$mean
  sdv <- ref$sd
  has_obs <- !is.null(observed)
  if (has_obs) {
    observed <- as.numeric(observed)
    n <- length(observed)
    # broadcast a scalar corridor across the observed trajectory
    if (length(mn) == 1L && n > 1L) {
      mn <- rep(mn, n)
      sdv <- rep(sdv, n)
    }
    if (length(mn) != n) {
      stop(sprintf(
        "'observed' length (%d) must match the model length (%d)",
        n, length(mn)), call. = FALSE)
    }
  } else {
    # corridor-only: the extent comes from the model waveform (or time_axis
    # for a scalar model, which otherwise has no x extent to draw across)
    n <- length(mn)
    if (n == 1L && is.null(time_axis) && is.null(ref$time)) {
      stop("a corridor-only plot of a scalar model needs 'time_axis'.",
           call. = FALSE)
    }
    if (n == 1L && !is.null(time_axis)) {
      mn <- rep(mn, length(time_axis))
      sdv <- rep(sdv, length(time_axis))
      n <- length(time_axis)
    }
  }
  if (any(!is.finite(sdv)) || any(sdv <= 0)) {
    stop("normative 'sd' must be finite and positive", call. = FALSE)
  }
  x <- time_axis %||% ref$time %||% seq_len(n)
  if (length(x) != n) {
    stop("'time_axis' must match the length of the corridor.", call. = FALSE)
  }
  bands <- sort(unique(bands[is.finite(bands) & bands > 0]))

  pal <- PhysioCore::physioPalette(8)
  band_fill <- pal[6L]     # Okabe-Ito blue (CVD-safe corridor)
  obs_col <- pal[2L]       # Okabe-Ito orange (CVD-safe against blue)

  base_df <- data.frame(x = x, med = mn)
  p <- ggplot2::ggplot(base_df, ggplot2::aes(x = x))
  # widest band first; translucent ribbons stack into a graded corridor
  for (k in rev(bands)) {
    rib <- data.frame(x = x, ymin = mn - k * sdv, ymax = mn + k * sdv)
    p <- p + ggplot2::geom_ribbon(
      data = rib, ggplot2::aes(x = x, ymin = ymin, ymax = ymax),
      fill = band_fill, alpha = 0.16, inherit.aes = FALSE)
  }
  # reference median drawn as a dashed path (GeomPath, distinct from the
  # observed GeomLine so the observed remains the single data line)
  p <- p + ggplot2::geom_path(ggplot2::aes(y = med), linetype = "dashed",
                              color = band_fill)
  if (has_obs) {
    base_df$obs <- observed
    p <- p + ggplot2::geom_line(data = base_df, ggplot2::aes(y = obs),
                                color = obs_col, linewidth = 0.9)
  }

  if (has_obs && isTRUE(annotate_z)) {
    z <- (observed - mn) / sdv
    zlab <- if (n == 1L) {
      sprintf("%s = %.2f", physioLabel("z_score"), z)
    } else {
      maxz <- suppressWarnings(max(abs(z), na.rm = TRUE))
      if (is.finite(maxz)) {
        sprintf("max|%s| = %.2f", physioLabel("z_score"), maxz)
      } else {
        sprintf("max|%s| = NA", physioLabel("z_score"))
      }
    }
    p <- p + ggplot2::annotate("label", x = -Inf, y = Inf, hjust = -0.05,
                               vjust = 1.1, label = zlab)
  }

  p + ggplot2::labs(
    x = physioLabel("time"),
    y = physioLabel("value"),
    title = model$source %||% physioLabel("normative_band")
  ) + reportTheme()
}
