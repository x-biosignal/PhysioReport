# Forest-style plot of annotated pre-to-post changes

Draws one row per metric showing the signed change as a point, with the
\\\pm\\MDC and \\\pm\\MCID thresholds as symmetric reference bands
around the no-change line, coloured by the change classification.

## Usage

``` r
plotChangeAnnotated(changes)
```

## Arguments

- changes:

  A `"change_annotation"` object from
  [`annotateChange`](https://x-biosignal.github.io/PhysioReport/reference/annotateChange.md).

## Value

A `ggplot` object.

## See also

[`annotateChange()`](https://x-biosignal.github.io/PhysioReport/reference/annotateChange.md)

## Examples

``` r
# \donttest{
ch <- annotateChange(c(fma = 20, pain = 7), c(fma = 31, pain = 4),
                     mdc = c(5.2, 1.0), mcid = c(9, 2),
                     direction = c("increase", "decrease"))
plotChangeAnnotated(ch)

# }
```
