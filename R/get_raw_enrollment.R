# ==============================================================================
# Raw Enrollment Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw enrollment data from
# Idaho State Department of Education (SDE).
#
# Data sources (updated December 2025):
# - Historical Enrollment by District/Charter: Multi-year data with grades
#   URL: https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx
# - Historical Enrollment by Building: Building-level data
#   URL: https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-Building-1.xlsx
# - Current Enrollment by District/Charter: Latest year only
#   URL: https://www.sde.idaho.gov/wp-content/uploads/2025/12/Enrollment-by-District-and-Charter-School.xlsx
#
# Note: The file structure uses:
# - 4 header rows to skip
# - Year column in format "2025-2026" (full years with dash)
# - Grade columns: Preschool, garten (Kindergarten), 1st-12th
#
# ==============================================================================


#' Download raw enrollment data from Idaho SDE
#'
#' Downloads enrollment data from Idaho State Department of Education.
#' Uses historical enrollment files which contain multi-year data.
#'
#' @param end_year School year end (2024 = 2023-24 school year)
#' @return List with district and building data frames
#' @keywords internal
get_raw_enr <- function(end_year) {

  # Validate year - data available from 1996 onwards in historical file
  # File contains data from 1995-1996 through 2025-2026
  if (end_year < 1996 || end_year > 2026) {
    stop("end_year must be between 1996 and 2026")
  }

  message(paste("Downloading Idaho SDE enrollment data for", end_year, "..."))

  # Download the historical enrollment file (contains all years)
  historical_data <- download_historical_enrollment()

  # Filter to the requested year
  district_data <- filter_year_data(historical_data$district, end_year)
  building_data <- filter_year_data(historical_data$building, end_year)

  if (nrow(district_data) == 0) {
    stop(paste("No data found for year", end_year, "in historical enrollment file"))
  }

  # Add end_year column
  district_data$end_year <- end_year
  if (nrow(building_data) > 0) {
    building_data$end_year <- end_year
  }

  list(
    district = district_data,
    building = building_data
  )
}


#' Download historical enrollment summary file
#'
#' Downloads the comprehensive historical enrollment file from Idaho SDE.
#' This file contains enrollment data for all districts and charter schools
#' across multiple years (1995-1996 through 2025-2026).
#'
#' @return List with district and building data frames
#' @keywords internal
download_historical_enrollment <- function() {

  message("  Downloading historical enrollment data...")

  # Primary URL for historical enrollment by district/charter (updated Dec 2025)
  # This file contains year-by-year enrollment for all districts with grade breakdowns
  primary_url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-District-or-Charter.xlsx"

  # Download to temp file

  tname <- tempfile(
    pattern = "id_historical_enr_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  download_success <- FALSE

  tryCatch({
    response <- httr::GET(
      primary_url,
      httr::write_disk(tname, overwrite = TRUE),
      httr::timeout(120)
    )

    if (!httr::http_error(response)) {
      # Verify it's a valid Excel file (should be ~500KB+)
      file_info <- file.info(tname)
      if (file_info$size > 100000) {
        download_success <- TRUE
      }
    }
  }, error = function(e) {
    message(paste("    Failed to download from:", primary_url))
  })

  if (!download_success) {
    stop("Failed to download Idaho historical enrollment data from SDE website. ",
         "URL may have changed. Check: https://www.sde.idaho.gov/finance/")
  }

  # Read the Excel file, skipping header rows
  # File structure: 4 header rows, then data
  # Columns: #, School District or Charter School, Year, Membership, Preschool, garten, 1st-12th
  # Note: This file uses "fill-down" format where district name/ID only appears on first row
  district_df <- tryCatch({
    readxl::read_excel(
      tname,
      sheet = 1,
      skip = 4,
      col_types = "text"
    )
  }, error = function(e) {
    stop(paste("Failed to parse Excel file:", e$message))
  })

  # Standardize column names
  names(district_df) <- c(
    "district_id", "district_name", "year", "membership",
    "preschool", "kindergarten", "grade_1", "grade_2", "grade_3", "grade_4",
    "grade_5", "grade_6", "grade_7", "grade_8", "grade_9", "grade_10",
    "grade_11", "grade_12"
  )[1:ncol(district_df)]

  # Fill down district_id and district_name (Excel format has these only on first row per entity)
  # Use tidyr::fill or manual fill
  last_id <- NA_character_
  last_name <- NA_character_
  for (i in seq_len(nrow(district_df))) {
    if (!is.na(district_df$district_name[i]) && district_df$district_name[i] != "") {
      last_id <- district_df$district_id[i]
      last_name <- district_df$district_name[i]
    } else if (!is.na(district_df$year[i])) {
      # Only fill if we have year data (skip blank separator rows)
      district_df$district_id[i] <- last_id
      district_df$district_name[i] <- last_name
    }
  }

  # Try to get building-level data from a separate file if available
  building_df <- download_building_enrollment()

  # Clean up temp file
  unlink(tname)

  list(
    district = district_df,
    building = building_df
  )
}


#' Download building-level enrollment data
#'
#' Downloads the historical building-level enrollment file from Idaho SDE.
#' This is a large file (~6MB) with enrollment by building across years.
#'
#' @return Data frame with building enrollment or empty data frame if unavailable
#' @keywords internal
download_building_enrollment <- function() {

  # Building-level data URL (updated Dec 2025)
  building_url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-Enrollment-by-Building-1.xlsx"

  tname <- tempfile(
    pattern = "id_building_enr_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  tryCatch({
    response <- httr::GET(
      building_url,
      httr::write_disk(tname, overwrite = TRUE),
      httr::timeout(180)  # Longer timeout for large file
    )

    if (!httr::http_error(response)) {
      file_info <- file.info(tname)
      # Building file is ~6MB
      if (file_info$size > 100000) {
        # Skip header row in building file
        df <- readxl::read_excel(tname, sheet = 1, skip = 1, col_types = "text")
        unlink(tname)
        return(df)
      }
    }
  }, error = function(e) {
    message("  Note: Building-level data not available")
  })

  unlink(tname)

  # Return empty data frame if building data not available
  data.frame()
}


