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
#
# Also fixes two ARIA issues emitted by Quarto/shortcode markup (found via
# axe-core audit, _quarto-debug.yml):
#   - {{< fa ... >}} icons carry aria-label on a generic <i>, which is
#     prohibited ARIA (serious). They are decorative, so swap to
#     aria-hidden="true".
#   - Collapsible callout headers are plain <div>s with
#     aria-expanded/aria-label, which a generic div may not carry
#     (critical). They behave as buttons, so add role="button" + tabindex.

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

# ---- Per-page HTML accessibility fixes ----
pages <- list.files(out_dir, pattern = "\\.html$", recursive = TRUE,
                    full.names = TRUE)
alt_pages <- 0L
icon_pages <- 0L
callout_pages <- 0L
scroll_pages <- 0L

for (page in pages) {
  html <- paste(readLines(page, warn = FALSE), collapse = "\n")
  original <- html

  # (a) Listing thumbnail alt text.
  # Quarto listing grids emit <img loading='lazy'> tags without alt
  # attributes. These thumbnails are decorative (the card title describes
  # the item), so empty alt text is appropriate. Only add alt="" when the
  # tag lacks alt entirely — never duplicate an existing alt attribute.
  imgs <- regmatches(html, gregexpr('<img\\b[^>]*>', html, perl = TRUE))[[1]]
  lazy <- imgs[grepl('loading=[\'"]lazy[\'"]', imgs, perl = TRUE)]
  noalt <- unique(lazy[!grepl('alt=', lazy, fixed = TRUE)])
  if (length(noalt) > 0L) {
    for (tg in noalt) {
      html <- gsub(tg, sub('>$', ' alt="">', tg), html, fixed = TRUE)
    }
    alt_pages <- alt_pages + 1L
  }

  # (b) FontAwesome decorative icons.
  # {{< fa ... >}} emits <i class="fa-solid fa-x" aria-label="x">, but
  # aria-label is prohibited on a generic <i> (axe aria-prohibited-attr,
  # serious). The icons are decorative — adjacent text or the link's own
  # aria-label names the target — so swap aria-label for aria-hidden.
  tags <- regmatches(html, gregexpr('<i\\b[^>]*>', html, perl = TRUE))[[1]]
  bad <- unique(tags[grepl('class="[^"]*fa-', tags, perl = TRUE) &
                     grepl('aria-label=', tags, fixed = TRUE) &
                     !grepl('role=', tags, fixed = TRUE)])
  if (length(bad) > 0L) {
    for (tg in bad) {
      fixed_tag <- gsub('\\s*aria-label="[^"]*"', ' aria-hidden="true"', tg)
      html <- gsub(tg, fixed_tag, html, fixed = TRUE)
    }
    icon_pages <- icon_pages + 1L
  }

  # (c) Collapsible callout headers.
  # Quarto renders the toggle as a plain <div> carrying aria-expanded /
  # aria-label, which a generic div may not carry (axe aria-allowed-attr,
  # critical). It behaves as a button, so give it the button role and make
  # it keyboard-focusable.
  new_html <- gsub(
    '(<div class="callout-header[^"]*"[^>]*?data-bs-toggle="collapse")',
    '\\1 role="button" tabindex="0"',
    html,
    perl = TRUE
  )
  if (!identical(new_html, html)) {
    callout_pages <- callout_pages + 1L
    html <- new_html
  }

  # (d) Keyboard-focusable scroll regions.
  # Wide tables/widgets inside .cell-output-display overflow horizontally;
  # without a tab stop keyboard users cannot scroll them (axe
  # scrollable-region-focusable, serious). Only pages that actually render
  # a reactable widget get the tab stop, so plain code-output pages keep
  # their existing tab order. The static markup carries the htmlwidgets
  # mount point (<div class="reactable html-widget">); the ReactTable
  # class only exists after the client-side render.
  if (grepl('class="reactable ', html, fixed = TRUE) ||
      grepl('data-reactable', html, fixed = TRUE)) {
    new_html <- gsub(
      '<div class="cell-output-display([^"]*)"(?![^>]*tabindex)',
      '<div class="cell-output-display\\1" tabindex="0"',
      html,
      perl = TRUE
    )
    if (!identical(new_html, html)) {
      scroll_pages <- scroll_pages + 1L
      html <- new_html
    }
  }

  if (!identical(html, original)) {
    writeLines(html, page)
  }
}

message("clean-site-libs: alt text added in ", alt_pages, " page(s); ",
        "FA icon aria-hidden fixed in ", icon_pages, " page(s); ",
        "callout role=button added in ", callout_pages, " page(s); ",
        "scrollable outputs made focusable in ", scroll_pages, " page(s)")
