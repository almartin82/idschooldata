# Get available years from Idaho SDE data

Returns the range of years for which enrollment data can be fetched from
the Idaho State Department of Education.

## Usage

``` r
get_available_years()

get_available_years()
```

## Value

Vector of available school year ends

A list with components:

- min_year:

  Earliest available year (2002)

- max_year:

  Most recent available year (2024)

- description:

  Human-readable description of the date range

## Examples

``` r
get_available_years()
#> $min_year
#> [1] 1996
#> 
#> $max_year
#> [1] 2026
#> 
#> $description
#> [1] "Idaho enrollment data is available from 1996 (1995-96 SY) to 2026 (2025-26 SY)"
#> 
```
