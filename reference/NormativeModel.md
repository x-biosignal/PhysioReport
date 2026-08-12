# Normative reference model (mean / SD corridor)

Builds a reusable description of a normative reference — the expected
`mean` and `sd` of a measurement, optionally stratified by covariates
such as age, sex or task. A model can be *scalar* (one mean/sd), a
*waveform* (per-timepoint mean/sd vectors, e.g. a 101-point gait-cycle
corridor), a stratified *table* (a `data.frame` with the strata columns
plus `mean`/`sd` and an optional `time` column), or a *lookup function*
`function(age, sex, task)` returning a `list(mean, sd, time)`. The
table/function forms let a normative database drive the model; when no
database is available an inline scalar/waveform/table spec degrades
gracefully to the same interface.

## Usage

``` r
NormativeModel(
  mean,
  sd = NULL,
  by = c("age", "sex", "task"),
  source = NULL,
  time = NULL
)
```

## Arguments

- mean:

  Numeric scalar or vector (the reference mean / waveform), OR a
  `data.frame` of stratified norms (must contain `mean` and `sd`
  columns, plus the `by` strata columns and an optional `time` column),
  OR a lookup `function(age, sex, task)` returning
  `list(mean=, sd=, time=)`.

- sd:

  Numeric scalar or vector of the same length as `mean` (recycled from
  length 1). Required for the numeric form; ignored for the table /
  function forms.

- by:

  Character vector naming the stratification columns/arguments (default
  `c("age", "sex", "task")`); for a `data.frame` the defaults are
  narrowed to the columns actually present.

- source:

  Optional character string describing the normative source (citation),
  used as the default plot title.

- time:

  Optional numeric vector (same length as `mean`) giving the x-axis
  (e.g. % gait cycle) for a waveform model.

## Value

An object of class `"NormativeModel"`.

## See also

[`normativeZScore()`](https://x-biosignal.github.io/PhysioReport/reference/normativeZScore.md),
[`plotNormativeBand()`](https://x-biosignal.github.io/PhysioReport/reference/plotNormativeBand.md)

## Examples

``` r
# scalar norm (e.g. comfortable gait speed for a stratum)
m <- NormativeModel(mean = 1.30, sd = 0.15, source = "Bohannon 1997")
normativeZScore(1.00, m)
#> [1] -2

# waveform norm (101-point knee-flexion corridor)
wf <- NormativeModel(mean = sin(seq(0, pi, length.out = 101)),
                     sd = rep(0.1, 101), time = 0:100)
```
