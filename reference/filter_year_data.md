# Filter historical data to a specific year

The historical enrollment file has years as columns. This function
identifies the correct year column and filters/pivots as needed.

## Usage

``` r
filter_year_data(df, end_year)
```

## Arguments

- df:

  Data frame from historical file

- end_year:

  The school year end to filter to

## Value

Data frame filtered to the requested year
