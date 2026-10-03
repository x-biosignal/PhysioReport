# Adapt a longitudinal tracker to timeline data

Converts a longitudinal-tracking result into the `sessions` / `outcomes`
data frames consumed by
[`longitudinalTimeline`](https://x-biosignal.github.io/PhysioReport/reference/longitudinalTimeline.md).

## Usage

``` r
as.timelineData(x, ...)

# Default S3 method
as.timelineData(x, ...)

# S3 method for class 'MSKLongitudinalTracker'
as.timelineData(x, ...)
```

## Arguments

- x:

  A tracker object (e.g. a `MSKLongitudinalTracker` from
  [`PhysioMSKNet::mskLongitudinalTracker()`](https://x-biosignal.github.io/PhysioMSKNet/reference/mskLongitudinalTracker.html)).

- ...:

  Unused.

## Value

A list with `sessions` and `outcomes` data frames.

## See also

[`longitudinalTimeline()`](https://x-biosignal.github.io/PhysioReport/reference/longitudinalTimeline.md)

## Examples

``` r
# A tracker is any object carrying $metrics_table and $timepoint_labels;
# build a minimal one directly so the adapter runs without PhysioMSKNet.
tracker <- structure(
  list(metrics_table = data.frame(
         timepoint = rep(c("wk0", "wk6"), each = 2),
         muscle = rep(c("biceps", "triceps"), 2),
         metric_name = "rms",
         value = c(0.10, 0.08, 0.14, 0.12)),
       timepoint_labels = c("wk0", "wk6")),
  class = "MSKLongitudinalTracker")
td <- as.timelineData(tracker)
td$outcomes
#>   time      metric value
#> 1    1  biceps rms  0.10
#> 2    1 triceps rms  0.08
#> 3    2  biceps rms  0.14
#> 4    2 triceps rms  0.12
```
