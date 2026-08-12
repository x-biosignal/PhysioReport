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
  [`PhysioMSKNet::mskLongitudinalTracker()`](https://x-biosignal.r-universe.dev/PhysioMSKNet/reference/mskLongitudinalTracker.html)).

- ...:

  Unused.

## Value

A list with `sessions` and `outcomes` data frames.

## See also

[`longitudinalTimeline()`](https://x-biosignal.github.io/PhysioReport/reference/longitudinalTimeline.md)
