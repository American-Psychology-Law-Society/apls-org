#!/usr/bin/env Rscript
# Convert newsletter HTML to PDF for archiving.
#
# Usage: Rscript html_to_pdf.R <input_html> <output_pdf>
#
# Uses pandoc + xelatex (already installed) to convert HTML to PDF.
# Falls back to wkhtmltopdf if available.

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  cat("Usage: Rscript html_to_pdf.R <input_html> <output_pdf>\n")
  quit(status = 1)
}

input_html <- normalizePath(args[1], mustWork = TRUE)
output_pdf <- normalizePath(args[2], mustWork = FALSE)

# 1. Try pandoc + xelatex (no browser needed)
pandoc <- Sys.which("pandoc")
if (nzchar(pandoc)) {
  status <- system2(pandoc,
    args = c(
      shQuote(input_html),
      "-o", shQuote(output_pdf),
      "--pdf-engine=xelatex",
      "-V", "geometry:margin=1in",
      "--resource-path", shQuote(dirname(input_html))
    ),
    stdout = TRUE, stderr = TRUE
  )
  exit_code <- if (!is.null(attr(status, "status"))) attr(status, "status") else 0
  if (exit_code == 0) {
    cat("PDF created with pandoc/xelatex:", output_pdf, "\n")
    quit(status = 0)
  } else {
    message("pandoc failed, trying wkhtmltopdf...")
  }
}

# 2. Try wkhtmltopdf as fallback
wkhtmltopdf <- Sys.which("wkhtmltopdf")
if (nzchar(wkhtmltopdf)) {
  status <- system2(wkhtmltopdf,
    args = c("--enable-local-file-access", shQuote(input_html), shQuote(output_pdf)),
    stdout = TRUE, stderr = TRUE
  )
  exit_code <- if (!is.null(attr(status, "status"))) attr(status, "status") else 0
  if (exit_code == 0) {
    cat("PDF created with wkhtmltopdf:", output_pdf, "\n")
    quit(status = 0)
  }
}

# 3. Skip cleanly if no converter available
cat("PDF skipped (", basename(output_pdf), ").\n")
cat("Install pandoc or wkhtmltopdf for automatic PDF generation.\n")
quit(status = 0)
