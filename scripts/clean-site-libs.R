#!/usr/bin/env Rscript
# Post-render cleanup for the built site.
#
# JavaScript source maps (*.map) are developer debugging aids. Browsers only
# request them while devtools is open, so they add weight to the published
# site without helping any visitor. The reactable R package ships fresh
# copies on every render, so this script runs after each `quarto render`
# (wired up via `post-render` in _quarto.yml) to strip them back out.
#
# Also removes reactable R-doc html/ subdirectories. These contain 00Index.html
# files that link to help pages not shipped with the package, producing
# false-positive broken-link reports on every build.
#
# Also adds alt="" to listing-card thumbnail images that lack alt text.
# These are decorative (the card title already describes the item), so
# empty alt is the correct accessibility treatment.

out_dir <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", unset = "docs")
libs <- file.path(out_dir, "site_libs")

# ---- Source maps ----
maps <- list.files(libs, pattern = "[.]map$", recursive = TRUE,
                   full.names = TRUE)

if (length(maps) > 0L) {
  file.remove(maps)
  message("clean-site-libs: removed ", length(maps),
          " source map(s) from ", libs)
} else {
  message("clean-site-libs: no source maps found")
}

# ---- Reactable doc HTML ----
reactable_dirs <- list.dirs(libs, recursive = TRUE)
reactable_dirs <- reactable_dirs[grepl("reactable", reactable_dirs, fixed = TRUE)]
reactable_html_dirs <- reactable_dirs[basename(reactable_dirs) == "html"]

if (length(reactable_html_dirs) > 0L) {
  unlink(reactable_html_dirs, recursive = TRUE)
  message("clean-site-libs: removed ", length(reactable_html_dirs),
          " reactable doc html/ director(y/ies)")
} else {
  message("clean-site-libs: no reactable doc html/ directories found")
}

# ---- Listing thumbnail alt text ----
# Quarto listing grids emit <img loading='lazy'> tags without alt attributes.
# These thumbnails are decorative (the card title describes the item),
# so empty alt text is appropriate.
pages <- list.files(out_dir, pattern = "\\.html$", recursive = TRUE,
                    full.names = TRUE)
fixed_count <- 0L

for (page in pages) {
  html <- paste(readLines(page, warn = FALSE), collapse = "\n")
  original <- html
  html <- gsub(
    '(?i)<img\\s+loading=[\'"]lazy[\'"]([^>]*?)>',
    '<img loading="lazy"\\1 alt="">',
    html,
    perl = TRUE
  )
  if (!identical(html, original)) {
    writeLines(html, page)
    fixed_count <- fixed_count + 1L
  }
}

if (fixed_count > 0L) {
  message("clean-site-libs: added alt text to listing thumbnails in ",
          fixed_count, " page(s)")
} else {
  message("clean-site-libs: no listing thumbnails needed alt text")
}
