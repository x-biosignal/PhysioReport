#' The x-biosignal report theme
#'
#' Thin wrapper returning the shared colorblind-safe ggplot2 theme from
#' \pkg{PhysioCore}, so every report uses consistent, accessible styling.
#'
#' @return A \code{ggplot2} theme (see \code{PhysioCore::theme_physio}).
#' @examples
#' \donttest{
#' if (requireNamespace("ggplot2", quietly = TRUE)) reportTheme()
#' }
#' @export
reportTheme <- function() {
  PhysioCore::theme_physio()
}
