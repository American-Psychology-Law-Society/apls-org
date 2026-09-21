# Run manually from the project root with access to both source workbooks:
#   source("about/_update-committees.R")
#
# This script only updates committed local data. It does not render or publish
# the website.

library(googlesheets4)
library(here)

source(here("about", "_data-validation.R"))

update_committee_data <- function() {
  DESCRIPTION_SHEET_ID <- "17aXj7E4OE-vIgnRkNVZyw8BBjJ1MoXuroS71IqJ9rsI"
  LEADERSHIP_SHEET_ID <- "16RGHgDI7snPwaHfvF1gxTLAMet1V5_kM_4iHog2h7m8"
  NON_COMMITTEE_TABS <- c("EC", "Conf_Chairs")

  as_character_data <- function(data) {
    data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
    data[] <- lapply(data, function(column) trimws(as.character(column)))
    data
  }

  add_optional_columns <- function(data, columns) {
    for (column in setdiff(columns, names(data))) data[[column]] <- NA_character_
    data
  }

  descriptions <- read_sheet(
    DESCRIPTION_SHEET_ID,
    sheet = "committees",
    col_types = "c"
  ) |>
    as_character_data()

  description_columns <- c(
    "key", "name", "description", "responsibilities", "values",
    "meetings", "membership", "reporting", "other"
  )
  assert_required_columns(descriptions, description_columns, "Committee descriptions")
  descriptions <- add_optional_columns(descriptions, c("chair", "email"))
  descriptions <- descriptions[c(description_columns, "chair", "email")]

  all_tabs <- sheet_names(LEADERSHIP_SHEET_ID)
  if (anyDuplicated(all_tabs)) {
    validation_error("Leadership workbook", "contains duplicate tab names")
  }

  tab_data <- setNames(
    lapply(all_tabs, function(tab) {
      read_sheet(LEADERSHIP_SHEET_ID, sheet = tab, col_types = "c") |>
        as_character_data()
    }),
    all_tabs
  )

  # Validate the two leadership-only tabs even though they are not written to the
  # committee membership file.
  assert_required_columns(tab_data[["EC"]], c("Name", "Position", "Email"), "EC")
  assert_required_columns(
    tab_data[["Conf_Chairs"]],
    c("Name", "Term", "Position"),
    "Conf_Chairs"
  )

  committee_tabs <- setdiff(all_tabs, NON_COMMITTEE_TABS)
  # Committee tabs store the beginning and ending years separately. Keep the
  # committed CSV schema unchanged by combining them into one Term value here.
  source_member_columns <- c("Position", "Name", "Email", "Term Start", "Term End")
  member_columns <- c("Position", "Name", "Email", "Term", "Additional")

  combine_terms <- function(data) {
    starts <- trimws(as.character(data[["Term Start"]]))
    ends <- trimws(as.character(data[["Term End"]]))
    start_blank <- is_blank_value(starts)
    end_blank <- is_blank_value(ends)
    term <- rep(NA_character_, nrow(data))
    both <- !start_blank & !end_blank
    term[both] <- paste0(starts[both], "-", ends[both])
    term[!both & !start_blank] <- starts[!both & !start_blank]
    term[!both & start_blank & !end_blank] <- ends[!both & start_blank & !end_blank]
    data$Term <- term
    data
  }

  members_by_tab <- lapply(committee_tabs, function(tab) {
    data <- tab_data[[tab]]
    assert_required_columns(data, source_member_columns, sprintf("Leadership tab '%s'", tab))
    data <- add_optional_columns(data, "Additional")
    data <- combine_terms(data)
    data <- data[member_columns]
    data$key <- tab
    data[c("key", member_columns)]
  })

  members <- if (length(members_by_tab) > 0) {
    do.call(rbind, members_by_tab)
  } else {
    data.frame(
      key = character(), Position = character(), Name = character(),
      Email = character(), Term = character(), Additional = character(),
      stringsAsFactors = FALSE
    )
  }
  rownames(members) <- NULL

  validate_committee_inputs(descriptions, members, committee_tabs)

  targets <- c(
    here("about", "data", "committee-descriptions.csv"),
    here("about", "data", "committee-members.csv")
  )
  staged <- vapply(
    targets,
    function(target) {
      tempfile(
        pattern = paste0(".", basename(target), "-"),
        tmpdir = dirname(target),
        fileext = ".tmp"
      )
    },
    character(1)
  )
  on.exit(unlink(staged[file.exists(staged)]), add = TRUE)

  write.csv(descriptions, staged[1], row.names = FALSE, na = "", fileEncoding = "UTF-8")
  write.csv(members, staged[2], row.names = FALSE, na = "", fileEncoding = "UTF-8")

  staged_descriptions <- read.csv(
    staged[1],
    colClasses = "character", na.strings = "", check.names = FALSE
  )
  staged_members <- read.csv(
    staged[2],
    colClasses = "character", na.strings = "", check.names = FALSE
  )
  validate_committee_inputs(staged_descriptions, staged_members, committee_tabs)

  atomic_replace_files(staged, targets)
  message("Updated: ", paste(targets, collapse = ", "))
  invisible(targets)
}

update_committee_data()
