# Render a parameterized clinical report (PDF / DOCX / HTML)

Renders a one-page, bilingual, colorblind-safe clinical report for a
gait, HRV or EMG assessment. PDF and HTML are produced from a
parameterized Quarto template (quarto + the Quarto CLI); DOCX is
produced by an editable officer path that needs no LaTeX toolchain
([`buildDocxReport`](https://x-biosignal.github.io/PhysioReport/reference/buildDocxReport.md)).

## Usage

``` r
renderClinicalReport(
  data,
  template = c("gait", "hrv", "emg"),
  format = c("pdf", "docx", "html"),
  lang = c("en", "ja"),
  out = NULL
)
```

## Arguments

- data:

  A report payload list. Recognized elements: `subject` (a label),
  `figures` (a named list of `ggplot` panels — build them with the
  colorblind-safe primitives, e.g.
  [`plotNormativeBand`](https://x-biosignal.github.io/PhysioReport/reference/plotNormativeBand.md)
  /
  [`clinicalGaitReport`](https://x-biosignal.github.io/PhysioReport/reference/clinicalGaitReport.md)),
  `change` (an optional
  [`annotateChange`](https://x-biosignal.github.io/PhysioReport/reference/annotateChange.md)
  result rendered as an MDC/MCID table) and `provenance` (an optional
  named list for the footer, e.g. from `metadata(pe)`).

- template:

  Report template: `"gait"` (default), `"hrv"` or `"emg"`.

- format:

  Output format: `"pdf"` (default), `"docx"` or `"html"`.

- lang:

  `"en"` (default) or `"ja"`; drives the localized headings via
  [`physioLabel`](https://x-biosignal.github.io/PhysioReport/reference/physioLabel.md).

- out:

  Output file path; defaults to a temp file named for the template and
  format.

## Value

The output path, invisibly.

## See also

[`buildDocxReport()`](https://x-biosignal.github.io/PhysioReport/reference/buildDocxReport.md),
[`clinicalGaitReport()`](https://x-biosignal.github.io/PhysioReport/reference/clinicalGaitReport.md),
[`annotateChange()`](https://x-biosignal.github.io/PhysioReport/reference/annotateChange.md)

## Examples

``` r
if (FALSE) { # \dontrun{
fig <- plotNormativeBand(NULL,
  NormativeModel(sin(seq(0, pi, length.out = 101)), rep(0.1, 101), time = 0:100))
renderClinicalReport(list(subject = "P01", figures = list(gait_cycle = fig)),
                     template = "gait", format = "docx", lang = "ja")
} # }
```
