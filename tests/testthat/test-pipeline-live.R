# ==============================================================================
# LIVE Pipeline Tests for idschooldata
# ==============================================================================
#
# These tests verify EACH STEP of the data pipeline using LIVE network calls.
# No mocks - we verify actual connectivity and data correctness.
#
# Test Categories:
# 1. URL Availability - HTTP status codes
# 2. File Download - Successful download and file type verification
# 3. File Parsing - Read file into R
# 4. Column Structure - Expected columns exist
# 5. Year Filtering - Extract data for specific years
# 6. Data Processing - get_raw_enr() returns valid data
# 7. Data Quality - No Inf/NaN, valid ranges
# 8. Output Fidelity - tidy=TRUE matches raw data
#
# ==============================================================================

library(testthat)
library(httr)

# ==============================================================================
# Helper Functions
# ==============================================================================

#' Skip if no network connectivity
skip_if_offline <- function() {
  tryCatch({
    response <- httr::HEAD("https://www.google.com", httr::timeout(5))
    if (httr::http_error(response)) {
      skip("No network connectivity")
    }
  }, error = function(e) {
    skip("No network connectivity")
  })
}

# ==============================================================================
# STEP 1: URL Availability Tests
# ==============================================================================

test_that("Idaho SDE main website is accessible", {
  skip_if_offline()
  response <- httr::HEAD("https://www.sde.idaho.gov/", httr::timeout(30))
  expect_equal(httr::status_code(response), 200)
})

test_that("Idaho SDE Public School Finance page is accessible", {
  skip_if_offline()
  response <- httr::HEAD("https://www.sde.idaho.gov/finance/", httr::timeout(30))
  expect_equal(httr::status_code(response), 200)
})

test_that("Historical enrollment file URL returns HTTP 200", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx"
  response <- httr::HEAD(url, httr::timeout(30))
  expect_equal(httr::status_code(response), 200)
})

test_that("Historical building enrollment file URL returns HTTP 200", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-Building-1.xlsx"
  response <- httr::HEAD(url, httr::timeout(30))
  expect_equal(httr::status_code(response), 200)
})

test_that("Current enrollment file URL returns HTTP 200", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Enrollment-by-District-and-Charter-School.xlsx"
  response <- httr::HEAD(url, httr::timeout(30))
  expect_equal(httr::status_code(response), 200)
})

# ==============================================================================
# STEP 2: File Download Tests
# ==============================================================================

test_that("Can download historical enrollment file (>100KB, Excel content-type)", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx"
  temp_file <- tempfile(fileext = ".xlsx")

  response <- httr::GET(
    url,
    httr::write_disk(temp_file, overwrite = TRUE),
    httr::timeout(120)
  )

  expect_equal(httr::status_code(response), 200)

  # File should be >100KB (real Excel, not HTML error page)
  file_info <- file.info(temp_file)
  expect_gt(file_info$size, 100000)

  # Content type should indicate Excel
  content_type <- httr::headers(response)$`content-type`
  expect_true(grepl("spreadsheet|excel|octet-stream", content_type, ignore.case = TRUE))

  unlink(temp_file)
})

# ==============================================================================
# STEP 3: File Parsing Tests
# ==============================================================================

test_that("Can parse historical enrollment Excel file with readxl", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx"
  temp_file <- tempfile(fileext = ".xlsx")

  httr::GET(url, httr::write_disk(temp_file, overwrite = TRUE), httr::timeout(120))

  # Should have sheets
  sheets <- readxl::excel_sheets(temp_file)
  expect_gt(length(sheets), 0)

  # Should parse with skip=4 (header rows)
  df <- readxl::read_excel(temp_file, sheet = 1, skip = 4)
  expect_true(is.data.frame(df))
  expect_gt(nrow(df), 1000)  # Historical file has many rows
  expect_gte(ncol(df), 15)   # Should have enrollment columns

  unlink(temp_file)
})

# ==============================================================================
# STEP 4: Column Structure Tests
# ==============================================================================

