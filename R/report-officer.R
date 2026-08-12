# Editable-DOCX report path (officer + optional flextable). This avoids
# any LaTeX dependency: officer writes native Word XML.

# Localized report title, e.g. "Gait report" / "歩行レポート".
.report_title <- function(template, lang = "en") {
  physioLabel(paste0(template, "_report"), lang)
}

# Provenance footer: software versions, the render date, and any caller-supplied
# key/value pairs (e.g. from metadata(pe)).
.report_provenance <- function(prov = NULL) {
  parts <- c(
    sprintf("PhysioReport %s", utils::packageVersion("PhysioReport")),
    sprintf("R %s", getRversion()),
    format(Sys.Date())
  )
  if (!is.null(prov) && length(prov) > 0) {
    kv <- vapply(names(prov),
                 function(k) sprintf("%s: %s", k, paste(prov[[k]], collapse = ", ")),
                 character(1))
    parts <- c(parts, kv)
  }
  paste(parts, collapse = "  |  ")
}

# Embed a ggplot into the docx body as an image. Current officer/rvg no longer
# support editable vector (DrawingML) graphics in a Word body — rvg::dml() is
# PowerPoint/Excel-only and rvg::body_add_vg() is defunct — so we use officer's
# supported body_add_gg() (the body_add.gg method), which renders the plot.
.add_report_ggplot <- function(doc, gg, width = 6.5, height = 3.5) {
  officer::body_add_gg(doc, value = gg, width = width, height = height)
}

# Embed the MDC/MCID change annotation as a table (flextable when available).
.add_change_table <- function(doc, change, lang = "en") {
  df <- as.data.frame(change)
  keep <- intersect(c("metric", "change", "mdc", "mcid", "classification"),
                    names(df))
  df <- df[, keep, drop = FALSE]
  df$classification <- as.character(df$classification)
  if (requireNamespace("flextable", quietly = TRUE)) {
    ft <- flextable::autofit(flextable::flextable(df))
    return(flextable::body_add_flextable(doc, ft))
  }
  officer::body_add_table(doc, df, first_row = TRUE)
}

#' Build an editable DOCX clinical report (officer)
#'
#' Renders a one-page clinical report to an editable Word document using
#' \pkg{officer} (with \pkg{flextable} when available) — no LaTeX
#' toolchain required. Called by \code{\link{renderClinicalReport}} for
#' \code{format = "docx"}; usable directly.
#'
#' @param data A report payload list (see \code{\link{renderClinicalReport}}):
#'   \code{subject}, \code{figures} (a named list of \code{ggplot}s),
#'   \code{change} (an optional \code{change_annotation}) and \code{provenance}
#'   (an optional named list).
#' @param template One of \code{"gait"}, \code{"hrv"}, \code{"emg"} (drives the
#'   localized title).
#' @param lang \code{"en"} or \code{"ja"}.
#' @param out Output \code{.docx} path.
#' @return \code{out}, invisibly.
#' @seealso [renderClinicalReport()]
#' @export
buildDocxReport <- function(data, template = c("gait", "hrv", "emg"),
                            lang = c("en", "ja"), out) {
  template <- match.arg(template)
  lang <- match.arg(lang)
  if (!requireNamespace("officer", quietly = TRUE)) {
    stop("buildDocxReport() requires the 'officer' package.", call. = FALSE)
  }
  .validate_report_data(data)

  doc <- officer::read_docx()
  doc <- officer::body_add_par(doc, .report_title(template, lang),
                               style = "heading 1")
  if (!is.null(data$subject)) {
    doc <- officer::body_add_par(
      doc, sprintf("%s: %s", physioLabel("subject", lang), data$subject))
  }

  for (nm in names(data$figures)) {
    doc <- officer::body_add_par(doc, physioLabel(nm, lang), style = "heading 2")
    doc <- .add_report_ggplot(doc, data$figures[[nm]])
  }

  if (!is.null(data$change)) {
    doc <- officer::body_add_par(doc, physioLabel("change", lang),
                                 style = "heading 2")
    doc <- .add_change_table(doc, data$change, lang)
  }

  doc <- officer::body_add_par(doc, "")
  doc <- officer::body_add_par(doc, .report_provenance(data$provenance))
  print(doc, target = out)
  invisible(out)
}
