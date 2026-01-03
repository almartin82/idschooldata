# idschooldata: Fetch and Process Idaho School Data

Downloads and processes school data from the Idaho State Department of
Education (SDE). Provides functions for fetching enrollment data from
the SDE's public finance portal and transforming it into tidy format for
analysis.

## Main functions

- [`fetch_enr`](https://almartin82.github.io/idschooldata/reference/fetch_enr.md):

  Fetch enrollment data for a school year

- [`fetch_enr_multi`](https://almartin82.github.io/idschooldata/reference/fetch_enr_multi.md):

  Fetch enrollment data for multiple years

- [`tidy_enr`](https://almartin82.github.io/idschooldata/reference/tidy_enr.md):

  Transform wide data to tidy (long) format

- [`id_enr_aggs`](https://almartin82.github.io/idschooldata/reference/id_enr_aggs.md):

  Add aggregation level flags

- [`enr_grade_aggs`](https://almartin82.github.io/idschooldata/reference/enr_grade_aggs.md):

  Create grade-level aggregations

## Cache functions

- [`cache_status`](https://almartin82.github.io/idschooldata/reference/cache_status.md):

  View cached data files

- [`clear_cache`](https://almartin82.github.io/idschooldata/reference/clear_cache.md):

  Remove cached data files

## ID System

Idaho uses a unique identification system:

- District IDs: 3 digits (e.g., 001 = Boise Independent District)

- Building IDs: Varies by source - typically district ID + building
  number

## Data Sources

Data is sourced from the Idaho State Department of Education:

- SDE Finance Portal:
  <https://www.sde.idaho.gov/finance-transparency/public-school-finance/>

- Historical Enrollment:
  <https://www.sde.idaho.gov/finance/files/attendance-enrollment/historical/>

## Data Eras

Idaho enrollment data has evolved over time:

- Era 1 (2002-2010): Legacy format with limited demographics

- Era 2 (2011-2024): Current format with race/ethnicity breakdowns

- Note: Demographic data (race/ethnicity) only available from 2011
  onward

## See also

Useful links:

- <https://almartin82.github.io/idschooldata>

- <https://github.com/almartin82/idschooldata>

- Report bugs at <https://github.com/almartin82/idschooldata/issues>

## Author

**Maintainer**: Al Martin <almartin@example.com>