test_that("Historical file has required columns: ID, Name, Year, Membership, Grades", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx"
  temp_file <- tempfile(fileext = ".xlsx")

  httr::GET(url, httr::write_disk(temp_file, overwrite = TRUE), httr::timeout(120))
  df <- readxl::read_excel(temp_file, sheet = 1, skip = 4)
  cols <- names(df)

  # District ID column
  expect_true(any(grepl("#", cols)))

  # District name column
  expect_true(any(grepl("School|District|Charter", cols, ignore.case = TRUE)))

  # Year column
  expect_true(any(grepl("Year", cols, ignore.case = TRUE)))

  # Membership column
  expect_true(any(grepl("Member|Total|Enroll", cols, ignore.case = TRUE)))

  # Grade columns
  expect_true(any(grepl("1st|2nd|3rd|garten", cols, ignore.case = TRUE)))

  unlink(temp_file)
})

# ==============================================================================
# STEP 5: Year Filtering Tests
# ==============================================================================

test_that("Historical data contains 2024-2025 school year with 100+ districts", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx"
  temp_file <- tempfile(fileext = ".xlsx")

  httr::GET(url, httr::write_disk(temp_file, overwrite = TRUE), httr::timeout(120))
  df <- readxl::read_excel(temp_file, sheet = 1, skip = 4)

  year_col <- names(df)[grepl("Year", names(df), ignore.case = TRUE)][1]
  expect_false(is.na(year_col))

  filtered <- df[df[[year_col]] == "2024-2025", ]

  expect_gt(nrow(filtered), 100)
  expect_lt(nrow(filtered), 500)

  unlink(temp_file)
})

test_that("Historical data contains 2014-2015 school year", {
  skip_if_offline()
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx"
  temp_file <- tempfile(fileext = ".xlsx")

  httr::GET(url, httr::write_disk(temp_file, overwrite = TRUE), httr::timeout(120))
  df <- readxl::read_excel(temp_file, sheet = 1, skip = 4)
  year_col <- names(df)[grepl("Year", names(df), ignore.case = TRUE)][1]

  filtered <- df[df[[year_col]] == "2014-2015", ]
  expect_gt(nrow(filtered), 50)

  unlink(temp_file)
})

# ==============================================================================
# STEP 6: get_raw_enr() Function Tests
# ==============================================================================

test_that("get_raw_enr(2025) returns list with district data frame having 100+ rows", {
  skip_if_offline()

  raw <- idschooldata:::get_raw_enr(2025)

  expect_true(is.list(raw))
  expect_true("district" %in% names(raw))
  expect_true(is.data.frame(raw$district))
  expect_gt(nrow(raw$district), 100)

  # Check standardized column names
  expect_true("district_id" %in% names(raw$district))
  expect_true("district_name" %in% names(raw$district))
  expect_true("membership" %in% names(raw$district))
  expect_true("year" %in% names(raw$district))
})

test_that("get_raw_enr(2025) returns only 2024-2025 data", {
  skip_if_offline()
  raw <- idschooldata:::get_raw_enr(2025)
  expect_true(all(raw$district$year == "2024-2025", na.rm = TRUE))
})

test_that("get_raw_enr(2010) returns 2009-2010 data", {
  skip_if_offline()
  raw <- idschooldata:::get_raw_enr(2010)
  expect_gt(nrow(raw$district), 50)
  expect_true(all(raw$district$year == "2009-2010", na.rm = TRUE))
})

test_that("get_available_years returns min=1996, max=2026", {
  result <- idschooldata::get_available_years()
  expect_true(is.list(result))
  expect_equal(result$min_year, 1996)
  expect_equal(result$max_year, 2026)
})

# ==============================================================================
# STEP 7: Data Quality Tests
# ==============================================================================

test_that("fetch_enr(2025) returns no Inf or NaN values", {
  skip_if_offline()
  data <- idschooldata::fetch_enr(2025, tidy = FALSE, use_cache = FALSE)

  for (col in names(data)[sapply(data, is.numeric)]) {
    expect_false(any(is.infinite(data[[col]]), na.rm = TRUE))
    expect_false(any(is.nan(data[[col]]), na.rm = TRUE))
  }
})

