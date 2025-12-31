# ==============================================================================
# Utility Functions
# ==============================================================================

#' Pipe operator
#'
#' See \code{dplyr::\link[dplyr:reexports]{\%>\%}} for details.
#'
#' @name %>%
#' @rdname pipe
#' @keywords internal
#' @export
#' @importFrom dplyr %>%
#' @usage lhs \%>\% rhs
#' @param lhs A value or the magrittr placeholder.
#' @param rhs A function call using the magrittr semantics.
#' @return The result of calling `rhs(lhs)`.
NULL


#' Convert to numeric, handling suppression markers
#'
#' Idaho SDE uses various markers for suppressed data (*, <10, N/A, etc.)
#' and may use commas in large numbers.
#'
#' @param x Vector to convert
#' @return Numeric vector with NA for non-numeric values
#' @keywords internal
safe_numeric <- function(x) {
  # Handle NULL or empty input
 if (is.null(x) || length(x) == 0) {
    return(numeric(0))
  }

  # Already numeric
  if (is.numeric(x)) {
    return(x)
  }

  # Remove commas and whitespace
  x <- gsub(",", "", x)
  x <- trimws(x)

  # Handle common suppression markers
  x[x %in% c("*", ".", "-", "-1", "<5", "<10", "N/A", "NA", "", "n/a")] <- NA_character_

  suppressWarnings(as.numeric(x))
}


#' Clean and standardize school/district names
#'
#' @param x Character vector of names
#' @return Cleaned character vector
#' @keywords internal
clean_name <- function(x) {
  if (is.null(x)) return(NA_character_)

  x <- trimws(x)
  # Remove extra whitespace
  x <- gsub("\\s+", " ", x)
  x
}


#' Standardize district ID format
#'
#' Idaho district IDs are typically 3 digits, zero-padded.
#'
#' @param x Vector of district IDs
#' @return Character vector of standardized IDs
#' @keywords internal
standardize_district_id <- function(x) {
  if (is.null(x)) return(NA_character_)

  x <- trimws(as.character(x))
  # Remove any non-numeric characters
  x <- gsub("[^0-9]", "", x)
  # Pad to 3 digits
  x <- sprintf("%03d", as.integer(x))
  x[x == "NA" | is.na(x)] <- NA_character_
  x
}


#' Get the academic year label from end_year
#'
#' @param end_year The end year of the academic year (e.g., 2024 for 2023-24)
#' @return Character string like "2023-24"
#' @keywords internal
get_year_label <- function(end_year) {
  paste0(end_year - 1, "-", substr(as.character(end_year), 3, 4))
}
