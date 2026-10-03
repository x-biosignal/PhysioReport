#' Bilingual (Japanese / English) label lookup for reports
#'
#' Resolves a report label key to its localized string. Unknown keys fall back
#' to the key itself, so partial dictionaries never break a report. Labels live
#' in \code{inst/extdata/labels.csv} (UTF-8), keeping the R source ASCII.
#'
#' @param key Character label key (e.g. \code{"bias"}).
#' @param lang Language: \code{"en"} (default) or \code{"ja"}.
#' @return The localized label string.
#' @examples
#' physioLabel("bias")
#' physioLabel("bias", "ja")
#' @importFrom utils read.csv
#' @export
physioLabel <- function(key, lang = c("en", "ja")) {
  lang <- match.arg(lang)
  dict <- .physioLabels()
  row <- dict[dict$key == key, , drop = FALSE]
  if (nrow(row) == 0L) return(key)
  row[[lang]][1L]
}

# Cached label table loaded from the UTF-8 data file.
.physioLabels <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      f <- system.file("extdata", "labels.csv", package = "PhysioReport")
      # encoding= (not fileEncoding=) reads the raw bytes and marks strings as
      # UTF-8. fileEncoding= re-encodes into the native locale, which drops every
      # row after the first multibyte (Japanese) cell under a non-UTF-8 locale
      # (C/POSIX on many CI runners, minimal containers, and R CMD check).
      cache <<- read.csv(f, stringsAsFactors = FALSE, encoding = "UTF-8")
    }
    cache
  }
})
