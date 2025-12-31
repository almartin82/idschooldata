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
#' @param df Raw district data frame
#' @param end_year School year end
#' @return Processed district data frame
#' @keywords internal
process_district_enr <- function(df, end_year) {

  if (is.null(df) || nrow(df) == 0) {
    return(data.frame())
  }

  cols <- names(df)
  n_rows <- nrow(df)

  # Helper to find column by pattern (case-insensitive)
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
    type = rep("District", n_rows),
    stringsAsFactors = FALSE
  )

  # District ID - Idaho uses various naming conventions
  district_id_col <- find_col(c("^district.?id$", "^lea.?id$", "^dist.?code$", "^district.?number$", "^dist.?id$"))
  if (!is.null(district_id_col)) {
    result$district_id <- standardize_district_id(df[[district_id_col]])
  } else {
    # Try to extract from name if ID column not found
    result$district_id <- NA_character_
  }

  # Campus ID is NA for district rows
  result$campus_id <- rep(NA_character_, n_rows)

  # District name
  district_name_col <- find_col(c("^district.?name$", "^lea.?name$", "^district$", "^name$"))
  if (!is.null(district_name_col)) {
    result$district_name <- clean_name(df[[district_name_col]])
  } else {
    result$district_name <- NA_character_
  }

  result$campus_name <- rep(NA_character_, n_rows)

  # Charter flag - Idaho distinguishes charters from traditional districts
  charter_col <- find_col(c("charter", "type", "lea.?type"))
  if (!is.null(charter_col)) {
    charter_values <- tolower(df[[charter_col]])
    result$charter_flag <- ifelse(
      grepl("charter", charter_values) | charter_values == "c" | charter_values == "y",
      "Y", "N"
    )
  } else {
    # Infer from name if column not found
    result$charter_flag <- ifelse(
      grepl("charter", result$district_name, ignore.case = TRUE),
      "Y", "N"
    )
  }

  # Total enrollment
  total_col <- find_col(c("^enrollment$", "^total$", "^total.?enrollment$", "^count$", paste0("^", end_year - 1, "-")))
  if (!is.null(total_col)) {
    result$row_total <- safe_numeric(df[[total_col]])
  } else {
    # Look for year-specific column
    year_label <- get_year_label(end_year)
    year_col <- find_col(c(paste0("^", year_label), paste0("^", end_year)))
    if (!is.null(year_col)) {
      result$row_total <- safe_numeric(df[[year_col]])
    } else {
      result$row_total <- NA_real_
    }
  }

  # Demographics - may not be available in all years
  # Idaho tracks: White, Black/African American, Hispanic/Latino, Asian,
  # American Indian/Alaska Native, Native Hawaiian/Pacific Islander, Two or More Races
  demo_map <- list(
    white = c("white", "caucasian"),
    black = c("black", "african.?american"),
    hispanic = c("hispanic", "latino", "latinx"),
    asian = c("^asian$", "asian.?alone"),
    pacific_islander = c("pacific", "hawaiian", "nhpi"),
    native_american = c("indian", "native.?american", "alaska", "aian"),
    multiracial = c("two.?or.?more", "multiracial", "multi.?race", "two.?races")
  )

  for (name in names(demo_map)) {
    col <- find_col(demo_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Special populations
  special_map <- list(
    econ_disadv = c("free.?reduced", "frl", "economically", "low.?income"),
    lep = c("lep", "ell", "english.?learner", "limited.?english"),
    special_ed = c("special.?ed", "iep", "sped", "disability")
  )

  for (name in names(special_map)) {
    col <- find_col(special_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Gender
  male_col <- find_col(c("^male$", "^males$", "^m$"))
  if (!is.null(male_col)) {
    result$male <- safe_numeric(df[[male_col]])
  }

  female_col <- find_col(c("^female$", "^females$", "^f$"))
  if (!is.null(female_col)) {
    result$female <- safe_numeric(df[[female_col]])
  }

  # Grade levels - Idaho uses PK, K, 01-12
  grade_map <- list(
    grade_pk = c("^pk$", "^pre.?k", "^prek$", "^prekindergarten$"),
    grade_k = c("^k$", "^kg$", "^kindergarten$"),
    grade_01 = c("^01$", "^1$", "^grade.?1$", "^first$"),
    grade_02 = c("^02$", "^2$", "^grade.?2$", "^second$"),
    grade_03 = c("^03$", "^3$", "^grade.?3$", "^third$"),
    grade_04 = c("^04$", "^4$", "^grade.?4$", "^fourth$"),
    grade_05 = c("^05$", "^5$", "^grade.?5$", "^fifth$"),
    grade_06 = c("^06$", "^6$", "^grade.?6$", "^sixth$"),
    grade_07 = c("^07$", "^7$", "^grade.?7$", "^seventh$"),
    grade_08 = c("^08$", "^8$", "^grade.?8$", "^eighth$"),
    grade_09 = c("^09$", "^9$", "^grade.?9$", "^ninth$"),
    grade_10 = c("^10$", "^grade.?10$", "^tenth$"),
    grade_11 = c("^11$", "^grade.?11$", "^eleventh$"),
    grade_12 = c("^12$", "^grade.?12$", "^twelfth$")
  )

  for (name in names(grade_map)) {
    col <- find_col(grade_map[[name]])
    if (!is.null(col)) {
      result[[name]] <- safe_numeric(df[[col]])
    }
  }

  # Filter out rows with no valid data
  result <- result[!is.na(result$row_total) | !is.na(result$district_name), ]

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
