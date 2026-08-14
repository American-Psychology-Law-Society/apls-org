#!/usr/bin/env Rscript
#
#
# Reports total site weight, the heaviest pages (HTML plus the local
# images they load), the largest individual assets, images that exceed
# the site's guidelines (over ~1600 px wide or over 300 KB), and PDFs
# over 1 MB.
#
# Usage:
#   Rscript scripts/audit-media.R          # summary report
#   Rscript scripts/audit-media.R --csv    # also write scripts/_audit-*.csv

library(stringr)

DOCS <- here::here("docs")
write_csvs <- "--csv" %in% commandArgs(trailingOnly = TRUE)

fmt_mb <- function(bytes) sprintf("%.2f MB", bytes / 1e6)
fmt_kb <- function(bytes) sprintf("%.0f KB", bytes / 1e3)

# image dimensions without extra packages

png_dims <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  header <- readBin(con, "raw", n = 26)
  if (length(header) < 26 || header[2] != as.raw(0x50)) return(c(NA, NA))
  w <- readBin(header[17:20], "integer", size = 4, endian = "big")
  h <- readBin(header[21:24], "integer", size = 4, endian = "big")
  c(w, h)
}

jpg_dims <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  bytes <- readBin(con, "raw", n = 100000)
  i <- 3L  # skip FFD8
  while (i < length(bytes) - 9) {
    if (bytes[i] != as.raw(0xFF)) { i <- i + 1L; next }
    marker <- as.integer(bytes[i + 1])
    # SOF markers hold dimensions (skip C4, C8, CC which are not SOF)
    if (marker >= 0xC0 && marker <= 0xCF && !marker %in% c(0xC4, 0xC8, 0xCC)) {
      h <- readBin(bytes[(i + 5):(i + 6)], "integer", size = 2, endian = "big")
      w <- readBin(bytes[(i + 7):(i + 8)], "integer", size = 2, endian = "big")
      return(c(w, h))
    }
    seg_len <- readBin(bytes[(i + 2):(i + 3)], "integer", size = 2, endian = "big")
    if (is.na(seg_len) || seg_len < 2) break
    i <- i + 2L + seg_len
  }
  c(NA, NA)
}

# inventory

files <- list.files(DOCS, recursive = TRUE, full.names = TRUE)
sizes <- file.size(files)
keep <- !is.na(sizes)
df <- data.frame(
  rel = sub(paste0("^", DOCS, "/?"), "", files[keep]),
  size = sizes[keep],
  stringsAsFactors = FALSE
)
df$ext <- tolower(tools::file_ext(df$rel))
df$dir1 <- str_extract(df$rel, "^[^/]+")

cat("=== Site totals ===\n")
cat("Files:", nrow(df), " Total:", fmt_mb(sum(df$size)), "\n\n")

groups <- list(
  HTML = "html",
  Images = c("png", "jpg", "jpeg", "gif", "svg", "webp", "ico"),
  PDFs = "pdf",
  `CSS/JS` = c("css", "js"),
  Video = c("mp4", "mov", "webm", "m4v"),
  Fonts = c("woff", "woff2", "ttf", "otf", "eot")
)
for (g in names(groups)) {
  sel <- df$ext %in% groups[[g]]
  cat(sprintf("%-8s %5d files  %9s\n", g, sum(sel), fmt_mb(sum(df$size[sel]))))
}

img <- df[df$ext %in% groups$Images, ]
pdf_df <- df[df$ext == "pdf", ]

# largest individual assets

cat("\n=== 20 largest files ===\n")
top <- head(df[order(-df$size), ], 20)
for (i in seq_len(nrow(top))) cat(sprintf("%9s  %s\n", fmt_mb(top$size[i]), top$rel[i]))

# biggest pages (HTML + local images they reference)

