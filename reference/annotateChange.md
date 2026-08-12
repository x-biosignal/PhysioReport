# Classify pre-to-post change against MDC and MCID thresholds

Annotates a set of paired (pre, post) outcome scores against their
Minimal Detectable Change (MDC) and Minimal Clinically Important
Difference (MCID) thresholds, classifying each change as `"no change"`
(within measurement error), `"detectable (>MDC)"` (a real change that
clears measurement error) or `"clinically meaningful (>MCID)"`.
Thresholds are compared to the absolute change and are
boundary-inclusive (a change exactly equal to the MDC is
`"detectable"`). The `direction` of benefit is tracked separately so
decrease-is-good metrics (pain, timed tests) are handled correctly.

## Usage

``` r
annotateChange(pre, post, mdc, mcid, direction = "increase")
```

## Arguments

- pre, post:

  Numeric vectors of pre- and post-intervention scores (one element per
  metric); may be named to label the metrics.

- mdc, mcid:

  Numeric MDC / MCID thresholds (positive), a scalar recycled across
  metrics or a vector matching `pre`. Obtain the MDC from
  [`PhysioCore::mdc()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/mdc.html)
  (or
  [`PhysioMoCap::mdc()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/mdc.html));
  the MCID is the instrument's anchor-based value.

- direction:

  Benefit direction, `"increase"` (higher is better, default) or
  `"decrease"` (lower is better); a scalar applied to all metrics or a
  vector matching `pre`.

## Value

A `data.frame` of class `"change_annotation"` with columns `metric`,
`pre`, `post`, `change` (signed `post - pre`), `improvement` (signed so
positive = beneficial), `mdc`, `mcid`, `exceeds_mdc`, `exceeds_mcid`,
`improved`, `direction` and `classification`. A metric with a missing
`pre` or `post` yields `NA` change and classification: missingness is
propagated rather than silently reported as `"no change"`.

## References

de Vet HCW et al. (2006). Minimally important change determined by a
visual method. *Qual Life Res*; Shrout & Fleiss (1979) for the SEM
underlying MDC.

## See also

[`plotChangeAnnotated()`](https://x-biosignal.github.io/PhysioReport/reference/plotChangeAnnotated.md),
[`PhysioCore::mdc()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/mdc.html)

## Examples

``` r
annotateChange(pre = c(fma = 20, pain = 7),
               post = c(fma = 31, pain = 4),
               mdc = c(5.2, 1.0), mcid = c(9, 2),
               direction = c("increase", "decrease"))
#> <change_annotation> 2 metric(s)
#>  metric change mdc mcid                classification
#>     fma     11 5.2    9 clinically meaningful (>MCID)
#>    pain     -3 1.0    2 clinically meaningful (>MCID)
```
