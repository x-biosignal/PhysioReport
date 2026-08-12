utils::globalVariables(c("label", "value", "kind", "x", "y", "side"))

# Left/Right colours, matching PhysioMoCap::plotSymmetry's .side_colours() so the
# report is visually consistent with the rest of the ecosystem.
.report_side_colours <- function() {
  stats::setNames(PhysioCore::physioPalette(2), c("Left", "Right"))
}

# Collapse a side's cycles to a single representative waveform: a points x cycles
# matrix is averaged across cycles; a vector is returned as-is.
.side_mean <- function(w) {
  if (is.matrix(w)) as.numeric(rowMeans(w, na.rm = TRUE)) else as.numeric(w)
}

# Linear-interpolate a waveform onto an n-point grid (0-100% cycle).
.to_grid <- function(w, n) {
  if (length(w) == n) return(w)
  stats::approx(seq_len(length(w)), w, n = n)$y
}

.validate_gait_norm <- function(norm) {
  if (!is.list(norm) || is.null(norm$variables) || is.null(norm$mean) ||
      is.null(norm$sd)) {
    stop("'norm' must be a gait_norm-like list with $variables, $mean, $sd.",
         call. = FALSE)
  }
  if (is.null(rownames(norm$mean)) ||
      !all(norm$variables %in% rownames(norm$mean))) {
    stop("'norm$mean' must be a matrix with rows named by 'norm$variables'.",
         call. = FALSE)
  }
  invisible(norm)
}

.norm_percent <- function(norm) {
  if (!is.null(norm$percent)) return(as.numeric(norm$percent))
  np <- ncol(norm$mean)
  seq(0, 100, length.out = np)
}

# One kinematic/kinetic panel: normative corridor + Left/Right mean traces.
.gait_waveform_panel <- function(var, mean, sd, left, right, x, events = NULL) {
  n <- length(x)
  nm <- NormativeModel(mean = as.numeric(mean), sd = as.numeric(sd),
                       time = x)
  p <- plotNormativeBand(NULL, nm, time_axis = x)
  trace <- rbind(
    data.frame(x = x, y = .to_grid(left, n), side = "Left"),
    data.frame(x = x, y = .to_grid(right, n), side = "Right"))
  p <- p +
    ggplot2::geom_line(data = trace,
                       ggplot2::aes(x = x, y = y, color = side),
                       linewidth = 0.8, inherit.aes = FALSE) +
    ggplot2::scale_color_manual(values = .report_side_colours(), name = NULL) +
    ggplot2::labs(title = var, x = physioLabel("gait_cycle"), y = NULL)
  if (!is.null(events) && length(events) > 0) {
    p <- p + ggplot2::geom_vline(xintercept = as.numeric(events),
                                 linetype = "dotted", color = "grey50")
  }
  p
}

# Compute per-limb GDI/GPS/GVS and build the dashboard. Gait indices are scored
# SEPARATELY for each limb (Schwartz-Rozumalski / Baker): averaging the two
# limbs' waveforms first would cancel antisymmetric (unilateral) deviation and
# mask hemiplegic / unilateral pathology. The overall GPS is the RMS of all
# per-side GVS (the bilateral Baker GPS); the bars show the worse side per
# variable; the GDI is reported for each side.
.gait_index_panel <- function(pe, norm) {
  if (!requireNamespace("PhysioMoCap", quietly = TRUE)) {
    stop("indices = TRUE requires the 'PhysioMoCap' package.", call. = FALSE)
  }
  vars <- norm$variables
  if (!all(vars %in% names(pe))) {
    stop("indices require every norm variable to be present in 'pe'.",
         call. = FALSE)
  }
  side_kin <- function(which) {
    m <- do.call(rbind, lapply(vars, function(v) .side_mean(pe[[v]][[which]])))
    rownames(m) <- vars
    m
  }
  left_kin <- side_kin("left")
  right_kin <- side_kin("right")

  gvs_l <- PhysioMoCap::gaitVariableScore(left_kin, norm)[vars]
  gvs_r <- PhysioMoCap::gaitVariableScore(right_kin, norm)[vars]
  # bilateral GPS = RMS of every per-side GVS (Baker et al. 2009)
  gps <- sqrt(mean(c(gvs_l, gvs_r)^2))
  # worse side per variable, so an asymmetric deviation is not diluted
  gvs_worst <- pmax(gvs_l, gvs_r)

  gdi <- c(L = NA_real_, R = NA_real_)
  if (!is.null(norm$features)) {
    gdi_of <- function(k) {
      tryCatch(PhysioMoCap::gaitDeviationIndex(k, norm)$gdi,
               error = function(e) NA_real_, warning = function(w) NA_real_)
    }
    gdi <- c(L = gdi_of(left_kin), R = gdi_of(right_kin))
  }

  map <- structure(list(gvs = gvs_worst, variables = vars, gps = gps),
                   class = "movement_analysis_profile")
  gaitIndexDashboard(gdi, gps, map)
}

