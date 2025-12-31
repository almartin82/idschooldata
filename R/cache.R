# ==============================================================================
# Caching Functions
# ==============================================================================
#
# This file contains functions for caching downloaded data locally to avoid
# repeated downloads from Idaho SDE.
#
# ==============================================================================

#' Get cache directory path
#'
#' Returns the path to the cache directory, creating it if necessary.
#' Uses rappdirs for cross-platform cache location.
#'
#' @return Path to cache directory
#' @keywords internal
get_cache_dir <- function() {
  cache_dir <- file.path(
    rappdirs::user_cache_dir("idschooldata"),
    "data"
  )

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  cache_dir
}


#' Get cache file path for given year and type
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return Full path to cache file
#' @keywords internal
get_cache_path <- function(end_year, type) {
  cache_dir <- get_cache_dir()
  file.path(cache_dir, paste0("enr_", type, "_", end_year, ".rds"))
}


#' Check if cached data exists and is valid
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @param max_age Maximum age in days (default 30)
#' @return TRUE if valid cache exists
#' @keywords internal
cache_exists <- function(end_year, type, max_age = 30) {
  cache_path <- get_cache_path(end_year, type)

  if (!file.exists(cache_path)) {
    return(FALSE)
  }

  # Check age
  file_info <- file.info(cache_path)
  age_days <- as.numeric(difftime(Sys.time(), file_info$mtime, units = "days"))

  age_days <= max_age
}


#' Read data from cache
#'
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return Cached data frame
#' @keywords internal
read_cache <- function(end_year, type) {
  cache_path <- get_cache_path(end_year, type)
  readRDS(cache_path)
}


#' Write data to cache
#'
#' @param df Data frame to cache
#' @param end_year School year end
#' @param type Data type ("tidy" or "wide")
#' @return Invisibly returns the cache path
#' @keywords internal
write_cache <- function(df, end_year, type) {
  cache_path <- get_cache_path(end_year, type)
  saveRDS(df, cache_path)
  invisible(cache_path)
}


#' Clear the idschooldata cache
#'
#' Removes cached data files.
#'
#' @param end_year Optional school year to clear. If NULL, clears all years.
#' @param type Optional data type to clear. If NULL, clears all types.
#' @return Invisibly returns the number of files removed
#' @export
#' @examples
#' \dontrun{
#' # Clear all cached data
#' clear_cache()
#'
#' # Clear only 2024 data
#' clear_cache(2024)
#'
#' # Clear only tidy format data
#' clear_cache(type = "tidy")
#' }
clear_cache <- function(end_year = NULL, type = NULL) {
  cache_dir <- get_cache_dir()

  if (!is.null(end_year) && !is.null(type)) {
    # Clear specific file
    files <- get_cache_path(end_year, type)
    files <- files[file.exists(files)]
  } else if (!is.null(end_year)) {
    # Clear all types for year
    files <- list.files(cache_dir, pattern = paste0("_", end_year, "\\.rds$"), full.names = TRUE)
  } else if (!is.null(type)) {
    # Clear all years for type
    files <- list.files(cache_dir, pattern = paste0("^enr_", type, "_"), full.names = TRUE)
  } else {
    # Clear all
    files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)
  }

  if (length(files) > 0) {
    file.remove(files)
    message(paste("Removed", length(files), "cached file(s)"))
  } else {
    message("No cached files to remove")
  }

  invisible(length(files))
}


#' Show cache status
#'
#' Lists all cached data files with their size and age.
#'
#' @return Data frame with cache information (invisibly)
#' @export
#' @examples
#' \dontrun{
#' cache_status()
#' }
cache_status <- function() {
  cache_dir <- get_cache_dir()
  files <- list.files(cache_dir, pattern = "\\.rds$", full.names = TRUE)

  if (length(files) == 0) {
    message("Cache is empty")
    return(invisible(data.frame()))
  }

  info <- file.info(files)
  info$file <- basename(files)
  info$year <- as.integer(gsub(".*_(\\d{4})\\.rds$", "\\1", info$file))
  info$type <- gsub("^enr_(.*)_\\d{4}\\.rds$", "\\1", info$file)
  info$size_mb <- round(info$size / 1024 / 1024, 2)
  info$age_days <- round(as.numeric(difftime(Sys.time(), info$mtime, units = "days")), 1)

  result <- info[, c("year", "type", "size_mb", "age_days")]
  result <- result[order(result$year, result$type), ]
  rownames(result) <- NULL

  print(result)
  invisible(result)
}
