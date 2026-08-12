# Multi-domain outcome radar (spider) plot

Plots a rehabilitation outcome profile across domains as a radar chart,
with an optional normative reference polygon and multi-timepoint
overlay. Uses the ecosystem colorblind-safe palette and report theme.

## Usage

``` r
plotOutcomeRadar(
  profile,
  reference = NULL,
  normalize = c("percent", "z"),
  domains = NULL
)
```

## Arguments

- profile:

  Domain scores: a named numeric vector (one timepoint), a matrix or
  data.frame with domains as columns and timepoints as rows, or a
  `MSKFunctionalOutcome` (from
  [`PhysioMSKNet::mskPredictFunctionalOutcome()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskPredictFunctionalOutcome.html)),
  whose aggregate ROM / strength / function become the domains.

- reference:

  Optional normative reference: a named numeric of per-domain means (for
  `"percent"`), or a data.frame with `domain`, `mean` and `sd` columns
  (required for `"z"`). Drawn as a reference polygon.

- normalize:

  `"percent"` (each domain as a percentage of its reference mean;
  reference polygon at 100) or `"z"` (z-score versus the reference;
  reference polygon centered at 0).

- domains:

  Optional character vector selecting and ordering the domains.

## Value

A `ggplot` object (a `coord_polar` radar).

## See also

[`plotNormativeBand()`](https://x-biosignal.github.io/PhysioReport/reference/plotNormativeBand.md)

## Examples

``` r
plotOutcomeRadar(c(pain = 3, balance = 7, gait = 6, strength = 5))
```
