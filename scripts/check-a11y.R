#!/usr/bin/env Rscript
# Accessibility audit of the built site (docs/).
#
# Scans every rendered page for common, mechanically checkable
# accessibility problems: missing alt text, links with no accessible
# name, heading hierarchy issues, duplicate IDs, unnamed iframes,
# tables without header cells, and more.
#
# Archived e-news email HTML is historical content and is skipped.
# Usage:
#   Rscript scripts/check-a11y.R          # summary
#   Rscript scripts/check-a11y.R --full   # every finding, page by page
# Or from RStudio, at the project root: source("scripts/check-a11y.R")

library(rvest)
library(xml2)

DOCS <- here::here("docs")

SKIP_PREFIXES <- c("site_libs/", "search.html", "resources/newsletter/e-news/")

add_issue <- function(issues, rule, rel, detail = "") {
  issues[[rule]] <- c(issues[[rule]], list(list(page = rel, detail = detail)))
  issues
}

audit_file <- function(path, rel, issues) {
  page <- tryCatch(read_html(path), error = function(e) NULL)
  if (is.null(page)) return(issues)

  body <- html_element(page, "body")
  # Draft pages render as empty stubs and are not public content.
  if (is.na(body) || !nzchar(trimws(html_text2(body)))) return(issues)

  root <- xml_root(page)
  lang <- xml_attr(root, "lang")
  if (is.na(lang) || !nzchar(lang)) {
    issues <- add_issue(issues, "page missing lang attribute", rel)
  }

  for (img in html_elements(page, "img")) {
    if (is.na(html_attr(img, "alt"))) {
      src <- html_attr(img, "src")
      issues <- add_issue(issues, "img missing alt", rel,
                          substr(if (is.na(src)) "?" else src, 1, 80))
    }
  }

  for (a in html_elements(page, "a")) {
    # Hidden from assistive tech on purpose (decorative/dead links).
    if (identical(html_attr(a, "aria-hidden"), "true")) next
    name <- trimws(html_text2(a))
    for (attr in c("aria-label", "aria-labelledby", "title")) {
      val <- html_attr(a, attr)
      if (!nzchar(name) && !is.na(val) && nzchar(val)) name <- val
    }
    if (nzchar(name)) next
    inner <- xml_find_first(a, ".//img[@alt]")
    if (!is.na(inner) && nzchar(trimws(xml_attr(inner, "alt")))) next
    
    icon <- xml_find_first(a, ".//*[@role='img' and @aria-label]")
    if (!is.na(icon) && nzchar(trimws(xml_attr(icon, "aria-label")))) next
    svg_title <- xml_find_first(a, ".//*[local-name()='svg']/*[local-name()='title']")
    if (!is.na(svg_title)) next
    href <- html_attr(a, "href")
    issues <- add_issue(issues, "link with no accessible name", rel,
                        substr(if (is.na(href)) "" else href, 1, 80))
  }

  h1s <- html_elements(page, "h1")
  if (length(h1s) == 0) {
    issues <- add_issue(issues, "page missing h1", rel)
  } else if (length(h1s) > 1) {
    issues <- add_issue(issues, "page has multiple h1", rel,
                        paste(length(h1s), "h1 elements"))
  }

  prev <- 0L
  for (h in html_elements(page, "h1, h2, h3, h4, h5, h6")) {
    cls <- html_attr(h, "class")
    cls <- if (is.na(cls)) "" else cls
    
    if (grepl("listing-title", cls, fixed = TRUE) ||
        grepl("quarto-listing-category-title", cls, fixed = TRUE)) next
    # Inside a panel-tabset, the tab heading becomes the tab label
    in_tab <- xml_find_first(h, "ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' tab-pane ')]")
    if (!is.na(in_tab)) next
    level <- as.integer(sub("^h", "", xml_name(h)))
    if (prev > 0 && level > prev + 1) {
      issues <- add_issue(issues, "heading level skipped", rel,
                          sprintf("h%d -> h%d: %s", prev, level,
                                  substr(trimws(html_text2(h)), 1, 40)))
      break
    }
    prev <- level
  }

  ids <- html_attr(html_elements(page, "[id]"), "id")
  # Quarto intentionally emits these once per theme variant
  ids <- ids[!ids %in% c("quarto-text-highlighting-styles", "quarto-bootstrap")]
  dup <- names(table(ids))[table(ids) > 1]
  for (id_value in dup) {
    issues <- add_issue(issues, "duplicate id", rel,
                        sprintf("#%s x%d", id_value, sum(ids == id_value)))
  }

  for (tag in html_elements(page, "[tabindex]")) {
    val <- suppressWarnings(as.integer(html_attr(tag, "tabindex")))
    if (!is.na(val) && val > 0) {
      issues <- add_issue(issues, "positive tabindex", rel, as.character(val))
    }
  }

  for (tbl in html_elements(page, "table")) {
    if (length(html_elements(tbl, "th")) == 0) {
      cls <- html_attr(tbl, "class")
      issues <- add_issue(issues, "table without header cells", rel,
                          substr(if (is.na(cls)) "" else cls, 1, 60))
    }
  }

  for (frame in html_elements(page, "iframe")) {
    title <- html_attr(frame, "title")
    if (is.na(title) || !nzchar(title)) {
      src <- html_attr(frame, "src")
      issues <- add_issue(issues, "iframe missing title", rel,
                          substr(if (is.na(src)) "" else src, 1, 80))
    }
  }

  issues
}

main <- function(show_all = FALSE) {
  pages <- list.files(DOCS, pattern = "\\.html$", recursive = TRUE,
                      full.names = TRUE)
  rels <- substr(pages, nchar(DOCS) + 2, nchar(pages))
  keep <- !vapply(rels, function(r) any(startsWith(r, SKIP_PREFIXES)),
                  logical(1))
  pages <- pages[keep]
  rels <- rels[keep]

  issues <- list()
  for (i in seq_along(pages)) {
    issues <- audit_file(pages[i], rels[i], issues)
  }

  cat("Audited", length(pages), "pages.\n\n")
  if (length(issues) == 0) {
    cat("No issues found.\n")
    return(0L)
  }

  total <- 0L
  rules <- names(issues)[order(-vapply(issues, length, integer(1)))]
  for (rule in rules) {
    hits <- issues[[rule]]
    total <- total + length(hits)
    cat(rule, ": ", length(hits), "\n", sep = "")
    shown <- if (show_all) hits else head(hits, 10)
    for (hit in shown) {
      suffix <- if (nzchar(hit$detail)) paste0("  (", hit$detail, ")") else ""
      cat("    ", hit$page, suffix, "\n", sep = "")
    }
    if (!show_all && length(hits) > 10) {
      cat("    ... and ", length(hits) - 10, " more (use --full)\n", sep = "")
    }
    cat("\n")
  }
  cat(total, "total issues.\n")
  1L
}

status <- main("--full" %in% commandArgs(trailingOnly = TRUE))
if (sys.nframe() == 0L) quit(status = status)
