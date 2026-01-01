# Clear the idschooldata cache

Removes cached data files.

## Usage

``` r
clear_cache(end_year = NULL, type = NULL)
```

## Arguments

- end_year:

  Optional school year to clear. If NULL, clears all years.

- type:

  Optional data type to clear. If NULL, clears all types.

## Value

Invisibly returns the number of files removed

## Examples

``` r
if (FALSE) { # \dontrun{
# Clear all cached data
clear_cache()

# Clear only 2024 data
clear_cache(2024)

# Clear only tidy format data
clear_cache(type = "tidy")
} # }
```
