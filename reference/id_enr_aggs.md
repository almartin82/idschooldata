# Identify enrollment aggregation levels

Adds boolean flags to identify state, district, and campus level
records.

## Usage

``` r
id_enr_aggs(df)
```

## Arguments

- df:

  Enrollment dataframe, output of tidy_enr

## Value

data.frame with boolean aggregation flags

## Examples

``` r
if (FALSE) { # \dontrun{
tidy_data <- fetch_enr(2024)
# Data already has aggregation flags via id_enr_aggs
table(tidy_data$is_state, tidy_data$is_district, tidy_data$is_campus)
} # }
```