#' Filter historical data to a specific year
#'
#' The historical enrollment file has data in long format with a Year column.
#' Year format is "2024-2025" (start year - end year with dash).
#'
#' @param df Data frame from historical file
#' @param end_year The school year end to filter to
#' @return Data frame filtered to the requested year
#' @keywords internal
filter_year_data <- function(df, end_year) {

  if (is.null(df) || nrow(df) == 0) {
    return(data.frame())
  }

  cols <- names(df)

  # Idaho file uses year format "2024-2025" (full years with dash)
  # end_year 2025 corresponds to "2024-2025" school year
  year_full <- paste0(end_year - 1, "-", end_year)  # e.g., "2024-2025"

  # Check for year column
  year_col <- grep("^year$|^school.?year$", cols, value = TRUE, ignore.case = TRUE)

  if (length(year_col) > 0) {
    year_col <- year_col[1]
    year_values <- df[[year_col]]

    # Match the full year format
    year_match <- year_values == year_full

    result <- df[year_match, , drop = FALSE]

    # Remove rows with no data (blank district names)
    if ("district_name" %in% names(result)) {
      result <- result[!is.na(result$district_name) & result$district_name != "", ]
    }

    return(result)
  }

  # If no year column found, try to identify it from available columns
  warning(paste("Could not identify year column in data for year", end_year))
  data.frame()
}


#' Download current year enrollment by district
#'
#' Downloads the current enrollment file which has only the latest year.
#'
#' @return Data frame with current enrollment data
#' @keywords internal
download_current_enrollment <- function() {

  message("  Downloading current enrollment data...")

  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Enrollment-by-District-and-Charter-School.xlsx"

  tname <- tempfile(
    pattern = "id_current_enr_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  tryCatch({
    response <- httr::GET(
      url,
      httr::write_disk(tname, overwrite = TRUE),
      httr::timeout(120)
    )

    if (httr::http_error(response)) {
      stop(paste("HTTP error:", httr::status_code(response)))
    }

    # Skip header rows
    df <- readxl::read_excel(tname, sheet = 1, skip = 4, col_types = "text")
    unlink(tname)
    return(df)

  }, error = function(e) {
    unlink(tname)
    warning(paste("Failed to download current enrollment:", e$message))
    return(data.frame())
  })
}


#' Download enrollment by grade level
#'
#' Note: Grade-level data is included in the main historical file,
#' so this function uses that file filtered to the requested year.
#'
#' @param end_year School year end
#' @return Data frame with grade-level enrollment
#' @keywords internal
download_grade_enrollment <- function(end_year) {

  message("  Downloading grade-level enrollment data...")

  # Grade data is in the statewide by grade file
  url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/12/Historical-State-Enrollment-by-Grade.xlsx"

  tname <- tempfile(
    pattern = "id_grade_enr_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  tryCatch({
    response <- httr::GET(
      url,
      httr::write_disk(tname, overwrite = TRUE),
      httr::timeout(180)
    )

    if (!httr::http_error(response)) {
      file_info <- file.info(tname)
      if (file_info$size > 100000) {
        df <- readxl::read_excel(tname, sheet = 1, skip = 1, col_types = "text")
        unlink(tname)
        return(filter_year_data(df, end_year))
      }
    }
  }, error = function(e) {
    message("  Note: Grade-level data not available separately")
  })

  unlink(tname)
  data.frame()
}
