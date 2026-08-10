# aplsr

Shared R helper functions for the [American Psychology-Law Society
(AP-LS)](https://ap-ls.org) Quarto website.

These functions were extracted from the site's `assets/apls_functions.R` so that
pages can use `library(aplsr)` instead of `source()`-ing a script.

## Installation

```r
# install.packages("pak")
pak::pak("APLS-org/apls-r")
# or:
# remotes::install_github("APLS-org/apls-r")
```

## What's included (v0.1.0)

**Award tables** (built on [reactable](https://glin.github.io/reactable/)):

- `awards_table()`: year + recipient table (with an optional muted detail
  column for award type / affiliation / advisor).
- `book_awards_table()`: Year / Author / Title, with linked titles.
- `dissertation_table()`: Year / 1st / 2nd / 3rd place.
- `apls_table_theme()`: the shared house style used by all of the above.
- `awards_timeline()`: optional [quarto-timeline](https://emilhvitfeldt.github.io/quarto-timeline/)
  output instead of a table.

**HTML / UI helpers:**

- `carousel()`: a Bootstrap 5 image carousel.
- `create_inline_object()`: an inline icon + link.
- `generate_info_bar()`: an info-bar block.

**Utilities:**

- `rowwise_table()`: build a `data.table` row by row (adapted from
  `mlr3misc`).

## Usage in a Quarto page

```r
library(aplsr)

data <- read.csv("../data/saleem-shah.csv")
awards_table(data, name = "name")
```

## Development

```r
devtools::document()
devtools::test()
devtools::check()
```

## License

MIT (c) American Psychology-Law Society.
