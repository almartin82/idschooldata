# ==============================================================================
# Enrollment Data Processing Functions
# ==============================================================================
#
# This file contains functions for processing raw Idaho SDE enrollment data
# into a clean, standardized format.
#
# ==============================================================================


#' Process raw Idaho SDE enrollment data
#'
#' Transforms raw SDE data into a standardized schema combining district
#' and building (campus) data.
#'
#' @param raw_data List containing district and building data frames from get_raw_enr
#' @param end_year School year end
#' @return Processed data frame with standardized columns
#' @keywords internal
process_enr <- function(raw_data, end_year) {

  # Process district data
  district_processed <- process_district_enr(raw_data$district, end_year)

  # Process building data (if available)
  if (!is.null(raw_data$building) && nrow(raw_data$building) > 0) {
    building_processed <- process_building_enr(raw_data$building, end_year)
  } else {
    building_processed <- data.frame()
  }

  # Create state aggregate from district data
  state_processed <- create_state_aggregate(district_processed, end_year)

  # Combine all levels
  result <- dplyr::bind_rows(state_processed, district_processed, building_processed)

  result
}


#' Process district-level enrollment data
#'
#' @param df Raw district data frame (already has standardized column names from download)
#' @param end_year School year end
#' @return Processed district data frame
#' @keywords internal
process_district_enr <- function(df, end_year) {

  if (is.null(df) || nrow(df) == 0) {
    return(data.frame())
  }

  cols <- names(df)
  n_rows <- nrow(df)

  # Build result dataframe
  result <- data.frame(
    end_year = rep(end_year, n_rows),
    type = rep("District", n_rows),
    stringsAsFactors = FALSE
  )

  # District ID (already standardized in download)
  if ("district_id" %in% cols) {
    result$district_id <- standardize_district_id(df$district_id)
  } else {
    result$district_id <- NA_character_
  }

  # Campus ID is NA for district rows
  result$campus_id <- rep(NA_character_, n_rows)

  # District name
  if ("district_name" %in% cols) {
    result$district_name <- clean_name(df$district_name)
  } else {
    result$district_name <- NA_character_
  }

  result$campus_name <- rep(NA_character_, n_rows)

  # Charter flag - infer from name
  result$charter_flag <- ifelse(
    grepl("charter", result$district_name, ignore.case = TRUE),
    "Y", "N"
  )

  # Total enrollment - use "membership" column from historical file
  if ("membership" %in% cols) {
    result$row_total <- safe_numeric(df$membership)
  } else {
    result$row_total <- NA_real_
  }

  # Grade levels - using standardized column names from download
  grade_cols <- list(
    grade_pk = "preschool",
    grade_k = "kindergarten",
    grade_01 = "grade_1",
    grade_02 = "grade_2",
    grade_03 = "grade_3",
    grade_04 = "grade_4",
    grade_05 = "grade_5",
    grade_06 = "grade_6",
    grade_07 = "grade_7",
    grade_08 = "grade_8",
    grade_09 = "grade_9",
    grade_10 = "grade_10",
    grade_11 = "grade_11",
    grade_12 = "grade_12"
  )

  for (name in names(grade_cols)) {
    col <- grade_cols[[name]]
    if (col %in% cols) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Filter out rows with no valid data (remove state total and empty rows)
  # Keep rows that have either a valid total or a district name (but not state totals)
  result <- result[
    !is.na(result$district_name) &
    result$district_name != "" &
    !grepl("STATE OF IDAHO", result$district_name, ignore.case = TRUE),
  ]

  result
}


#' Process building-level enrollment data
#'
#' @param df Raw building data frame
#' @param end_year School year end
#' @return Processed building data frame
#' @keywords internal
process_building_enr <- function(df, end_year) {

  if (is.null(df) || nrow(df) == 0) {
    return(data.frame())
  }

  cols <- names(df)
  n_rows <- nrow(df)

  # Helper to find column by pattern
  find_col <- function(patterns) {
    for (pattern in patterns) {
      matched <- grep(pattern, cols, value = TRUE, ignore.case = TRUE)
      if (length(matched) > 0) return(matched[1])
    }
    NULL
  }

  # Build result dataframe
  result <- data.frame(
    end_year = rep(end_year, n_rows),
    type = rep("Campus", n_rows),
    stringsAsFactors = FALSE
  )

  # District ID
  district_id_col <- find_col(c("^district.?id$", "^lea.?id$", "^dist.?code$"))
  if (!is.null(district_id_col)) {
    result$district_id <- standardize_district_id(df[[district_id_col]])
  }

  # Building/Campus ID
  building_id_col <- find_col(c("^building.?id$", "^school.?id$", "^campus.?id$", "^site.?id$"))
  if (!is.null(building_id_col)) {
    result$campus_id <- trimws(as.character(df[[building_id_col]]))
  } else {
    result$campus_id <- NA_character_
  }

  # District name
  district_name_col <- find_col(c("^district.?name$", "^lea.?name$"))
  if (!is.null(district_name_col)) {
    result$district_name <- clean_name(df[[district_name_col]])
  }

  # Building/Campus name
  building_name_col <- find_col(c("^building.?name$", "^school.?name$", "^campus.?name$", "^site.?name$", "^school$"))
  if (!is.null(building_name_col)) {
    result$campus_name <- clean_name(df[[building_name_col]])
  }

  # Charter flag
  charter_col <- find_col(c("charter", "type"))
  if (!is.null(charter_col)) {
    charter_values <- tolower(df[[charter_col]])
    result$charter_flag <- ifelse(
      grepl("charter", charter_values) | charter_values == "c",
      "Y", "N"
    )
  }

  # Total enrollment
  total_col <- find_col(c("^enrollment$", "^total$", "^total.?enrollment$"))
  if (!is.null(total_col)) {
    result$row_total <- safe_numeric(df[[total_col]])
  }

  # Filter out empty rows
  result <- result[!is.na(result$row_total) | !is.na(result$campus_name), ]

  result
}


#' Create state-level aggregate from district data
#'
#' @param district_df Processed district data frame
#' @param end_year School year end
#' @return Single-row data frame with state totals
#' @keywords internal
create_state_aggregate <- function(district_df, end_year) {

  if (is.null(district_df) || nrow(district_df) == 0) {
    return(data.frame(
      end_year = end_year,
      type = "State",
      district_id = NA_character_,
      campus_id = NA_character_,
      district_name = NA_character_,
      campus_name = NA_character_,
      charter_flag = NA_character_,
      row_total = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  # Columns to sum
  sum_cols <- c(
    "row_total",
    "white", "black", "hispanic", "asian",
    "pacific_islander", "native_american", "multiracial",
    "male", "female",
    "econ_disadv", "lep", "special_ed",
    "grade_pk", "grade_k",
    "grade_01", "grade_02", "grade_03", "grade_04",
    "grade_05", "grade_06", "grade_07", "grade_08",
    "grade_09", "grade_10", "grade_11", "grade_12"
  )

  # Filter to columns that exist
  sum_cols <- sum_cols[sum_cols %in% names(district_df)]

  # Create state row
  state_row <- data.frame(
    end_year = end_year,
    type = "State",
    district_id = NA_character_,
    campus_id = NA_character_,
    district_name = NA_character_,
    campus_name = NA_character_,
    charter_flag = NA_character_,
    stringsAsFactors = FALSE
  )

  # Sum each column
  for (col in sum_cols) {
    if (col %in% names(district_df)) {
      state_row[[col]] <- sum(district_df[[col]], na.rm = TRUE)
    }
  }

  state_row
}


#' Standardize column names across different file formats
#'
#' Idaho SDE uses different column naming conventions across years and files.
#' This function maps them to a consistent set of names.
#'
#' @param df Data frame with raw column names
#' @return Data frame with standardized column names
#' @keywords internal
standardize_column_names <- function(df) {

  if (is.null(df) || ncol(df) == 0) {
    return(df)
  }

  # Mapping of common variations to standard names
  name_map <- c(
    # District identifiers
    "lea_id" = "district_id",
    "lea_number" = "district_id",
    "dist_id" = "district_id",
    "district_number" = "district_id",
    "districtid" = "district_id",

    # District names
    "lea_name" = "district_name",
    "dist_name" = "district_name",
    "districtname" = "district_name",

    # Building identifiers
    "building_id" = "campus_id",
    "school_id" = "campus_id",
    "site_id" = "campus_id",
    "buildingid" = "campus_id",
    "schoolid" = "campus_id",

    # Building names
    "building_name" = "campus_name",
    "school_name" = "campus_name",
    "site_name" = "campus_name",
    "buildingname" = "campus_name",
    "schoolname" = "campus_name",

    # Enrollment
    "total_enrollment" = "row_total",
    "enrollment_total" = "row_total",
    "student_count" = "row_total"
  )

  # Apply mappings
  current_names <- tolower(gsub("[^a-z0-9]", "_", names(df)))
  current_names <- gsub("_+", "_", current_names)
  current_names <- gsub("^_|_$", "", current_names)

  for (i in seq_along(current_names)) {
    if (current_names[i] %in% names(name_map)) {
      names(df)[i] <- name_map[current_names[i]]
    }
  }

  df
}
