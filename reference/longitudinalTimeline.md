# Longitudinal patient timeline (swimlane)

Draws a longitudinal rehabilitation timeline: each outcome measure is a
stacked lane showing its trajectory across sessions, intervention
periods are shaded spans across all lanes, and points where the
session-to-session change crosses the Minimal Detectable Change /
Minimal Clinically Important Difference are marked (via
[`annotateChange`](https://x-biosignal.github.io/PhysioReport/reference/annotateChange.md)).

## Usage

``` r
longitudinalTimeline(
  sessions,
  interventions = NULL,
  outcomes,
  mdc = NULL,
  mcid = NULL
)
```

## Arguments

- sessions:

  A `data.frame` of session timepoints with a `time` column (numeric or
  `Date`) and an optional `label`; drawn as light session reference
  lines.

- interventions:

  Optional `data.frame` of intervention periods with `start` and `end`
  columns (and an optional `label`); drawn as shaded spans behind every
  lane.

- outcomes:

  A long `data.frame` of outcome measurements with columns `time`,
  `metric` and `value` (one lane per `metric`).

- mdc, mcid:

  Optional MDC / MCID thresholds used to flag crossings: a scalar
  applied to all metrics, or a value named by metric. Both must be
  supplied to draw crossing markers.

## Value

A `ggplot` object (faceted, one lane per metric).

## See also

[`annotateChange()`](https://x-biosignal.github.io/PhysioReport/reference/annotateChange.md),
[`as.timelineData()`](https://x-biosignal.github.io/PhysioReport/reference/as.timelineData.md)

## Examples

``` r
sessions <- data.frame(time = 1:5)
outcomes <- data.frame(time = rep(1:5, 2),
  metric = rep(c("gait_speed", "fma"), each = 5),
  value = c(0.6, 0.7, 0.9, 1.0, 1.1, 20, 22, 28, 30, 33))
longitudinalTimeline(sessions, outcomes = outcomes,
  mdc = c(gait_speed = 0.1, fma = 5), mcid = c(gait_speed = 0.15, fma = 9))
```
