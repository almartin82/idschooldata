# ==============================================================================
# Raw Enrollment Data Download Functions
# ==============================================================================
#
# This file contains functions for downloading raw enrollment data from
# Idaho State Department of Education (SDE).
#
# Data sources:
# - Historical Enrollment Summary: District/Charter totals by year (2002-2025)
# - Historical Enrollment by District: Detailed enrollment with grades (2011-2025)
# - Enrollment by Building: Current year building-level data
#
# File locations on SDE website:
# - https://www.sde.idaho.gov/finance/files/attendance-enrollment/historical/
# - https://www.sde.idaho.gov/finance/files/attendance-enrollment/enrollment/
#
# Note: Historical data before 2011 has limited demographic breakdowns.
# Race/ethnicity data is only reliably available from 2011 onward.
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

  # Validate year - data available from 2002 onwards in historical file
  if (end_year < 2002 || end_year > 2025) {
    stop("end_year must be between 2002 and 2025")
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
#' across multiple years.
#'
#' @return List with district and building data frames
#' @keywords internal
download_historical_enrollment <- function() {

  message("  Downloading historical enrollment data...")

  # Primary URL for historical enrollment by district/charter
  # This file contains year-by-year enrollment for all districts
  primary_url <- "https://www.sde.idaho.gov/finance/files/attendance-enrollment/historical/Historical-Enrollment-by-District-or-Charter.xlsx"

  # Alternative URL structure (in case primary fails)
  alt_url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/07/Historical-Enrollment-by-District-or-Charter.xlsx"

  # Download to temp file
  tname <- tempfile(
    pattern = "id_historical_enr_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  # Try primary URL first, then alternative
  download_success <- FALSE

  for (url in c(primary_url, alt_url)) {
    tryCatch({
      response <- httr::GET(
        url,
        httr::write_disk(tname, overwrite = TRUE),
        httr::timeout(120)
      )

      if (!httr::http_error(response)) {
        # Verify it's a valid Excel file
        file_info <- file.info(tname)
        if (file_info$size > 1000) {
          download_success <- TRUE
          break
        }
      }
    }, error = function(e) {
      message(paste("    Failed to download from:", url))
    })
  }

  if (!download_success) {
    stop("Failed to download Idaho historical enrollment data from SDE website")
  }

  # Read the Excel file
  # The historical file typically has enrollment across columns by year
  district_df <- tryCatch({
    readxl::read_excel(
      tname,
      sheet = 1,
      col_types = "text"
    )
  }, error = function(e) {
    stop(paste("Failed to parse Excel file:", e$message))
  })

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
#' @return Data frame with building enrollment or empty data frame if unavailable
#' @keywords internal
download_building_enrollment <- function() {

  # Building-level data URL
  building_url <- "https://www.sde.idaho.gov/finance/files/attendance-enrollment/historical/Historical-Enrollment-by-Building-for-District-and-Charter-School.xlsx"

  alt_url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/07/Historical-Enrollment-by-Building.xlsx"

  tname <- tempfile(
    pattern = "id_building_enr_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  for (url in c(building_url, alt_url)) {
    tryCatch({
      response <- httr::GET(
        url,
        httr::write_disk(tname, overwrite = TRUE),
        httr::timeout(120)
      )

      if (!httr::http_error(response)) {
        file_info <- file.info(tname)
        if (file_info$size > 1000) {
          df <- readxl::read_excel(tname, sheet = 1, col_types = "text")
          unlink(tname)
          return(df)
        }
      }
    }, error = function(e) {
      # Silently continue to next URL
    })
  }

  unlink(tname)

  # Return empty data frame if building data not available
  data.frame()
}


#' Filter historical data to a specific year
#'
#' The historical enrollment file has years as columns. This function
#' identifies the correct year column and filters/pivots as needed.
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

  # Idaho historical file typically uses format like "2023-24" or "2024" for year columns
  # or may have a "Year" column with the data in long format
  year_label <- get_year_label(end_year)  # e.g., "2023-24"
  year_short <- as.character(end_year)    # e.g., "2024"
  year_prev <- as.character(end_year - 1) # e.g., "2023"

  # Check if data is in wide format (years as columns)
  year_cols <- grep(paste0(year_label, "|^", year_short, "$|^", year_prev, "-"), cols, value = TRUE)

  if (length(year_cols) > 0) {
    # Wide format - need to select the enrollment column for this year
    # Identify ID columns (district name, ID, etc.)
    id_patterns <- c("district", "name", "id", "code", "lea", "charter")
    id_cols <- cols[grepl(paste(id_patterns, collapse = "|"), cols, ignore.case = TRUE)]

    # Keep ID columns and the year column
    keep_cols <- unique(c(id_cols, year_cols))
    keep_cols <- keep_cols[keep_cols %in% cols]

    if (length(keep_cols) > 0) {
      result <- df[, keep_cols, drop = FALSE]
      # Rename the year column to "enrollment" for consistency
      if (length(year_cols) == 1) {
        names(result)[names(result) == year_cols[1]] <- "enrollment"
      }
      return(result)
    }
  }

  # Check if data is in long format with a Year column
  year_col <- grep("^year$|^school.?year$|^fiscal.?year$", cols, value = TRUE, ignore.case = TRUE)

  if (length(year_col) > 0) {
    year_col <- year_col[1]
    # Filter to matching year
    year_values <- df[[year_col]]

    # Match various year formats
    year_match <- year_values == year_label |
                  year_values == year_short |
                  grepl(paste0("^", year_prev, ".*", substr(year_short, 3, 4)), year_values)

    result <- df[year_match, , drop = FALSE]
    return(result)
  }

  # If no year structure detected, return empty
  warning(paste("Could not identify year structure in data for year", end_year))
  data.frame()
}


#' Download current year enrollment by district
#'
#' Downloads the current enrollment file which has more detailed breakdowns.
#'
#' @return Data frame with current enrollment data
#' @keywords internal
download_current_enrollment <- function() {

  message("  Downloading current enrollment data...")

  url <- "https://www.sde.idaho.gov/finance/files/attendance-enrollment/enrollment/Enrollment-by-District-and-Charter.xlsx"

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

    df <- readxl::read_excel(tname, sheet = 1, col_types = "text")
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
#' @param end_year School year end
#' @return Data frame with grade-level enrollment
#' @keywords internal
download_grade_enrollment <- function(end_year) {

  message("  Downloading grade-level enrollment data...")

  # Historical grade-level data
  url <- "https://www.sde.idaho.gov/finance/files/attendance-enrollment/historical/Historical-Statewide-Enrollment-by-Grade.xlsx"

  alt_url <- "https://www.sde.idaho.gov/wp-content/uploads/2025/07/Historical-Enrollment-by-District-or-Charter-by-Grade.xlsx"

  tname <- tempfile(
    pattern = "id_grade_enr_",
    tmpdir = tempdir(),
    fileext = ".xlsx"
  )

  for (url in c(url, alt_url)) {
    tryCatch({
      response <- httr::GET(
        url,
        httr::write_disk(tname, overwrite = TRUE),
        httr::timeout(120)
      )

      if (!httr::http_error(response)) {
        file_info <- file.info(tname)
        if (file_info$size > 1000) {
          df <- readxl::read_excel(tname, sheet = 1, col_types = "text")
          unlink(tname)
          return(filter_year_data(df, end_year))
        }
      }
    }, error = function(e) {
      # Continue to next URL
    })
  }

  unlink(tname)
  data.frame()
}


#' Get available years from Idaho SDE data
#'
#' @return Vector of available school year ends
#' @keywords internal
get_available_years <- function() {
  # Based on research, Idaho SDE historical data goes back to approximately 2002
  # with more complete data from 2011 onward
  2002:2025
}
