# Plot an observation against a normative band

Draws a normative corridor as graded \\\pm1\\SD and \\\pm2\\SD ribbons
around the reference median, overlays the observed trajectory, and
annotates the z-score. Uses the ecosystem colorblind-safe palette and
report theme.

## Usage

``` r
plotNormativeBand(
  observed = NULL,
  model,
  bands = c(1, 2),
  time_axis = NULL,
  annotate_z = TRUE,
  age = NULL,
  sex = NULL,
  task = NULL,
  ...
)
```

## Arguments

- observed:

  Numeric observation (a waveform, or a scalar broadcast across the
  corridor). `NULL` draws just the corridor (no observed line and no z
  annotation), so callers can overlay their own traces (e.g.
  left/right); for a scalar model this requires `time_axis` to set the x
  extent.

- model:

  A
  [`NormativeModel`](https://x-biosignal.github.io/PhysioReport/reference/NormativeModel.md).

- bands:

  Numeric vector of SD multiples to shade (default `c(1, 2)`); one
  `geom_ribbon` layer per band, widest drawn first.

- time_axis:

  Optional numeric x-axis; defaults to the model's `time` or the sample
  index.

- annotate_z:

  Logical; if `TRUE` (default) annotate the (max absolute) z-score.

- age, sex, task:

  Optional strata forwarded to the model.

- ...:

  Currently unused (reserved for future styling arguments).

## Value

A `ggplot` object.

## See also

[`NormativeModel()`](https://x-biosignal.github.io/PhysioReport/reference/NormativeModel.md),
[`normativeZScore()`](https://x-biosignal.github.io/PhysioReport/reference/normativeZScore.md)

## Examples

``` r
# \donttest{
wf <- NormativeModel(mean = sin(seq(0, pi, length.out = 101)),
                     sd = rep(0.1, 101), time = 0:100)
obs <- sin(seq(0, pi, length.out = 101)) + rnorm(101, 0, 0.05)
plotNormativeBand(obs, wf)

# }
```
