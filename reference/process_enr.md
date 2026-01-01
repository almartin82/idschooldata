# Process raw Idaho SDE enrollment data

Transforms raw SDE data into a standardized schema combining district
and building (campus) data.

## Usage

``` r
process_enr(raw_data, end_year)
```

## Arguments

- raw_data:

  List containing district and building data frames from get_raw_enr

- end_year:

  School year end

## Value

Processed data frame with standardized columns