#' Clinical gait report dashboard
#'
#' Composes a multi-panel clinical gait report: one waveform panel per gait
#' variable (a colorblind-safe normative \eqn{\pm}SD corridor from
#' \code{\link{plotNormativeBand}} overlaid with the subject's Left and Right
#' mean traces and optional event markers), followed by a gait-index dashboard
#' (GDI / GPS / Movement Analysis Profile). Panels are laid out with
#' \pkg{patchwork}.
#'
#' @param pe A named list of per-variable side-split cycle waveforms:
#'   \code{pe[[variable]]} is a list with \code{$left} and \code{$right}, each a
#'   numeric cycle waveform or a points-by-cycles matrix (averaged across
#'   cycles). Variables are matched to \code{norm$variables} by name; kinetic
#'   variables (moments/power) can be included when \code{norm} carries their
#'   corridors.
#' @param norm A \code{gait_norm}-like list (e.g. from
#'   \code{PhysioGaitNorm::loadGaitNorm()}) with \code{$variables}, row-named
#'   \code{$mean} and \code{$sd} matrices (variables x cycle points), and
#'   optionally \code{$percent} and \code{$features} (for the GDI).
#' @param events Optional numeric vector of gait-cycle percentages at which to
#'   draw event markers (e.g. toe-off) on every waveform panel.
#' @param sides Which sides to overlay (currently informational; both Left and
#'   Right are drawn).
#' @param indices Logical; if \code{TRUE} (default) append the gait-index
#'   dashboard panel (requires \pkg{PhysioMoCap} and all norm variables present
#'   in \code{pe}); omitted with a warning if it cannot be computed.
#' @return A \pkg{patchwork} composite (a \code{ggplot}-compatible object).
#' @seealso [gaitIndexDashboard()], [plotNormativeBand()],
#'   \code{PhysioMoCap::plotSymmetry()}
#' @examples
#' \donttest{
#' # see the package tests for a synthetic gait fixture
#' }
#' @importFrom ggplot2 geom_line scale_color_manual geom_vline labs
#' @export
clinicalGaitReport <- function(pe, norm, events = NULL, sides = c("L", "R"),
                               indices = TRUE) {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("clinicalGaitReport() requires the 'patchwork' package.",
         call. = FALSE)
  }
  if (!is.list(pe) || is.null(names(pe))) {
    stop("'pe' must be a named list of per-variable Left/Right waveforms.",
         call. = FALSE)
  }
  .validate_gait_norm(norm)
  x <- .norm_percent(norm)
  vars <- intersect(norm$variables, names(pe))
  if (length(vars) == 0L) {
    stop("no variables are common to 'pe' and 'norm$variables'.", call. = FALSE)
  }

  panels <- lapply(vars, function(v) {
    side <- pe[[v]]
    if (!is.list(side) || is.null(side$left) || is.null(side$right)) {
      stop(sprintf("pe[['%s']] must be a list with $left and $right.", v),
           call. = FALSE)
    }
    .gait_waveform_panel(v, norm$mean[v, ], norm$sd[v, ],
                         .side_mean(side$left), .side_mean(side$right),
                         x, events)
  })

  if (isTRUE(indices)) {
    idx <- tryCatch(.gait_index_panel(pe, norm), error = function(e) {
      warning("gait-index panel omitted: ", conditionMessage(e), call. = FALSE)
      NULL
    })
    if (!is.null(idx)) panels <- c(panels, list(idx))
  }
  patchwork::wrap_plots(panels)
}

