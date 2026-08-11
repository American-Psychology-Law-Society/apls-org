#!/usr/bin/env Rscript
# Check a PDF file: report page count and extract text from the first 3 pages.
#
# Usage:
#   Rscript scripts/check-pdf.R <pdf-file>
#
# Requires the pdftools R package:
#   install.packages("pdftools")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1L) {
  cat("Usage: Rscript check-pdf.R <pdf-file>\n")
  quit(status = 1)
}

pdf_path <- args[1]

if (!file.exists(pdf_path)) {
  cat("Error: file not found:", pdf_path, "\n")
  quit(status = 1)
}

if (!requireNamespace("pdftools", quietly = TRUE)) {
  cat("Error: the 'pdftools' R package is required.\n")
  cat("Install it with: install.packages('pdftools')\n")
  quit(status = 1)
}

# Get page count via pdf_info
info <- pdftools::pdf_info(pdf_path)
cat("Pages:", info$pages, "\n")

# Extract text from first 3 pages
texts <- pdftools::pdf_text(pdf_path)
for (i in seq_len(min(3L, length(texts)))) {
  txt <- texts[[i]]
  cat(sprintf("Page %d text length: %d\n", i, nchar(txt)))
  if (nzchar(txt)) {
    first_200 <- substr(txt, 1, 200)
    cat(sprintf("  First 200 chars: %s\n", dQuote(first_200)))
  }
}
