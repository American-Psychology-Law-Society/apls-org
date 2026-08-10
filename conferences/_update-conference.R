# Update the conference pages from the AP-LS Conference Google Sheet.
#
# Mirrors awards/_update-awards.R. Co-chairs edit the Sheet during the
# conference year; this script pulls it into local files that the pages
# render. Run manually whenever the Sheet changes:
#   source("conferences/_update-conference.R")     # from the project root
# The committed CSVs and generated workshop pages are what the site renders,
# so the site build never depends on Google being reachable.
#
# ---------------------------------------------------------------
# SHEET STRUCTURE (one Google Sheet, "anyone with the link can view"):
#
# Tab "info"                 columns: key, value
#   keys: submissions_note, cfp_note, cfp_deadline, submission_portal_url,
#         reviewer_form_url, hotel_note, hotel_booking_url, schedule_note,
#         registration_note, registration_url, preconference_note,
#         rates_note, workshop_rates_note
#
# Tab "registration-rates"   columns: status, early_bird, regular
#   one row per attendee status, in display order
#
# Tab "workshop-rates"       columns: type, status, early_bird, regular
#   type is "Full-Day" or "Half-Day"; one row per status within each type
#
# Tab "workshops"            columns: slug, title, subtitle, date, authors,
#                            categories, description, objectives, credits,
#                            time
#   slug       folder name for the workshop page, e.g. workshop_1
#   date       MM/DD/YYYY
#   authors    presenters, separated by semicolons
#   categories level and length, separated by semicolons
#              (e.g. "Intermediate; Half Day")
#   objectives learning objectives, separated by semicolons
#   credits    e.g. "7 CE hours";  time e.g. "8:30 AM - 4:30 PM"
# ---------------------------------------------------------------

library(googlesheets4)
library(dplyr)
library(readr)
library(here)

# Public sheet ("anyone with the link can view"), read-only, no login needed.
gs4_deauth()

# Paste the Sheet's ID here once the web editor creates it (the long string
# in the Sheet's URL, between /d/ and /edit). conferences/sheet-seed/ has
# import-ready CSVs and a walkthrough for creating the Sheet.
SHEET_ID <- "PASTE-THE-SHEET-ID-HERE"

data_dir <- here("conferences", "data")

# ---- part 1: pull the Sheet into local CSVs -----------------------------

# tab name -> output CSV -> columns to keep (in display order)
tabs <- list(
  list(tab = "info",               file = "info.csv",
       cols = c("key", "value")),
  list(tab = "registration-rates", file = "registration-rates.csv",
       cols = c("status", "early_bird", "regular")),
  list(tab = "workshop-rates",     file = "workshop-rates.csv",
       cols = c("type", "status", "early_bird", "regular")),
  list(tab = "workshops",          file = "workshops.csv",
       cols = c("slug", "title", "subtitle", "date", "authors", "categories",
                "description", "objectives", "credits", "time"))
)

write_tab <- function(spec) {
  d <- read_sheet(SHEET_ID, sheet = spec$tab)
  d <- dplyr::select(d, dplyr::any_of(spec$cols))

  # Safety: never overwrite a good CSV with an empty pull (blank or
  # mis-named tab, or a transient read). Warn and leave the file untouched.
  if (nrow(d) == 0 || ncol(d) == 0) {
    warning("Skipped ", spec$file, ": tab '", spec$tab, "' returned ",
            nrow(d), " rows x ", ncol(d), " cols. Existing CSV left unchanged.",
            call. = FALSE)
    return(invisible(NULL))
  }

  d <- dplyr::mutate(d, dplyr::across(dplyr::everything(),
                                      ~ ifelse(is.na(.x), "", as.character(.x))))
  readr::write_csv(d, file.path(data_dir, spec$file))
  message("Wrote ", spec$file, " (", nrow(d), " rows)")
}

# ---- part 2: build workshop pages from workshops.csv ---------------------

yaml_scalar <- function(x) {
  # double-quote a YAML scalar, escaping quotes and backslashes
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub('"', '\\"', x, fixed = TRUE)
  paste0('"', x, '"')
}

yaml_list <- function(values) {
  values <- trimws(values)
  values <- values[nzchar(values)]
  paste0("  - ", vapply(values, yaml_scalar, character(1)), collapse = "\n")
}

workshop_qmd <- function(row) {
  authors    <- strsplit(row$authors, ";", fixed = TRUE)[[1]]
  categories <- strsplit(row$categories, ";", fixed = TRUE)[[1]]
  objectives <- strsplit(row$objectives, ";", fixed = TRUE)[[1]]
  description <- gsub("\r\n", "\n", row$description)
  description <- paste0("  ", gsub("\n", "\n  ", description, fixed = TRUE))

  paste0(
    "---\n",
    "title: ", yaml_scalar(row$title), "\n",
    "subtitle: |\n  ", gsub("\n", "\n  ", row$subtitle, fixed = TRUE), "\n",
    "date: ", row$date, "\n",
    "author:\n", yaml_list(authors), "\n",
    "categories:\n", yaml_list(categories), "\n",
    "description: |\n", description, "\n",
    "objectives:\n", yaml_list(objectives), "\n",
    "event-info:\n",
    "  credits: ", yaml_scalar(row$credits), "\n",
    "  time: ", yaml_scalar(row$time), "\n",
    "---\n\n",
    "<!-- This page is generated by conferences/_update-conference.R from the\n",
    "     workshops tab of the conference Google Sheet. Edit the Sheet and\n",
    "     re-run the script; do not edit this file by hand. -->\n"
  )
}

build_workshop_pages <- function() {
  workshops_file <- file.path(data_dir, "workshops.csv")
  if (!file.exists(workshops_file)) {
    message("No workshops.csv yet; skipping workshop pages.")
    return(invisible(NULL))
  }
  w <- readr::read_csv(workshops_file, col_types = readr::cols(.default = "c"))
  w <- w[nzchar(w$slug), , drop = FALSE]
  if (nrow(w) == 0) {
    message("No workshops listed yet; skipping workshop pages.")
    return(invisible(NULL))
  }
  for (i in seq_len(nrow(w))) {
    dir <- here("conferences", "preconference", w$slug[i])
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    writeLines(workshop_qmd(w[i, ]), file.path(dir, "index.qmd"))
    message("Wrote preconference/", w$slug[i], "/index.qmd")
  }
  # Warn about workshop folders that are not in the Sheet (never delete).
  existing <- list.dirs(here("conferences", "preconference"),
                        full.names = FALSE, recursive = FALSE)
  extra <- setdiff(existing, c("", w$slug))
  if (length(extra) > 0) {
    warning("Folders not in the workshops tab (left untouched): ",
            paste(extra, collapse = ", "), call. = FALSE)
  }
}

# ---- run -----------------------------------------------------------------

if (identical(SHEET_ID, "PASTE-THE-SHEET-ID-HERE")) {
  message("No SHEET_ID set yet, so nothing was pulled from Google Drive.")
  message("Workshop pages will still be rebuilt from the local workshops.csv.")
} else {
  invisible(lapply(tabs, write_tab))
}

build_workshop_pages()
message("Done. Review changes with `git diff conferences/` before committing,",
        " then render the conference pages.")
