# Changelog

## PhysioReport 0.1.1

- Fixed DOCX report generation under current `officer`/`rvg`: `rvg`
  removed editable vector (DrawingML) graphics for Word bodies
  ([`rvg::dml()`](https://davidgohel.github.io/rvg/reference/dml.html)
  is now PowerPoint/Excel-only, `body_add_vg()` is defunct), so
  [`officer::body_add()`](https://davidgohel.github.io/officer/reference/body_add.html)
  had no method for the `dml` object. Plots are now embedded with
  officer’s supported `body_add_gg()` (rasterised image). Fixes the docx
  render test.

## PhysioReport 0.1.0

Initial release as a standalone package in the x-biosignal physiological
signal ecosystem. PhysioReport provides parameterized, bilingual,
colorblind-safe building blocks for clinical reports (gait, HRV, EMG)
with normative overlays and MDC/MCID-annotated change.

### New Features

- Bilingual (Japanese / English) report labels via
  [`physioLabel()`](https://x-biosignal.github.io/PhysioReport/reference/physioLabel.md),
  which resolves a label key to its localized string. The dictionary
  lives in a UTF-8 data file (`inst/extdata/labels.csv`), keeping the R
  source ASCII, and unknown keys fall back to the key itself so partial
  dictionaries never break a report.
- Clinical agreement visualization with
  [`plotBlandAltman()`](https://x-biosignal.github.io/PhysioReport/reference/plotBlandAltman.md):
  draws a Bland-Altman plot (mean vs. difference of paired measurements)
  with bias and limit-of-agreement reference lines. Statistics are
  computed by
  [`PhysioCore::blandAltman()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/blandAltman.html),
  so the plotted lines exactly match the returned bias and limits of
  agreement, and labels/axes are localized through
  [`physioLabel()`](https://x-biosignal.github.io/PhysioReport/reference/physioLabel.md).

### Documentation

- Consistent, accessible report styling via
  [`reportTheme()`](https://x-biosignal.github.io/PhysioReport/reference/reportTheme.md),
  a thin wrapper around the shared colorblind-safe
  [`PhysioCore::theme_physio()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/theme_physio.html)
  so every report uses the same ecosystem theme and palette.
