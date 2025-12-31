#' idschooldata: Fetch and Process Idaho School Data
#'
#' Downloads and processes school data from the Idaho State Department of
#' Education (SDE). Provides functions for fetching enrollment data from the
#' SDE's public finance portal and transforming it into tidy format for analysis.
#'
#' @section Main functions:
#' \describe{
#'   \item{\code{\link{fetch_enr}}}{Fetch enrollment data for a school year}
#'   \item{\code{\link{fetch_enr_multi}}}{Fetch enrollment data for multiple years}
#'   \item{\code{\link{tidy_enr}}}{Transform wide data to tidy (long) format}
#'   \item{\code{\link{id_enr_aggs}}}{Add aggregation level flags}
#'   \item{\code{\link{enr_grade_aggs}}}{Create grade-level aggregations}
#' }
#'
#' @section Cache functions:
#' \describe{
#'   \item{\code{\link{cache_status}}}{View cached data files}
#'   \item{\code{\link{clear_cache}}}{Remove cached data files}
#' }
#'
#' @section ID System:
#' Idaho uses a unique identification system:
#' \itemize{
#'   \item District IDs: 3 digits (e.g., 001 = Boise Independent District)
#'   \item Building IDs: Varies by source - typically district ID + building number
#' }
#'
#' @section Data Sources:
#' Data is sourced from the Idaho State Department of Education:
#' \itemize{
#'   \item SDE Finance Portal: \url{https://www.sde.idaho.gov/finance-transparency/public-school-finance/}
#'   \item Historical Enrollment: \url{https://www.sde.idaho.gov/finance/files/attendance-enrollment/historical/}
#' }
#'
#' @section Data Eras:
#' Idaho enrollment data has evolved over time:
#' \itemize{
#'   \item Era 1 (2002-2010): Legacy format with limited demographics
#'   \item Era 2 (2011-2024): Current format with race/ethnicity breakdowns
#'   \item Note: Demographic data (race/ethnicity) only available from 2011 onward
#' }
#'
#' @docType package
#' @name idschooldata-package
#' @aliases idschooldata
#' @keywords internal
"_PACKAGE"

#' Pipe operator
#'
#' See \code{magrittr::\link[magrittr:pipe]{\%>\%}} for details.
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
