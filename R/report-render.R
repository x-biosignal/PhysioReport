# Validate the report payload shared by every output format.
.validate_report_data <- function(data) {
  if (!is.list(data)) {
    stop("'data' must be a list report payload.", call. = FALSE)
  }
  if (!is.null(data$figures)) {
    nms <- names(data$figures)
    # every figure must be individually (non-blank) named: a partially-named
    # list like list(a = fig, fig) has names c("a", "") which is not NULL, and
    # would otherwise reach officer::body_add_gg(NULL) with a cryptic crash
    if (!is.list(data$figures) ||
        (length(data$figures) > 0L && (is.null(nms) || any(!nzchar(nms))))) {
      stop("'data$figures' must be a named list of ggplot objects.",
           call. = FALSE)
    }
    ok <- vapply(data$figures, function(g) inherits(g, "ggplot"), logical(1))
    if (!all(ok)) {
      stop("every element of 'data$figures' must be a ggplot object.",
           call. = FALSE)
    }
  }
  if (!is.null(data$change) && !inherits(data$change, "change_annotation")) {
    stop("'data$change' must be a change_annotation (from annotateChange()).",
         call. = FALSE)
  }
  invisible(data)
}

.quarto_available <- function() {
  requireNamespace("quarto", quietly = TRUE) && nzchar(Sys.which("quarto"))
}

#' Render a parameterized clinical report (PDF / DOCX / HTML)
#'
#' Renders a one-page, bilingual, colorblind-safe clinical report for a gait,
#' HRV or EMG assessment. PDF and HTML are produced from a parameterized Quarto
#' template (\pkg{quarto} + the Quarto CLI); DOCX is produced by an editable
#' \pkg{officer} path that needs no LaTeX toolchain
#' (\code{\link{buildDocxReport}}).
#'
#' @param data A report payload list. Recognized elements: \code{subject} (a
#'   label), \code{figures} (a named list of \code{ggplot} panels — build them
#'   with the colorblind-safe primitives, e.g.
#'   \code{\link{plotNormativeBand}} / \code{\link{clinicalGaitReport}}),
#'   \code{change} (an optional \code{\link{annotateChange}} result rendered as
#'   an MDC/MCID table) and \code{provenance} (an optional named list for the
#'   footer, e.g. from \code{metadata(pe)}).
#' @param template Report template: \code{"gait"} (default), \code{"hrv"} or
#'   \code{"emg"}.
#' @param format Output format: \code{"pdf"} (default), \code{"docx"} or
#'   \code{"html"}.
#' @param lang \code{"en"} (default) or \code{"ja"}; drives the localized
#'   headings via \code{\link{physioLabel}}.
#' @param out Output file path; defaults to a temp file named for the template
#'   and format.
#' @return The output path, invisibly.
#' @seealso [buildDocxReport()], [clinicalGaitReport()], [annotateChange()]
#' @examples
#' \dontrun{
#' fig <- plotNormativeBand(NULL,
#'   NormativeModel(sin(seq(0, pi, length.out = 101)), rep(0.1, 101), time = 0:100))
#' renderClinicalReport(list(subject = "P01", figures = list(gait_cycle = fig)),
#'                      template = "gait", format = "docx", lang = "ja")
#' }
#' @export
renderClinicalReport <- function(data, template = c("gait", "hrv", "emg"),
                                 format = c("pdf", "docx", "html"),
                                 lang = c("en", "ja"), out = NULL) {
  template <- match.arg(template)
  format <- match.arg(format)
  lang <- match.arg(lang)
  .validate_report_data(data)
  if (is.null(out)) {
    # a unique temp subdir keeps the predictable basename while avoiding
    # collisions between repeated calls with the same template/format
    d <- tempfile("clinreport")
    dir.create(d)
    out <- file.path(d, sprintf("%s_report.%s", template, format))
  }

  if (format == "docx") {
    return(buildDocxReport(data, template = template, lang = lang, out = out))
  }

  # pdf / html via a parameterized Quarto template
  if (!.quarto_available()) {
    stop("format = '", format, "' needs the 'quarto' package and the Quarto ",
         "CLI; use format = 'docx' for a LaTeX-free path.", call. = FALSE)
  }
  qmd <- system.file("quarto", sprintf("%s_report.qmd", template),
                     package = "PhysioReport")
  if (!nzchar(qmd)) {
    stop("no Quarto template for template = '", template, "'.", call. = FALSE)
  }
  data_path <- tempfile(fileext = ".rds")
  saveRDS(data, data_path)
  work <- tempfile("clinreport")
  dir.create(work)
  local_qmd <- file.path(work, basename(qmd))
  file.copy(qmd, local_qmd, overwrite = TRUE)
  quarto::quarto_render(
    input = local_qmd,
    output_format = format,
    execute_params = list(data_path = data_path, lang = lang,
                          subject = data$subject %||% ""))
  produced <- sub("\\.qmd$", paste0(".", format), local_qmd)
  if (!file.exists(produced)) {
    stop("Quarto did not produce '", basename(produced), "'.", call. = FALSE)
  }
  file.copy(produced, out, overwrite = TRUE)
  invisible(out)
}
