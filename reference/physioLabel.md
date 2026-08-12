# Bilingual (Japanese / English) label lookup for reports

Resolves a report label key to its localized string. Unknown keys fall
back to the key itself, so partial dictionaries never break a report.
Labels live in `inst/extdata/labels.csv` (UTF-8), keeping the R source
ASCII.

## Usage

``` r
physioLabel(key, lang = c("en", "ja"))
```

## Arguments

- key:

  Character label key (e.g. `"bias"`).

- lang:

  Language: `"en"` (default) or `"ja"`.

## Value

The localized label string.

## Examples

``` r
physioLabel("bias")
#> [1] "Bias"
physioLabel("bias", "ja")
#> [1] "バイアス"
```
