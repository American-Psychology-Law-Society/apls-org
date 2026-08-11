#!/usr/bin/env Rscript
# Process email newsletter HTML files into Quarto pages
#
# Run from project root:
#   Rscript scripts/process-newsletters.R
#
# Reads HTML files from:  resources/newsletter/_new_newsletters/
# Writes Quarto pages to:  resources/newsletter/e-news/YYYY/monYYYY/
#
# Requirements:
#   - R packages: here, fs, yaml, stringr, xml2, httr, base64enc
#   - pagedown + Chrome/Chromium (for PDF generation; auto-detects Playwright)
#
# The script skips Gmail inbox saves (>1MB without email body) and only
# processes single-email HTML saves. For future months, save the newsletter
# email as "Save page as > Webpage, HTML Only" from the individual message
# view in Gmail (not from the inbox view).

suppressPackageStartupMessages({
  library(here)
  library(fs)
  library(yaml)
  library(stringr)
})

# ------------------------------------------------------------------
# Config
# ------------------------------------------------------------------

input_dir  <- here("resources", "newsletter", "_new_newsletters")
output_dir <- here("resources", "newsletter", "e-news")
extractor  <- here("scripts", "extract_newsletter.R")
pdf_converter <- here("scripts", "html_to_pdf.R")

stopifnot(dir_exists(input_dir))

# Month name -> 3-letter abbreviation -> numeric mapping
month_abbr_map <- setNames(
  sprintf("%02d", 1:12),
  tolower(month.name)
)

month_short_map <- setNames(
  tolower(month.abb),
  tolower(month.name)
)

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

parse_filename <- function(fname) {
  # Handles multiple filename formats:
  #   "August 2026 Newsletter - ..."
  #   "Gmail - April 2026 Newsletter.html"
  # Extracts month and year from the first occurrence of "Month YYYY".
  m <- str_match(basename(fname), "([A-Za-z]+)\\s+(\\d{4})")
  if (any(is.na(m))) {
    return(NULL)
  }

  month_name  <- tolower(m[1, 2])
  year        <- m[1, 3]
  month_num   <- month_abbr_map[[month_name]]
  month_short <- month_short_map[[month_name]]

  if (is.null(month_num) || is.null(month_short)) {
    return(NULL)
  }

  list(
    month_name = month_name,
    month_num  = month_num,
    year       = year,
    folder     = paste0(month_short, year),      # e.g. "aug2026"
    title      = paste0(str_to_title(m[1, 2]), " ", year),
    date       = paste0(month_num, "/1/", year)
  )
}

write_index_qmd <- function(out_path, info, pdf_name) {
  frontmatter <- list(
    title = info$title,
    date  = info$date,
    image = "logo.png",
    links = list(
      list(icon = "file-earmark-pdf", name = "Download", url = pdf_name)
    )
  )

  body <- sprintf(
    "```{=html}\n<iframe class=\"news ar4x3\" src=\"./%s.html\" title=\"%s Newsletter\"></iframe>\n```",
    info$folder, info$title
  )

  text <- paste(
    "---",
    as.yaml(frontmatter),
    "---",
    "",
    body,
    sep = "\n"
  )

  writeLines(text, out_path)
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------

html_files <- dir_ls(input_dir, glob = "*.html")

if (length(html_files) == 0) {
  message("No HTML files found in ", input_dir)
  quit(status = 0)
}

message("Found ", length(html_files), " file(s) to process:\n",
        paste("  -", path_file(html_files), collapse = "\n"))

for (f in html_files) {
  info <- parse_filename(f)

  if (is.null(info)) {
    warning("Skipping ", path_file(f), ": could not parse month/year from filename.", call. = FALSE)
    next
  }

  # Build output paths
  year_dir  <- path(output_dir, info$year)
  issue_dir <- path(year_dir, info$folder)
  out_html  <- path(issue_dir, paste0(info$folder, ".html"))
  out_pdf   <- path(issue_dir, paste0(info$folder, ".pdf"))
  out_index <- path(issue_dir, "index.qmd")

  message("\n--- Processing: ", info$title, " ---")
  message("  Input:  ", path_file(f))
  message("  Output: ", path_rel(out_index, here()))

  # Create directories
  dir_create(issue_dir, recurse = TRUE)

  # Run R extractor (also extracts leading photo as logo.png)
  logo_path <- path(issue_dir, "logo.png")
  result <- system2(
    command = "Rscript",
    args    = c(shQuote(extractor), shQuote(f), shQuote(out_html), shQuote(logo_path)),
    stdout  = TRUE,
    stderr  = TRUE
  )

  exit_code <- if (!is.null(attr(result, "status"))) attr(result, "status") else 0

  if (exit_code != 0) {
    warning("Failed to extract ", path_file(f), ":\n", paste(result, collapse = "\n"), call. = FALSE)
    next
  }

  if (length(result) > 0) {
    message("  Note: ", paste(result, collapse = "; "))
  }

  # Generate PDF
  message("  Generating PDF...")
  pdf_result <- system2(
    command = "Rscript",
    args    = c(shQuote(pdf_converter), shQuote(out_html), shQuote(out_pdf)),
    stdout  = TRUE,
    stderr  = TRUE
  )
  pdf_exit <- if (!is.null(attr(pdf_result, "status"))) attr(pdf_result, "status") else 0

  if (pdf_exit != 0) {
    warning("Failed to generate PDF for ", path_file(f), ":\n", paste(pdf_result, collapse = "\n"), call. = FALSE)
  } else {
    message("  PDF: ", path_rel(out_pdf, here()))
  }

  # Write index.qmd
  pdf_name <- paste0(info$folder, ".pdf")
  write_index_qmd(out_index, info, pdf_name)
  message("  Done.")
}

message("\nAll done. Review the output in ", output_dir)