cat("\n=== 15 heaviest pages (HTML + images loaded) ===\n")
html_files <- df$rel[df$ext == "html" & !startsWith(df$rel, "site_libs/")]
page_weight <- function(rel) {
  full <- file.path(DOCS, rel)
  text <- tryCatch(paste(readLines(full, warn = FALSE), collapse = "\n"),
                   error = function(e) "")
  if (!nzchar(text)) return(NA_real_)
  refs <- unlist(str_extract_all(text, "(?i)(?:src|href|poster)\\s*=\\s*\"[^\"]*\""))
  refs <- sub('^[^=]*=\\s*"', "", refs); refs <- sub('"$', "", refs)
  refs <- refs[!grepl("^(https?:|mailto:|tel:|data:|#|//)", refs)]
  refs <- sub("[?#].*$", "", refs)
  img_refs <- refs[tolower(tools::file_ext(refs)) %in% groups$Images]
  total <- file.size(full)
  for (r in img_refs) {
    target <- if (startsWith(r, "/")) file.path(DOCS, sub("^/", "", r))
              else normalizePath(file.path(dirname(full), r), mustWork = FALSE)
    if (file.exists(target)) total <- total + file.size(target)
  }
  total
}
weights <- vapply(html_files, page_weight, numeric(1))
weights <- weights[!is.na(weights)]
wtop <- head(sort(weights, decreasing = TRUE), 15)
for (i in seq_along(wtop)) cat(sprintf("%9s  %s\n", fmt_mb(wtop[i]), names(wtop)[i]))

# images that make size go over the site limit

cat("\n=== Images over limit (> 300 KB or > 1600 px wide) ===\n")
dims <- t(vapply(img$rel, function(r) {
  full <- file.path(DOCS, r)
  ext <- tolower(tools::file_ext(r))
  tryCatch(if (ext == "png") png_dims(full) else if (ext %in% c("jpg", "jpeg")) jpg_dims(full) else c(NA, NA),
           error = function(e) c(NA, NA))
}, numeric(2)))
img$w <- dims[, 1]; img$h <- dims[, 2]
img$flag <- ifelse(img$size > 300e3, "size", ifelse(!is.na(img$w) & img$w > 1600, "width", ""))
bad <- img[img$flag != "", ]
bad <- bad[order(-bad$size), ]
cat("Count:", nrow(bad), " Total:", fmt_mb(sum(bad$size)), "\n\n")

by_dir <- aggregate(size ~ dir1, data = bad, FUN = function(x) c(n = length(x), mb = sum(x)))
for (i in order(-by_dir$size[, "mb"])) {
  cat(sprintf("  %-30s %4d images  %9s\n", by_dir$dir1[i],
              by_dir$size[i, "n"], fmt_mb(by_dir$size[i, "mb"])))
}
cat("\nWorst 15:\n")
for (i in seq_len(min(15, nrow(bad)))) {
  dims_txt <- if (is.na(bad$w[i])) "?" else paste0(bad$w[i], "x", bad$h[i])
  cat(sprintf("%9s  %-11s  %s (%s)\n", fmt_mb(bad$size[i]), dims_txt, bad$rel[i], bad$flag[i]))
}

# PDFs over 1 MB

cat("\n=== PDFs over 1 MB ===\n")
big_pdf <- pdf_df[pdf_df$size > 1e6, ]
big_pdf <- big_pdf[order(-big_pdf$size), ]
cat("Count:", nrow(big_pdf), " Total:", fmt_mb(sum(big_pdf$size)), "\n")
for (i in seq_len(min(15, nrow(big_pdf)))) {
  cat(sprintf("%9s  %s\n", fmt_mb(big_pdf$size[i]), big_pdf$rel[i]))
}
if (nrow(big_pdf) > 15) cat("... and", nrow(big_pdf) - 15, "more\n")

if (write_csvs) {
  write.csv(bad[, c("rel", "size", "w", "h", "flag")], here::here("scripts", "_audit-images.csv"), row.names = FALSE)
  write.csv(big_pdf[, c("rel", "size")], here::here("scripts", "_audit-pdfs.csv"), row.names = FALSE)
  cat("\nWrote scripts/_audit-images.csv and scripts/_audit-pdfs.csv\n")
}
