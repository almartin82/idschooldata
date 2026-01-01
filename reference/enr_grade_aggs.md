# Custom Enrollment Grade Level Aggregates

Creates aggregations for common grade groupings: K-8, 9-12 (HS), K-12.

## Usage

``` r
enr_grade_aggs(df)
```

## Arguments

- df:

  A tidy enrollment df

## Value

df of aggregated enrollment data

## Examples

``` r
if (FALSE) { # \dontrun{
tidy_data <- fetch_enr(2024)
grade_aggs <- enr_grade_aggs(tidy_data)
} # }
```