#' Gait index dashboard panel (GDI / GPS / MAP)
#'
#' A single bar panel summarising the gait indices for a clinical gait report:
#' one bar per Gait Variable Score (the Movement Analysis Profile) plus the
#' overall Gait Profile Score, coloured by deviation magnitude, with the Gait
#' Deviation Index reported in the subtitle (GDI 100 = normative mean, each 10
#' points is one standard deviation, lower = more deviation).
#'
#' @param gdi A \code{gait_deviation_index} (from
#'   \code{PhysioMoCap::gaitDeviationIndex()}) or a numeric GDI value. A named
#'   numeric vector (e.g. \code{c(L = 82, R = 61)}) reports a per-side GDI.
#' @param gps A numeric Gait Profile Score, or a
#'   \code{movement_analysis_profile} (its \code{$gps} is used).
#' @param map A \code{movement_analysis_profile} (from
#'   \code{PhysioMoCap::movementAnalysisProfile()}) or a named numeric vector of
#'   Gait Variable Scores.
#' @return A \code{ggplot} object.
#' @seealso [clinicalGaitReport()]
#' @examples
#' \donttest{
#' gaitIndexDashboard(gdi = 82,
#'                    gps = 8.4,
#'                    map = c(pelvis = 3, hip = 9, knee = 12, ankle = 6))
#' }
#' @importFrom ggplot2 ggplot aes geom_col scale_fill_viridis_c labs
#' @export
gaitIndexDashboard <- function(gdi, gps, map) {
  if (inherits(gdi, "gait_deviation_index")) {
    gdi_txt <- sprintf("%.0f", as.numeric(gdi$gdi))
  } else {
    gv <- as.numeric(gdi)
    if (length(gv) >= 2L && !is.null(names(gdi))) {
      gdi_txt <- paste(sprintf("%s %.0f", names(gdi), gv), collapse = " / ")
    } else {
      gdi_txt <- sprintf("%.0f", gv[1L])
    }
  }
  gps_val <- if (inherits(gps, "movement_analysis_profile")) {
    as.numeric(gps$gps)
  } else {
    as.numeric(gps)[1L]
  }
  if (inherits(map, "movement_analysis_profile")) {
    vars <- map$variables
    gvs <- as.numeric(map$gvs[vars])
  } else {
    gvs <- as.numeric(map)
    vars <- names(map)
    if (is.null(vars)) vars <- paste0("var", seq_along(gvs))
  }
  if (length(gvs) == 0L) {
    stop("'map' must contain at least one Gait Variable Score.", call. = FALSE)
  }

  df <- data.frame(
    label = c(vars, "GPS (overall)"),
    value = c(gvs, gps_val),
    kind = c(rep("GVS", length(vars)), "GPS"),
    stringsAsFactors = FALSE
  )
  df$label <- factor(df$label, levels = rev(df$label))

  ggplot2::ggplot(df, ggplot2::aes(x = value, y = label, fill = value)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_viridis_c(direction = -1, guide = "none") +
    ggplot2::labs(
      x = sprintf("%s (deg)", physioLabel("rms_amplitude")),
      y = NULL,
      title = "Gait indices",
      subtitle = sprintf(
        "GDI = %s  (100 = normative mean, 10 pts = 1 SD; lower = more deviation)",
        gdi_txt)
    ) + reportTheme()
}
