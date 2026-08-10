#!/usr/bin/env Rscript
# Post-render cleanup for the built site.
#
# JavaScript source maps (*.map) are developer debugging aids. Browsers only
# request them while devtools is open, so they add weight to the published
# site without helping any visitor. The reactable R package ships fresh
# copies on every render, so this script runs after each `quarto render`
# (wired up via `post-render` in _quarto.yml) to strip them back out.

out_dir <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", unset = "docs")
libs <- file.path(out_dir, "site_libs")

maps <- list.files(libs, pattern = "[.]map$", recursive = TRUE,
                   full.names = TRUE)

if (length(maps) > 0L) {
  file.remove(maps)
  message("clean-site-libs: removed ", length(maps),
          " source map(s) from ", libs)
} else {
  message("clean-site-libs: no source maps found")
}
