utils::globalVariables(c("domain", "value", "series"))

# Coerce a profile into a series x domain matrix (row-named by series/timepoint,
# column-named by domain). Accepts a named vector, a matrix/data.frame, or a
# PhysioMSKNet MSKFunctionalOutcome (its aggregate ROM/strength/function).
.as_domain_matrix <- function(profile) {
  if (inherits(profile, "MSKFunctionalOutcome")) {
    agg <- profile$aggregate
    v <- c(ROM = agg$overall_rom, Strength = agg$overall_strength,
           Function = agg$overall_function)
    return(matrix(v, nrow = 1L, dimnames = list("profile", names(v))))
  }
  if (is.matrix(profile) || is.data.frame(profile)) {
    m <- as.matrix(profile)
    if (!is.numeric(m)) stop("profile must be numeric.", call. = FALSE)
    if (is.null(colnames(m))) {
      stop("a profile matrix must have domain column names.", call. = FALSE)
    }
    if (is.null(rownames(m))) rownames(m) <- paste0("t", seq_len(nrow(m)))
    return(m)
  }
  v <- as.numeric(profile)
  if (is.null(names(profile))) {
    stop("a profile vector must be named by domain.", call. = FALSE)
  }
  matrix(v, nrow = 1L, dimnames = list("profile", names(profile)))
}

.ref_lookup <- function(reference, domains, what) {
  if (is.data.frame(reference)) {
    if (!all(c("domain", what) %in% names(reference))) {
      stop(sprintf("a data.frame 'reference' needs 'domain' and '%s' columns.",
                   what), call. = FALSE)
    }
    idx <- match(domains, reference$domain)
    if (anyNA(idx)) {
      stop("'reference' is missing domain(s): ",
           paste(domains[is.na(idx)], collapse = ", "), ".", call. = FALSE)
    }
    return(as.numeric(reference[[what]][idx]))
  }
  # a named numeric supplies the mean only
  if (what != "mean") {
    stop("z-normalization needs a data.frame 'reference' with an 'sd' column.",
         call. = FALSE)
  }
  if (is.null(names(reference)) || !all(domains %in% names(reference))) {
    stop("'reference' must be named by domain.", call. = FALSE)
  }
  as.numeric(reference[domains])
}

.radar_normalize <- function(m, reference, normalize) {
  domains <- colnames(m)
  if (normalize == "percent") {
    if (is.null(reference)) return(m)
    ref <- .ref_lookup(reference, domains, "mean")
    if (any(!is.finite(ref)) || any(ref == 0)) {
      stop("'reference' means must be finite and non-zero for percent scaling.",
           call. = FALSE)
    }
    return(sweep(m, 2L, ref, "/") * 100)
  }
  # z
  if (is.null(reference)) {
    stop("normalize = 'z' requires a 'reference'.", call. = FALSE)
  }
  mu <- .ref_lookup(reference, domains, "mean")
  sdv <- .ref_lookup(reference, domains, "sd")
  if (any(!is.finite(sdv)) || any(sdv <= 0)) {
    stop("'reference' sd must be finite and positive.", call. = FALSE)
  }
  sweep(sweep(m, 2L, mu, "-"), 2L, sdv, "/")
}

#' Multi-domain outcome radar (spider) plot
#'
#' Plots a rehabilitation outcome profile across domains as a radar chart, with
#' an optional normative reference polygon and multi-timepoint overlay. Uses the
#' ecosystem colorblind-safe palette and report theme.
#'
#' @param profile Domain scores: a named numeric vector (one timepoint), a
#'   matrix or data.frame with domains as columns and timepoints as rows, or a
#'   \code{MSKFunctionalOutcome} (from
#'   \code{PhysioMSKNet::mskPredictFunctionalOutcome()}), whose aggregate ROM /
#'   strength / function become the domains.
#' @param reference Optional normative reference: a named numeric of per-domain
#'   means (for \code{"percent"}), or a data.frame with \code{domain},
#'   \code{mean} and \code{sd} columns (required for \code{"z"}). Drawn as a
#'   reference polygon.
#' @param normalize \code{"percent"} (each domain as a percentage of its
#'   reference mean; reference polygon at 100) or \code{"z"} (z-score versus the
#'   reference; reference polygon centered at 0).
#' @param domains Optional character vector selecting and ordering the domains.
#' @return A \code{ggplot} object (a \code{coord_polar} radar).
#' @seealso [plotNormativeBand()]
#' @examples
#' plotOutcomeRadar(c(pain = 3, balance = 7, gait = 6, strength = 5))
#' @importFrom ggplot2 ggplot aes geom_polygon geom_point coord_polar
#'   scale_color_manual labs
#' @export
plotOutcomeRadar <- function(profile, reference = NULL,
                             normalize = c("percent", "z"), domains = NULL) {
  normalize <- match.arg(normalize)
  m <- .as_domain_matrix(profile)
  if (!is.null(domains)) {
    miss <- setdiff(domains, colnames(m))
    if (length(miss) > 0) {
      stop("profile is missing domain(s): ", paste(miss, collapse = ", "), ".",
           call. = FALSE)
    }
    m <- m[, domains, drop = FALSE]
  }
  dom <- colnames(m)
  if (length(dom) < 3L) {
    stop("a radar needs at least 3 domains.", call. = FALSE)
  }
  mn <- .radar_normalize(m, reference, normalize)

  df <- data.frame(
    series = factor(rep(rownames(mn), each = length(dom)),
                    levels = rownames(mn)),
    domain = factor(rep(dom, times = nrow(mn)), levels = dom),
    value = as.vector(t(mn)), stringsAsFactors = FALSE)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = domain, y = value, group = series))
  # normative reference polygon (drawn first, behind the profiles)
  if (!is.null(reference)) {
    ref_val <- if (normalize == "percent") 100 else 0
    ref_df <- data.frame(domain = factor(dom, levels = dom), value = ref_val)
    p <- p + ggplot2::geom_polygon(
      data = ref_df, ggplot2::aes(x = domain, y = value, group = 1L),
      inherit.aes = FALSE, fill = NA, color = "grey50", linetype = "dashed")
  }
  p <- p +
    ggplot2::geom_polygon(ggplot2::aes(color = series), fill = NA,
                          linewidth = 0.8) +
    ggplot2::geom_point(ggplot2::aes(color = series), size = 2) +
    ggplot2::scale_color_manual(
      values = PhysioCore::physioPalette(nrow(mn)),
      name = if (nrow(mn) > 1L) NULL else "series") +
    ggplot2::coord_polar()
  if (nrow(mn) == 1L) p <- p + ggplot2::guides(color = "none")

  ylab <- physioLabel(if (normalize == "percent") "percent_reference"
                      else "z_score")
  p + ggplot2::labs(x = NULL, y = ylab) + reportTheme()
}
