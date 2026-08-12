# Build an editable DOCX clinical report (officer)

Renders a one-page clinical report to an editable Word document using
officer (with flextable when available) — no LaTeX toolchain required.
Called by
[`renderClinicalReport`](https://x-biosignal.github.io/PhysioReport/reference/renderClinicalReport.md)
for `format = "docx"`; usable directly.

## Usage

``` r
buildDocxReport(
  data,
  template = c("gait", "hrv", "emg"),
  lang = c("en", "ja"),
  out
)
```

## Arguments

- data:

  A report payload list (see
  [`renderClinicalReport`](https://x-biosignal.github.io/PhysioReport/reference/renderClinicalReport.md)):
  `subject`, `figures` (a named list of `ggplot`s), `change` (an
  optional `change_annotation`) and `provenance` (an optional named
  list).

- template:

  One of `"gait"`, `"hrv"`, `"emg"` (drives the localized title).

- lang:

  `"en"` or `"ja"`.

- out:

  Output `.docx` path.

## Value

`out`, invisibly.

## See also

[`renderClinicalReport()`](https://x-biosignal.github.io/PhysioReport/reference/renderClinicalReport.md)
