# ==============================================================================
# Enrollment Data Fetching Functions
# ==============================================================================
#
# This file contains the main user-facing functions for downloading enrollment
# data from the Idaho State Department of Education.
#
# ==============================================================================

#' Fetch Idaho enrollment data
#'
#' Downloads and processes enrollment data from the Idaho State Department
#' of Education (SDE) public finance portal.
#'
#' @param end_year A school year. Year is the end of the academic year - eg 2023-24
#'   school year is year '2024'. Valid values are 2002-2025, though demographic
#'   breakdowns are only available from 2011 onward.
#' @param tidy If TRUE (default), returns data in long (tidy) format with subgroup
#'   column. If FALSE, returns wide format.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#'   Set to FALSE to force re-download from SDE.
#' @return Data frame with enrollment data. Wide format includes columns for
#'   district_id, campus_id, names, and enrollment counts by demographic/grade.
#'   Tidy format pivots these counts into subgroup and grade_level columns.
#' @export
#' @examples
#' \dontrun{
#' # Get 2024 enrollment data (2023-24 school year)
#' enr_2024 <- fetch_enr(2024)
#'
#' # Get wide format
#' enr_wide <- fetch_enr(2024, tidy = FALSE)
#'
#' # Force fresh download (ignore cache)
#' enr_fresh <- fetch_enr(2024, use_cache = FALSE)
#'
#' # Filter to specific district (Boise)
#' boise <- enr_2024 |>
#'   dplyr::filter(district_id == "001")
#' }
fetch_enr <- function(end_year, tidy = TRUE, use_cache = TRUE) {

  # Validate year - Idaho historical data available from 1996 (1995-96 SY) to 2026 (2025-26 SY)
  if (end_year < 1996 || end_year > 2026) {
    stop("end_year must be between 1996 and 2026")
  }

  if (end_year < 2011) {
    message("Note: Older years have grade-level data but limited demographic breakdowns")
  }

  # Determine cache type based on tidy parameter
  cache_type <- if (tidy) "tidy" else "wide"

  # Check cache first
  if (use_cache && cache_exists(end_year, cache_type)) {
    message(paste("Using cached data for", end_year))
    return(read_cache(end_year, cache_type))
  }

  # Get raw data from Idaho SDE
  raw <- get_raw_enr(end_year)

  # Process to standard schema
  processed <- process_enr(raw, end_year)

  # Optionally tidy
  if (tidy) {
    processed <- tidy_enr(processed) |>
      id_enr_aggs()
  }

  # Cache the result
  if (use_cache) {
    write_cache(processed, end_year, cache_type)
  }

  processed
}


#' Fetch enrollment data for multiple years
#'
#' Downloads and combines enrollment data for multiple school years.
#'
#' @param end_years Vector of school year ends (e.g., c(2022, 2023, 2024))
#' @param tidy If TRUE (default), returns data in long (tidy) format.
#' @param use_cache If TRUE (default), uses locally cached data when available.
#' @return Combined data frame with enrollment data for all requested years
#' @export
#' @examples
#' \dontrun{
#' # Get 3 years of data
#' enr_multi <- fetch_enr_multi(2022:2024)
#'
#' # Track enrollment trends
#' enr_multi |>
#'   dplyr::filter(is_state, subgroup == "total_enrollment", grade_level == "TOTAL") |>
#'   dplyr::select(end_year, n_students)
#' }
fetch_enr_multi <- function(end_years, tidy = TRUE, use_cache = TRUE) {

  # Validate years
  invalid_years <- end_years[end_years < 1996 | end_years > 2026]
  if (length(invalid_years) > 0) {
    stop(paste("Invalid years:", paste(invalid_years, collapse = ", "),
               "\nend_year must be between 1996 and 2026"))
  }

  # Fetch each year
  results <- purrr::map(
    end_years,
    function(yr) {
      message(paste("Fetching", yr, "..."))
      fetch_enr(yr, tidy = tidy, use_cache = use_cache)
    }
  )

  # Combine
  dplyr::bind_rows(results)
}


#' Get data availability information
#'
#' Returns information about what data is available for Idaho schools.
#'
#' @return List with availability information
#' @export
#' @examples
#' \dontrun{
#' info <- get_data_availability()
#' print(info$years)
#' print(info$demographics_available)
#' }
get_data_availability <- function() {
  list(
    state = "Idaho",
    state_abbr = "ID",
    agency = "Idaho State Department of Education",
    agency_url = "https://www.sde.idaho.gov/",

    years = list(
      enrollment_total = 1996:2026,
      enrollment_by_grade = 1996:2026,
      enrollment_by_building = 2011:2026
    ),

    data_eras = list(
      era1 = list(
        years = 1996:2010,
        description = "Historical format - enrollment by grade",
        demographics = FALSE,
        by_grade = TRUE,
        notes = "Grade-level enrollment available, limited demographics"
      ),
      era2 = list(
        years = 2011:2026,
        description = "Current format with grade and building detail",
        demographics = FALSE,
        by_grade = TRUE,
        notes = "Grade-level and building-level data available"
      )
    ),

    demographics_available = c(
      "Note: Race/ethnicity data not included in main enrollment file.",
      "Available through Idaho Report Card: https://idahoreportcard.org/"
    ),

    special_populations = c(
      "Note: ELL, Special Ed, and Free/Reduced Lunch data available through",
      "Idaho Report Card or separate SDE reporting systems"
    ),

    geographic = list(
      districts = "~115 traditional school districts",
      charters = "~60+ charter schools",
      regions = "6 education service regions"
    ),

    notes = c(
      "Enrollment counts are as of first Friday in November (official count date)",
      "Students dual-enrolled are counted once per school, once per district",
      "Private and homeschool students are excluded",
      "Data goes back to 1995-96 school year (end_year = 1996)"
    ),

    data_sources = c(
      "Historical Enrollment: https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx",
      "Building Enrollment: https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-Building-1.xlsx",
      "Finance Portal: https://www.sde.idaho.gov/finance/",
      "Idaho Report Card: https://idahoreportcard.org/"
    )
  )
}


#' Print data availability summary
#'
#' Prints a formatted summary of available Idaho school data.
#'
#' @export
#' @examples
#' \dontrun{
#' print_data_availability()
#' }
print_data_availability <- function() {
  info <- get_data_availability()

  cat("\n=== Idaho School Data Availability ===\n\n")

  cat("Source:", info$agency, "\n")
  cat("URL:", info$agency_url, "\n\n")

  cat("Enrollment Data:\n")
  cat("  Total enrollment: ", min(info$years$enrollment_total), "-",
      max(info$years$enrollment_total), "\n", sep = "")
  cat("  With demographics: ", min(info$years$enrollment_demographic), "-",
      max(info$years$enrollment_demographic), "\n", sep = "")
  cat("  By grade level: ", min(info$years$enrollment_by_grade), "-",
      max(info$years$enrollment_by_grade), "\n\n", sep = "")

  cat("Demographics available:\n")
  cat("  ", paste(info$demographics_available, collapse = ", "), "\n\n")

  cat("Geographic coverage:\n")
  cat("  ", info$geographic$districts, "\n")
  cat("  ", info$geographic$charters, "\n\n")

  cat("Notes:\n")
  for (note in info$notes) {
    cat("  - ", note, "\n")
  }
  cat("\n")

  invisible(info)
}
