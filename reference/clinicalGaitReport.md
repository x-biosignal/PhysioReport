# Clinical gait report dashboard

Composes a multi-panel clinical gait report: one waveform panel per gait
variable (a colorblind-safe normative \\\pm\\SD corridor from
[`plotNormativeBand`](https://x-biosignal.github.io/PhysioReport/reference/plotNormativeBand.md)
overlaid with the subject's Left and Right mean traces and optional
event markers), followed by a gait-index dashboard (GDI / GPS / Movement
Analysis Profile). Panels are laid out with patchwork.

## Usage

``` r
clinicalGaitReport(
  pe,
  norm,
  events = NULL,
  sides = c("L", "R"),
  indices = TRUE
)
```

## Arguments

- pe:

  A named list of per-variable side-split cycle waveforms:
  `pe[[variable]]` is a list with `$left` and `$right`, each a numeric
  cycle waveform or a points-by-cycles matrix (averaged across cycles).
  Variables are matched to `norm$variables` by name; kinetic variables
  (moments/power) can be included when `norm` carries their corridors.

- norm:

  A `gait_norm`-like list (e.g. from
  [`PhysioGaitNorm::loadGaitNorm()`](https://x-biosignal.r-universe.dev/PhysioGaitNorm/reference/loadGaitNorm.html))
  with `$variables`, row-named `$mean` and `$sd` matrices (variables x
  cycle points), and optionally `$percent` and `$features` (for the
  GDI).

- events:

  Optional numeric vector of gait-cycle percentages at which to draw
  event markers (e.g. toe-off) on every waveform panel.

- sides:

  Which sides to overlay (currently informational; both Left and Right
  are drawn).

- indices:

  Logical; if `TRUE` (default) append the gait-index dashboard panel
  (requires PhysioMoCap and all norm variables present in `pe`); omitted
  with a warning if it cannot be computed.

## Value

A patchwork composite (a `ggplot`-compatible object).

## See also

[`gaitIndexDashboard()`](https://x-biosignal.github.io/PhysioReport/reference/gaitIndexDashboard.md),
[`plotNormativeBand()`](https://x-biosignal.github.io/PhysioReport/reference/plotNormativeBand.md),
[`PhysioMoCap::plotSymmetry()`](https://x-biosignal.r-universe.dev/PhysioMoCap/reference/plotSymmetry.html)

## Examples

``` r
# \donttest{
# see the package tests for a synthetic gait fixture
# }
```
