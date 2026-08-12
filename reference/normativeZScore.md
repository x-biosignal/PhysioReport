# Normative z-score of an observation

Standardizes an observed value (or waveform) against a
[`NormativeModel`](https://x-biosignal.github.io/PhysioReport/reference/NormativeModel.md):
\\z = (value - mean) / sd\\, element-wise. A scalar model recycles
across a vector of observations; a waveform model returns a
per-timepoint z of the same length as the observation.

## Usage

``` r
normativeZScore(value, model, age = NULL, sex = NULL, task = NULL)
```

## Arguments

- value:

  Numeric observation. A scalar, a vector of scalars (scored against a
  scalar model), or a waveform matching a waveform model's length.

- model:

  A
  [`NormativeModel`](https://x-biosignal.github.io/PhysioReport/reference/NormativeModel.md).

- age, sex, task:

  Optional strata forwarded to the model to select the applicable norm.

## Value

Numeric z-score(s), matching the length of `value` (or the waveform
length).

## See also

[`NormativeModel()`](https://x-biosignal.github.io/PhysioReport/reference/NormativeModel.md),
[`plotNormativeBand()`](https://x-biosignal.github.io/PhysioReport/reference/plotNormativeBand.md)

## Examples

``` r
m <- NormativeModel(mean = 1.30, sd = 0.15)
normativeZScore(c(1.00, 1.30, 1.60), m)
#> [1] -2  0  2
```
