# Update awards/data/*.csv from the AP-LS Award Winners Google Sheet.
#
# Run manually whenever the winners Sheet changes w/
#   source("awards/_update-awards.R")     # do it from the project root
# NOTE: The committed CSVs are what the award pages render, so the site build never
# depends on Google being reachable. But each tab in the Google Sheet has 
# the same structure (tab names + column
# headers) as the source workbook -- RE-NAMING anything will cause problems!!

library(googlesheets4)
library(dplyr)
library(readr)
library(here)

# Public sheet ("anyone with the link can view"), read-only, no login needed.
gs4_deauth()

SHEET_ID <- "1iePnIxlQRviQ5Hf7Vayzgh59UzidN_pS72wUUHnSTbA"

out_dir <- here("awards", "data")

# tab name in the Sheet -> output CSV -> columns to keep (in display order)
tabs <- list(
  list(tab = "saleem-shah",     file = "saleem-shah.csv",
       cols = c("year", "name")),
  list(tab = "teaching",        file = "teaching.csv",
       cols = c("year", "type", "name", "affiliation")),
  list(tab = "book",            file = "book_awards.csv",
       cols = c("year", "author", "title", "url", "img")),
  list(tab = "undergrad-paper", file = "undergrad-paper.csv",
       cols = c("year", "award", "name", "affiliation", "title", "advisor")),
  list(tab = "dissertation",    file = "dissertation.csv",
       cols = c("year", "first", "second", "third")),
  list(tab = "distinguished",   file = "distinguished.csv",
       cols = c("year", "name")),
  list(tab = "REID",            file = "reid.csv",
       cols = c("year", "name", "institution", "project_title",
                "award_type", "award_amount"))
)

write_tab <- function(spec) {
  d <- read_sheet(SHEET_ID, sheet = spec$tab)

  # keep only the columns we display, in order; ignore any extras in the Sheet
  d <- dplyr::select(d, dplyr::any_of(spec$cols))

  # Safety: never overwrite a good CSV with an empty pull (blank/mis-named tab,
  # or a transient read). Warn and leave the existing CSV untouched.
  if (nrow(d) == 0 || ncol(d) == 0) {
    warning("Skipped ", spec$file, ": tab '", spec$tab, "' returned ",
            nrow(d), " rows x ", ncol(d), " cols. Existing CSV left unchanged.",
            call. = FALSE)
    return(invisible(NULL))
  }

  # coerce every column to plain text so read.csv() in the .qmd is predictable
  # (read_sheet can return list/typed columns). Empty cells -> "".
  d <- dplyr::mutate(d, dplyr::across(dplyr::everything(),
                                      ~ ifelse(is.na(.x), "", as.character(.x))))

  # NOTE: the book table's `year` column is intentionally text (e.g. "2025a",
  # "2009-10"). Keep that column formatted as plain text in the Sheet so the
  # labels survive; otherwise dates/numbers will be written here verbatim.

  readr::write_csv(d, file.path(out_dir, spec$file))
  message("Wrote ", spec$file, " (", nrow(d), " rows)")
}

invisible(lapply(tabs, write_tab))
message("Done. Review changes with `git diff awards/data/` before committing.")
