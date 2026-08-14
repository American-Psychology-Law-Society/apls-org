#!/usr/bin/env Rscript
# One-time (and re-runnable) accessibility pass over the already-archived
# standalone newsletter HTML files. Applies the same sanitizer that
# extract_newsletter.R now runs on new issues, plus document-level fixes
# the extracted fragments never had:
#   - <html lang="en">                 (axe html-has-lang)
#   - <title> from the issue filename  (axe document-title)
#
# Idempotent: attributes that already exist are left alone, so it is safe
# to re-run after editing the sanitizer.
#
# Run from project root:
#   Rscript scripts/sanitize-newsletter-archive.R
#   Rscript scripts/sanitize-newsletter-archive.R --dry-run

suppressPackageStartupMessages({
  library(here)
  library(fs)
  library(xml2)
  library(stringr)
})

source(here("scripts", "extract_newsletter.R"))

dry_run <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)

# Title from filename: "aug2026" -> "August 2026 Newsletter",
# "apr23" -> "April 2023 Newsletter". Falls back to the file stem.
title_from_filename <- function(fname) {
  stem <- path_ext_remove(path_file(fname))
  m <- str_match(stem, "^([a-z]{3})\\s*(\\d{2,4})$")
  if (any(is.na(m))) return(paste(stem, "Newsletter"))
  month <- match(tolower(m[1, 2]), tolower(month.abb))
  year <- as.integer(m[1, 3])
  if (is.na(month)) return(paste(stem, "Newsletter"))
  if (year < 100) year <- year + 2000L
  paste(month.name[month], year, "Newsletter")
}

# Standalone issue files: e-news/YYYY/monYYYY/<issue>.html (anything that
# is not index.html, which is a Quarto page) plus the legacy raw saves in
# e-news/html/.
enews <- here("resources", "newsletter", "e-news")
files <- c(
  dir_ls(path(enews, "html"), glob = "*.html"),
  dir_ls(enews, regexp = "/20\\d\\d/[^/]+/[^/]+[.]html$", recurse = TRUE)
)
files <- files[path_file(files) != "index.html"]

message("Found ", length(files), " archived newsletter file(s).",
        if (dry_run) " (dry run — no files will be written)" else "")

n_changed <- 0L

for (f in files) {
  doc <- read_html(f, encoding = "UTF-8")

  html_el <- xml_find_first(doc, "/html")
  if (!is.na(html_el) && is.na(xml_attr(html_el, "lang"))) {
    xml_attr(html_el, "lang") <- "en"
  }

  # Title: only when missing or empty (raw Gmail saves may carry their own)
  title_el <- xml_find_first(doc, "//head/title")
  if (is.na(title_el)) {
    head_el <- xml_find_first(doc, "//head")
    if (is.na(head_el)) {
      head_el <- xml_add_child(html_el, "head", .where = 0)
    }
    title_el <- xml_add_child(head_el, "title")
  }
  if (trimws(xml_text(title_el)) == "") {
    xml_text(title_el) <- title_from_filename(f)
  }

  sanitize_newsletter_doc(doc)

  if (!dry_run) {
    writeLines(as.character(doc), f, useBytes = TRUE)
  }
  n_changed <- n_changed + 1L
}

message(if (dry_run) "Would sanitize " else "Sanitized ",
        n_changed, " file(s). Re-render the site to copy them into docs/.")
