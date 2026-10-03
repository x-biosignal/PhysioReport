make_report_payload <- function() {
  fig <- plotNormativeBand(NULL, NormativeModel(
    sin(seq(0, pi, length.out = 101)), rep(0.1, 101), time = 0:100))
  ch <- annotateChange(c(fma = 20, pain = 7), c(fma = 31, pain = 4),
                       mdc = c(5.2, 1), mcid = c(9, 2),
                       direction = c("increase", "decrease"))
  list(subject = "P01", figures = list(gait_cycle = fig), change = ch,
       provenance = list(device = "Vicon"))
}

# read the concatenated text of a .docx body (word/document.xml)
docx_body_text <- function(path) {
  d <- tempfile()
  utils::unzip(path, files = "word/document.xml", exdir = d)
  paste(readLines(file.path(d, "word", "document.xml"), warn = FALSE,
                  encoding = "UTF-8"), collapse = "")
}

test_that("renderClinicalReport validates the payload", {
  expect_error(renderClinicalReport(list(figures = list(1)), format = "docx"),
               "ggplot")
  expect_error(renderClinicalReport(list(change = 1), format = "docx"),
               "change_annotation")
  expect_error(renderClinicalReport("notalist", format = "docx"), "list")
  # a partially-named figures list must be rejected up front (not crash later)
  fig <- plotNormativeBand(NULL, NormativeModel(1:5, 1, time = 1:5))
  expect_error(
    renderClinicalReport(list(figures = list(a = fig, fig)), format = "docx"),
    "named list")
})

test_that("pdf/html without the Quarto CLI fail with a clear message", {
  skip_if(.quarto_available())
  data <- make_report_payload()
  expect_error(renderClinicalReport(data, format = "html"), "[Qq]uarto")
  expect_error(renderClinicalReport(data, format = "pdf"), "[Qq]uarto")
})

test_that("localized titles and the provenance footer resolve", {
  expect_equal(.report_title("gait", "en"), "Gait report")
  expect_equal(.report_title("hrv", "ja"), physioLabel("hrv_report", "ja"))
  expect_false(identical(.report_title("emg", "en"), .report_title("emg", "ja")))
  prov <- .report_provenance(list(device = "Vicon"))
  expect_match(prov, "PhysioReport")
  expect_match(prov, "Vicon")
  # no provenance list still yields versions + date
  expect_match(.report_provenance(NULL), "PhysioReport")
})

test_that("a Quarto template ships for every modality", {
  for (t in c("gait", "hrv", "emg")) {
    expect_true(nzchar(system.file("quarto", paste0(t, "_report.qmd"),
                                   package = "PhysioReport")))
  }
})

test_that("buildDocxReport writes a non-empty, localized .docx (en and ja)", {
  skip_if_not_installed("officer")
  data <- make_report_payload()

  out_en <- tempfile(fileext = ".docx")
  expect_invisible(buildDocxReport(data, "gait", "en", out_en))
  expect_gt(file.size(out_en), 0)
  body_en <- docx_body_text(out_en)
  expect_match(body_en, "Gait report")
  expect_true(grepl("[<]", body_en) && grepl("w:document", body_en))  # valid OOXML

  out_ja <- tempfile(fileext = ".docx")
  buildDocxReport(data, "gait", "ja", out_ja)
  body_ja <- docx_body_text(out_ja)
  expect_match(body_ja, physioLabel("gait_report", "ja"))   # localized heading
  expect_match(body_ja, physioLabel("subject", "ja"))
})

test_that("renderClinicalReport(format='docx') dispatches to the officer path", {
  skip_if_not_installed("officer")
  data <- make_report_payload()
  out <- tempfile(fileext = ".docx")
  res <- renderClinicalReport(data, template = "gait", format = "docx",
                              lang = "en", out = out)
  expect_identical(res, out)
  expect_gt(file.size(out), 0)
  # default out path is derived from template + format
  res2 <- renderClinicalReport(data, template = "emg", format = "docx")
  expect_match(res2, "emg_report\\.docx$")
  expect_gt(file.size(res2), 0)
})
