# Single-case (SCED) effect-size summary

Summarises the nonoverlap / trend effect sizes for a two-phase (A/B)
single- case series, delegating to the peer-reviewed estimators in
PhysioClinStats: the Percentage of Non-overlapping Data (as a
percentage), the Nonoverlap of All Pairs, and the
baseline-trend-corrected Tau-U in its bounded tau-b (`"scan"`) form.

## Usage

``` r
scedStats(data, phase, improvement = c("increase", "decrease"))
```

## Arguments

- data:

  Numeric vector of observations, in session order.

- phase:

  Vector of phase labels the same length as `data`; the first two phases
  (in order of appearance) are taken as A (baseline) and B
  (intervention).

- improvement:

  `"increase"` (default) if higher scores are better, or `"decrease"` if
  lower scores are the goal.

## Value

A `data.frame` of class `"sced_stats"` with columns `metric` and
`estimate` (PND in \[0, 100\], NAP in \[0, 1\], Tau-U in \[-1, 1\]).

## References

Parker RI, Vannest KJ (2011). Tau-U. Behavior Therapy; Scruggs et al.
(1987) PND; Parker & Vannest (2009) NAP.

## See also

[`plotSCED()`](https://x-biosignal.github.io/PhysioReport/reference/plotSCED.md),
[`PhysioClinStats::scedTauU()`](https://x-biosignal.github.io/PhysioClinStats/reference/scedTauU.html)

## Examples

``` r
if (FALSE) { # \dontrun{
scedStats(c(2, 3, 2, 3, 6, 7, 8, 7), rep(c("A", "B"), each = 4))
} # }
```
