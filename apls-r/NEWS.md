# aplsr 0.4.0

* `export_review_doc()` supports custom-layout pages, including the website
  homepage, by using their explicit main-content region.
* `publish_review_request()` accepts a public AP-LS page URL and request ID,
  then creates and uploads the corresponding single-page review document.
* `publish_review_site()` creates a versioned, resumable Google Drive snapshot
  of the rendered website, with a checkpoint manifest and per-page errors. It
  also maintains a stable Google Sheet index used to find each review document
  from its public page URL.
* `review_site_index()` maps rendered website pages to their source files and
  public URLs while excluding `draft: true` sources even when stale rendered
  HTML remains in the output directory.

# aplsr 0.3.0

* `export_review_doc()` turns a rendered AP-LS website page into a Word review
  copy while leaving the source `.qmd` file alone.
* `upload_review_doc()` sends that copy to an existing My Drive or Shared Drive
  folder and can convert it to a Google Doc for comments and suggested edits.

# aplsr 0.2.2

* `resource_grid()` gains a `title_level` argument (default 3, unchanged
  behavior) so pages can match card titles to the surrounding heading
  outline. The homepage grid sits directly under an h1, so its h3 titles
  skipped a level (axe heading-order violation); it now uses
  `title_level = 2`.

# aplsr 0.2.1

* `carousel()` slides now carry their caption as the image `alt` text.
  Screen readers used to announce the linked slides with no name at all.

# aplsr 0.2.0

* New `resource_grid()` helper: builds the grid of icon link cards used on
  the home page and the resources page. Both pages previously carried their
  own copy of this function, and the two copies had drifted apart.

# aplsr 0.1.1

* Table colors now use the site's CSS variables (`--apls-primary`,
  `--apls-fg`, `--apls-muted`) with the original hex values as fallbacks.
  Award tables used to render dark text on the dark-mode page background,
  which made names and headers unreadable.

# aplsr 0.1.0

* Initial package. Migrates the core reusable helpers from the AP-LS
  website's `assets/apls_functions.R`:
  * Award tables: `awards_table()`, `book_awards_table()`,
    `dissertation_table()`, `apls_table_theme()`, `awards_timeline()`.
  * HTML/UI helpers: `carousel()`, `create_inline_object()`,
    `generate_info_bar()`.
  * Utility: `rowwise_table()`.