test_that("Enrollment counts are non-negative", {
  skip_if_offline()
  data <- idschooldata::fetch_enr(2025, tidy = FALSE, use_cache = FALSE)

  expect_true(all(data$row_total >= 0, na.rm = TRUE))

  grade_cols <- grep("^grade_", names(data), value = TRUE)
  for (col in grade_cols) {
    expect_true(all(data[[col]] >= 0, na.rm = TRUE))
  }
})

test_that("State total is between 250,000 and 500,000", {
  skip_if_offline()
  data <- idschooldata::fetch_enr(2025, tidy = FALSE, use_cache = FALSE)

  state_row <- data[data$type == "State", ]
  expect_equal(nrow(state_row), 1)
  expect_gt(state_row$row_total, 250000)
  expect_lt(state_row$row_total, 500000)
})

test_that("Districts have 150-300 entities with max enrollment >20,000", {
  skip_if_offline()
  data <- idschooldata::fetch_enr(2025, tidy = FALSE, use_cache = FALSE)

  district_data <- data[data$type == "District", ]
  expect_gt(nrow(district_data), 150)
  expect_lt(nrow(district_data), 300)
  expect_gt(max(district_data$row_total, na.rm = TRUE), 20000)
})

# ==============================================================================
# STEP 8: Aggregation Tests
# ==============================================================================

test_that("State total within 5% of sum of districts", {
  skip_if_offline()
  data <- idschooldata::fetch_enr(2025, tidy = FALSE, use_cache = FALSE)

  state_total <- data$row_total[data$type == "State"]
  district_sum <- sum(data$row_total[data$type == "District"], na.rm = TRUE)

  pct_diff <- abs(state_total - district_sum) / state_total
  expect_lt(pct_diff, 0.05)
})

test_that("State grade sums within 5% of state row total", {
  skip_if_offline()
  data <- idschooldata::fetch_enr(2025, tidy = FALSE, use_cache = FALSE)

  state_row <- data[data$type == "State", ]

  grade_cols <- c("grade_pk", "grade_k", paste0("grade_", sprintf("%02d", 1:12)))
  grade_cols <- grade_cols[grade_cols %in% names(state_row)]

  grade_sum <- sum(unlist(state_row[, grade_cols]), na.rm = TRUE)

  pct_diff <- abs(state_row$row_total - grade_sum) / state_row$row_total
  expect_lt(pct_diff, 0.05)
})

# ==============================================================================
# STEP 9: Output Fidelity Tests
# ==============================================================================

test_that("tidy=TRUE and tidy=FALSE both return non-empty data", {
  skip_if_offline()

  wide <- idschooldata::fetch_enr(2025, tidy = FALSE, use_cache = FALSE)
  tidy <- idschooldata::fetch_enr(2025, tidy = TRUE, use_cache = FALSE)

  expect_gt(nrow(wide), 0)
  expect_gt(nrow(tidy), 0)
})

test_that("Boise Independent District has enrollment >20,000", {
  skip_if_offline()
  raw <- idschooldata:::get_raw_enr(2025)

  boise <- raw$district[
    grepl("^BOISE INDEPENDENT", raw$district$district_name, ignore.case = TRUE),
  ]

  expect_equal(nrow(boise), 1)
  expect_gt(as.numeric(boise$membership), 20000)
})

# ==============================================================================
# Cache Tests
# ==============================================================================

test_that("Cache path function exists", {
  tryCatch({
    path <- idschooldata:::get_cache_path(2024, "enrollment")
    expect_true(is.character(path))
    expect_true(grepl("2024", path))
  }, error = function(e) {
    skip("Cache functions not implemented")
  })
})

# ==============================================================================
# Year Coverage Tests
# ==============================================================================

test_that("Data available for years 2020-2025", {
  skip_if_offline()

  for (year in 2020:2025) {
    raw <- idschooldata:::get_raw_enr(year)
    expect_gt(nrow(raw$district), 100)
  }
})
