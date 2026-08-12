# Bland-Altman agreement plot

Draws a Bland-Altman plot (mean vs. difference of paired measurements)
with bias and limit-of-agreement reference lines. The statistics come
from
[`PhysioCore::blandAltman()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/blandAltman.html),
so the plotted lines exactly match the computed bias and limits of
agreement.

## Usage

``` r
plotBlandAltman(x, y, confidence = 0.95)
```

## Arguments

- x, y:

  Numeric vectors of paired measurements (e.g. two methods, or baseline
  vs follow-up).

- confidence:

  Confidence level for the limits of agreement (default 0.95).

## Value

A `ggplot` object.

## Examples

``` r
# \donttest{
plotBlandAltman(c(1, 2, 3, 4, 5), c(1.1, 1.9, 3.2, 3.8, 5.1))

# }
```
