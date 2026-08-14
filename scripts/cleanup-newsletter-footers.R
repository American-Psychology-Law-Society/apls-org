#!/usr/bin/env Rscript
# Strip email footer PII from all existing newsletter HTML files.
#
# Usage: Rscript scripts/cleanup-newsletter-footers.R
#
# Scans all newsletter HTML source files and removes the MemberClicks footer
# block that contains PII (sent-to address, physical address, phone, etc.)

library(xml2)

# Footer keywords that mark the start of the PII block
footer_keywords <- c(
  "This email was sent to",
  "Remove My Email",
  "Manage Preferences",
  "Privacy Policy",
  "Powered by MemberClicks",
  "6510 Telecom Dr",
  "704-456-7276",
  "office@ap-ls.org"
)

cleanup_file <- function(path) {
  html <- readLines(path, encoding = "UTF-8", warn = FALSE)
  text <- paste(html, collapse = "\n")
  original_len <- nchar(text)

  text_lower <- tolower(text)
  truncated <- FALSE

  for (kw in footer_keywords) {
    kw_lower <- tolower(kw)
    pos <- regexpr(kw_lower, text_lower, fixed = TRUE)
    if (pos[1] > 0) {
      # Find the start of the HTML tag containing this text
      before <- substr(text, 1, pos[1] - 1)
      tag_starts <- gregexpr("<", before, fixed = TRUE)[[1]]
      if (all(tag_starts == -1)) {
        text <- substr(text, 1, pos[1] - 1)
      } else {
        last_tag_start <- max(tag_starts)
        text <- substr(text, 1, last_tag_start - 1)
      }
      truncated <- TRUE
      break
    }
  }

  if (!truncated) {
    return(FALSE)
  }

  # Clean up trailing whitespace and incomplete tags
  text <- sub("[\\s\\n\\r]+$", "", text)
  text <- sub("<[^>]*$", "", text)

  # Write back only if changed
  new_len <- nchar(text)
  if (new_len < original_len) {
    writeLines(text, path, useBytes = TRUE)
    message("CLEANED: ", path, " (removed ", original_len - new_len, " chars)")
    return(TRUE)
  }
  return(FALSE)
}

# ------------------------------------------------------------------
# Find all newsletter HTML source files
# ------------------------------------------------------------------

base <- "resources/newsletter/e-news"
files <- c()

# 2025-2026:  subdirectories with monYYYY/monYYYY.html
for (yr in c("2025", "2026")) {
  yr_path <- file.path(base, yr)
  if (dir.exists(yr_path)) {
    dirs <- list.dirs(yr_path, recursive = FALSE)
    for (d in dirs) {
      fname <- file.path(d, paste0(basename(d), ".html"))
      if (file.exists(fname)) files <- c(files, fname)
    }
  }
}

# 2023-2024: same subdirectory pattern
for (yr in c("2023", "2024")) {
  yr_path <- file.path(base, yr)
  if (dir.exists(yr_path)) {
    dirs <- list.dirs(yr_path, recursive = FALSE)
    for (d in dirs) {
      fname <- file.path(d, paste0(basename(d), ".html"))
      if (file.exists(fname)) files <- c(files, fname)
    }
  }
}

# 2021-2022: flat files in html/ directory
html_dir <- file.path(base, "html")
if (dir.exists(html_dir)) {
  files <- c(files, list.files(html_dir, pattern = "\\.html$", full.names = TRUE))
}

message("Scanning ", length(files), " newsletter HTML file(s)...\n")

count <- 0
for (f in files) {
  if (cleanup_file(f)) count <- count + 1
}

message("\nDone. Cleaned ", count, " file(s).")
