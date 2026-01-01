# Tidy enrollment data

Transforms wide enrollment data to long format with subgroup column.

## Usage

``` r
tidy_enr(df)
```

## Arguments

- df:

  A wide data.frame of processed enrollment data

## Value

A long data.frame of tidied enrollment data

## Examples

``` r
if (FALSE) { # \dontrun{
wide_data <- fetch_enr(2024, tidy = FALSE)
tidy_data <- tidy_enr(wide_data)
} # }
```
