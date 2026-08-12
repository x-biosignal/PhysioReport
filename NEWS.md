# PhysioReport 0.1.1

- Fixed DOCX report generation under current `officer`/`rvg`: `rvg` removed
  editable vector (DrawingML) graphics for Word bodies (`rvg::dml()` is now
  PowerPoint/Excel-only, `body_add_vg()` is defunct), so `officer::body_add()`
  had no method for the `dml` object. Plots are now embedded with officer's
  supported `body_add_gg()` (rasterised image). Fixes the docx render test.

# PhysioReport 0.1.0

Initial release as a standalone package in the x-biosignal physiological
signal ecosystem. PhysioReport provides parameterized, bilingual,
colorblind-safe building blocks for clinical reports (gait, HRV, EMG) with
normative overlays and MDC/MCID-annotated change.

## New Features

- Bilingual (Japanese / English) report labels via `physioLabel()`, which
  resolves a label key to its localized string. The dictionary lives in a
  UTF-8 data file (`inst/extdata/labels.csv`), keeping the R source ASCII, and
  unknown keys fall back to the key itself so partial dictionaries never break
  a report.
- Clinical agreement visualization with `plotBlandAltman()`: draws a
  Bland-Altman plot (mean vs. difference of paired measurements) with bias and
  limit-of-agreement reference lines. Statistics are computed by
  `PhysioCore::blandAltman()`, so the plotted lines exactly match the returned
  bias and limits of agreement, and labels/axes are localized through
  `physioLabel()`.

## Documentation

- Consistent, accessible report styling via `reportTheme()`, a thin wrapper
  around the shared colorblind-safe `PhysioCore::theme_physio()` so every
  report uses the same ecosystem theme and palette.
