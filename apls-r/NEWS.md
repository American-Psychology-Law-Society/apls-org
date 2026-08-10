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
