utils::globalVariables(c("ba_mean", "ba_diff"))

#' Bland-Altman agreement plot
#'
#' Draws a Bland-Altman plot (mean vs. difference of paired measurements) with
#' bias and limit-of-agreement reference lines. The statistics come from
#' \code{PhysioCore::blandAltman()}, so the plotted lines exactly match the
#' computed bias and limits of agreement.
#'
#' @param x,y Numeric vectors of paired measurements (e.g. two methods, or
#'   baseline vs follow-up).
#' @param confidence Confidence level for the limits of agreement (default 0.95).
#' @return A \code{ggplot} object.
#' @examples
#' \donttest{
#' plotBlandAltman(c(1, 2, 3, 4, 5), c(1.1, 1.9, 3.2, 3.8, 5.1))
#' }
#' @importFrom ggplot2 ggplot aes geom_point geom_hline labs
#' @export
plotBlandAltman <- function(x, y, confidence = 0.95) {
  ba <- PhysioCore::blandAltman(x, y, confidence = confidence)
  df <- data.frame(ba_mean = (x + y) / 2, ba_diff = x - y)
  ggplot2::ggplot(df, ggplot2::aes(x = ba_mean, y = ba_diff)) +
    ggplot2::geom_point(color = PhysioCore::physioPalette(2)[2], alpha = 0.8) +
    ggplot2::geom_hline(yintercept = ba$bias, linetype = "solid") +
    ggplot2::geom_hline(yintercept = ba$lower_loa, linetype = "dashed") +
    ggplot2::geom_hline(yintercept = ba$upper_loa, linetype = "dashed") +
    ggplot2::labs(
      x = physioLabel("mean"),
      y = physioLabel("difference"),
      title = "Bland-Altman"
    ) +
    reportTheme()
}
