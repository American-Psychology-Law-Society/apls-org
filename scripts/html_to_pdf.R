#!/usr/bin/env Rscript
# Convert an HTML file to PDF using headless Chrome via pagedown.
#
# Usage: Rscript html_to_pdf.R <input_html> <output_pdf>
#
# Requires the pagedown R package and a Chrome/Chromium installation.
# Automatically detects Playwright's Chromium if available.

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  cat("Usage: Rscript html_to_pdf.R <input_html> <output_pdf>\n")
  quit(status = 1)
}

input_html <- normalizePath(args[1], mustWork = TRUE)
output_pdf <- normalizePath(args[2], mustWork = FALSE)

if (!requireNamespace("pagedown", quietly = TRUE)) {
  cat("Error: the 'pagedown' R package is required.\n")
  cat("Install it with: install.packages('pagedown')\n")
  quit(status = 1)
}

# Auto-detect Chrome/Chromium, preferring Playwright's installation
find_chrome <- function() {
  # Try Playwright's Chromium first
  pw_dir <- file.path(Sys.getenv("HOME"), "Library", "Caches", "ms-playwright")
  if (dir.exists(pw_dir)) {
    chromium_dirs <- list.dirs(pw_dir, recursive = FALSE, full.names = TRUE)
    chromium_dirs <- chromium_dirs[grepl("chromium-", basename(chromium_dirs))]
    if (length(chromium_dirs) > 0) {
      # Sort by version number to get the newest
      versions <- as.integer(sub("chromium-", "", basename(chromium_dirs)))
      newest <- chromium_dirs[which.max(versions)]
      candidate <- file.path(newest, "chrome-mac-arm64",
        "Google Chrome for Testing.app", "Contents", "MacOS",
        "Google Chrome for Testing")
      if (file.exists(candidate)) return(candidate)
      # Try x64 variant
      candidate <- file.path(newest, "chrome-mac",
        "Google Chrome for Testing.app", "Contents", "MacOS",
        "Google Chrome for Testing")
      if (file.exists(candidate)) return(candidate)
    }
  }

  # Fallback: system Chrome locations
  candidates <- c(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser"
  )
  for (c in candidates) {
    if (file.exists(c)) return(c)
  }

  NULL
}

chrome_path <- find_chrome()
if (is.null(chrome_path)) {
  cat("ERROR: Could not find Chrome or Chromium.\n")
  cat("Please install Chrome, or install Playwright Chromium:\n")
  cat("  python3 -m playwright install chromium\n")
  quit(status = 1)
}

Sys.setenv(PAGEDOWN_CHROME = chrome_path)

tryCatch({
  pagedown::chrome_print(
    input = input_html,
    output = output_pdf,
    wait = 2,
    timeout = 60,
    verbose = FALSE
  )
  cat("PDF created:", output_pdf, "\n")
}, error = function(e) {
  cat("ERROR: Failed to generate PDF:\n", conditionMessage(e), "\n")
  quit(status = 1)
})
