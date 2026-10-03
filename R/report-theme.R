#' The x-biosignal report theme
#'
#' Thin wrapper returning the shared colorblind-safe ggplot2 theme from
#' \pkg{PhysioExperiment}, so every report uses consistent, accessible styling.
#'
#' @return A \code{ggplot2} theme (see \code{PhysioExperiment::theme_physio}).
#' @examples
#' reportTheme()
#' @export
reportTheme <- function() {
  PhysioExperiment::theme_physio()
}
