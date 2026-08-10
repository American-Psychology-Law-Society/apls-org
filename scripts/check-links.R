#!/usr/bin/env Rscript
# Scan rendered HTML in docs/ for local src/href references that don't
# resolve to a real file. Catches broken images, banners, and links after
# file moves/deletions. Skips external URLs, anchors, and mailto/tel.
#
# Usage:
#   Rscript scripts/check-links.R
# Or from RStudio, at the project root: source("scripts/check-links.R")

library(stringr)

DOCS <- here::here("docs")

SKIP_SCHEMES <- c("http", "https", "mailto", "tel", "ftp", "data", "javascript")

# Lexically normalize an absolute path: collapse "." and ".." without
# requiring the path to exist.
normalize_path <- function(path) {
  parts <- strsplit(path, "/", fixed = TRUE)[[1]]
  out <- character(0)
  for (p in parts) {
    if (p %in% c("", ".")) next
    if (p == "..") {
      if (length(out) > 0) out <- out[-length(out)]
    } else {
      out <- c(out, p)
    }
  }
  paste0("/", paste(out, collapse = "/"))
}

is_broken <- function(ref, page_dir) {
  ref <- trimws(ref)
  if (!nzchar(ref) || startsWith(ref, "#")) return(FALSE)
  if (startsWith(ref, "//")) return(FALSE)
  scheme <- str_match(ref, "^([a-zA-Z][a-zA-Z0-9+.-]*):")[, 2]
  if (!is.na(scheme) && scheme %in% SKIP_SCHEMES) return(FALSE)
  path <- utils::URLdecode(sub("[?#].*$", "", ref))
  if (!nzchar(path)) return(FALSE)
  target <- if (startsWith(path, "/")) {
    file.path(DOCS, sub("^/", "", path))
  } else {
    file.path(DOCS, page_dir, path)
  }
  target <- normalize_path(target)
  if (file.exists(target) || dir.exists(target)) return(FALSE)
  # directory link -> index.html inside it counts as fine
  if (file.exists(paste0(target, ".html")) ||
      file.exists(file.path(target, "index.html"))) return(FALSE)
  TRUE
}

main <- function() {
  pages <- list.files(DOCS, pattern = "\\.html$", recursive = TRUE,
                      full.names = TRUE)
  broken <- list()
  for (full in pages) {
    html <- tryCatch(paste(readLines(full, warn = FALSE), collapse = "\n"),
                     error = function(e) "")
    if (!nzchar(html)) next
    refs <- unlist(str_extract_all(
      html, "(?i)(?:src|href|poster|data-src)\\s*=\\s*\"[^\"]*\""))
    refs <- sub('^[^=]*=\\s*"', "", refs)
    refs <- sub('"$', "", refs)
    page_dir <- dirname(sub(paste0("^", DOCS, "/?"), "", full))
    rel_page <- sub(paste0("^", DOCS, "/?"), "", full)
    for (ref in unique(refs)) {
      if (is_broken(ref, page_dir)) {
        broken[[ref]] <- union(broken[[ref]], rel_page)
      }
    }
  }
  if (length(broken) == 0) {
    cat("No broken local references found.\n")
    return(0L)
  }
  for (ref in sort(names(broken))) {
    hits <- sort(broken[[ref]])
    cat("BROKEN: ", ref, "\n", sep = "")
    for (p in head(hits, 5)) cat("    in ", p, "\n", sep = "")
    if (length(hits) > 5) {
      cat("    ... and ", length(hits) - 5, " more pages\n", sep = "")
    }
  }
  cat("\n", length(broken), " unique broken references.\n", sep = "")
  1L
}

status <- main()
if (sys.nframe() == 0L) quit(status = status)
