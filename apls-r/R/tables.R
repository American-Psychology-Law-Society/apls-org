#' Shared reactable theme for AP-LS award tables
#'
#' House style used by all award "past recipients" tables: a brand-navy header
#' rule, transparent rows (so the page background shows through), thin neutral
#' separators, and a subtle navy hover.
#'
#' @return A [reactable::reactableTheme()] object.
#' @examples
#' apls_table_theme()
#' @export
apls_table_theme <- function() {
  reactable::reactableTheme(
    style           = list(fontFamily = "inherit"),
    backgroundColor = "transparent",
    headerStyle     = list(
      color         = "var(--apls-primary, #1B3264)",
      fontWeight    = 600,
      borderBottom  = "2px solid var(--apls-primary, #1B3264)",
      paddingBottom = "6px"
    ),
    borderColor     = "rgba(0,0,0,0.08)",
    highlightColor  = "rgba(27,50,100,0.06)",
    cellPadding     = "10px 14px"
  )
}

#' Year-grouped award recipients table
#'
#' Renders a two- (or three-) column table of award recipients by year, in the
#' shared house style. Used for awards with one or more named recipients per
#' year (e.g. Saleem Shah, Distinguished Contributions, Teaching, Undergraduate).
#'
#' @param data A data frame with at least a year column and a recipient-name
#'   column. Extra columns are hidden unless named in `detail`.
#' @param name Name of the recipient column. Default `"name"`.
#' @param detail Optional name of a column shown as a muted second column
#'   (e.g. award type, affiliation, advisor). Default `NULL`.
#' @param group Name of the year column to sort and label by. Default `"year"`.
#' @param page_size Rows per page. Default `60`.
#'
#' @return An [htmltools::div()] wrapping a [reactable::reactable()] widget.
#' @examples
#' df <- data.frame(year = c(2025, 2024), name = c("A. Smith", "B. Jones"))
#' awards_table(df)
#' @export
awards_table <- function(data, name = "name", detail = NULL,
                         group = "year", page_size = 60) {
  data <- as.data.frame(data)

  cols <- list()
  cols[[group]] <- reactable::colDef(
    name = "Year", maxWidth = 110, align = "left",
    style = list(fontWeight = 700, color = "var(--apls-primary, #1B3264)", fontSize = "1.05rem")
  )
  cols[[name]] <- reactable::colDef(
    name = "Recipient",
    style = list(fontWeight = 600, color = "var(--apls-fg, #1f2937)")
  )
  if (!is.null(detail)) {
    cols[[detail]] <- reactable::colDef(
      name = "", vAlign = "center", align = "left",
      style = list(color = "var(--apls-muted, #6c757d)")
    )
  }
  for (cn in setdiff(names(data), c(group, name, detail))) {
    cols[[cn]] <- reactable::colDef(show = FALSE)
  }

  sorted <- list("desc")
  names(sorted) <- group

  tbl <- reactable::reactable(
    data,
    defaultPageSize = page_size,
    defaultSorted   = sorted,
    static          = TRUE,
    sortable        = FALSE,
    striped         = FALSE,
    highlight       = TRUE,
    theme           = apls_table_theme(),
    defaultColDef   = reactable::colDef(vAlign = "center", align = "left"),
    columns         = cols
  )
  htmltools::div(tbl, style = "max-width: 620px;")
}

#' Book award table
#'
#' Renders the Lawrence S. Wrightsman Book Award recipients as a
#' Year / Author / Title table, with the title linked to `url` when present.
#'
#' @param data A data frame with columns `year`, `author`, `title`, `url`, and
#'   (optionally) `img`.
#' @param page_size Rows per page. Default `20`.
#'
#' @return An [htmltools::div()] wrapping a [reactable::reactable()] widget.
#' @examples
#' df <- data.frame(
#'   year = "2026", author = "Ed.", title = "A Book",
#'   url = "https://example.org", img = ""
#' )
#' book_awards_table(df)
#' @export
book_awards_table <- function(data, page_size = 20) {
  data <- as.data.frame(data)

  tbl <- reactable::reactable(
    data,
    defaultPageSize = page_size,
    defaultSorted   = list(year = "desc"),
    static          = TRUE,
    sortable        = FALSE,
    striped         = FALSE,
    highlight       = TRUE,
    theme           = apls_table_theme(),
    defaultColDef   = reactable::colDef(vAlign = "center", align = "left"),
    columns = list(
      year = reactable::colDef(
        name = "Year", maxWidth = 90,
        style = list(fontWeight = 700, color = "var(--apls-primary, #1B3264)")
      ),
      author = reactable::colDef(
        name = "Author", maxWidth = 230,
        style = list(fontWeight = 600, color = "var(--apls-fg, #1f2937)")
      ),
      title = reactable::colDef(
        name = "Title", html = TRUE, align = "left",
        cell = function(value, index) {
          url <- data$url[index]
          if (!is.na(url) && nzchar(url)) {
            sprintf('<a href="%s" target="_blank">%s</a>', url, value)
          } else {
            value
          }
        }
      ),
      url = reactable::colDef(show = FALSE),
      img = reactable::colDef(show = FALSE)
    )
  )
  htmltools::div(tbl, style = "max-width: 860px;")
}

#' Dissertation award table
#'
#' Renders the dissertation awards as a Year / 1st / 2nd / 3rd place table.
#'
#' @param data A data frame with columns `year`, `first`, `second`, `third`.
#' @param page_size Rows per page. Default `60`.
#'
#' @return An [htmltools::div()] wrapping a [reactable::reactable()] widget.
#' @examples
#' df <- data.frame(year = 2026, first = "A", second = "B", third = "C")
#' dissertation_table(df)
#' @export
dissertation_table <- function(data, page_size = 60) {
  data <- as.data.frame(data)

  place <- function(label) {
    reactable::colDef(name = label, vAlign = "center", align = "left", html = TRUE)
  }

  tbl <- reactable::reactable(
    data,
    defaultPageSize = page_size,
    defaultSorted   = list(year = "desc"),
    static          = TRUE,
    sortable        = FALSE,
    striped         = FALSE,
    highlight       = TRUE,
    theme           = apls_table_theme(),
    defaultColDef   = reactable::colDef(vAlign = "center", align = "left"),
    columns = list(
      year   = reactable::colDef(
        name = "Year", minWidth = 80, maxWidth = 110,
        style = list(fontWeight = 700, color = "var(--apls-primary, #1B3264)")
      ),
      first  = place("1st place"),
      second = place("2nd place"),
      third  = place("3rd place")
    )
  )
  htmltools::div(tbl, style = "max-width: 960px;")
}

#' Emit a quarto-timeline from award data
#'
#' Prints Pandoc fenced-div markup for the
#' \href{https://emilhvitfeldt.github.io/quarto-timeline/}{quarto-timeline}
#' extension. MUST be called from a chunk with `#| output: asis`, and the page
#' must enable the filter (`quarto add EmilHvitfeldt/quarto-timeline` and
#' `filters: [timeline]` in the YAML). Rows sharing a `label` (year) are grouped
#' under one marker by the extension.
#'
#' @param data A data frame.
#' @param label Name of the column used as the marker label (year).
#'   Default `"year"`.
#' @param content Name of a column holding the markdown shown for each entry.
#'   Default `"content"`.
#' @param classes Character vector of timeline classes. Default
#'   `c("timeline", "vertical-alt", "tl-card")`.
#' @param style Optional inline CSS (e.g. `--tl-color-*` overrides) applied to
#'   the outer `.timeline` div. Default `NULL`.
#'
#' @return Invisibly `NULL`; called for the side effect of `cat()`-ing markup.
#' @examples
#' df <- data.frame(year = 2026, content = "**A. Smith**")
#' awards_timeline(df)
#' @export
awards_timeline <- function(data, label = "year", content = "content",
                            classes = c("timeline", "vertical-alt", "tl-card"),
                            style = NULL) {
  data <- as.data.frame(data)
  ord  <- order(suppressWarnings(as.numeric(data[[label]])), decreasing = TRUE)
  data <- data[ord, , drop = FALSE]

  cls <- paste(paste0(".", classes), collapse = " ")
  style_attr <- if (!is.null(style)) paste0(" style=\"", style, "\"") else ""
  cat("::: {", cls, style_attr, "}\n\n", sep = "")
  for (i in seq_len(nrow(data))) {
    cat("::: {.event data-label=\"", as.character(data[[label]][i]), "\"}\n", sep = "")
    cat(data[[content]][i], "\n", sep = "")
    cat(":::\n\n")
  }
  cat(":::\n")
  invisible(NULL)
}


#' Member directory table with country flags
#'
#' Renders a sortable, searchable directory table showing members with small
#' circular flag icons next to their names. Uses the shared house style plus
#' flag images from flagcdn.com.
#'
#' @param data A data frame. Required columns: `first_name`, `last_name`,
#'   `degree`, `city`, `state`, `country`. An optional `deceased` column is
#'   accepted but hidden.
#' @param page_size Rows per page. Default `60`.
#'
#' @return An [htmltools::div()] wrapping a [reactable::reactable()] widget.
#' @examples
#' df <- data.frame(
#'   first_name = "Jane", last_name = "Doe", degree = "PhD",
#'   city = "Lincoln", state = "NE", country = "United States",
#'   stringsAsFactors = FALSE
#' )
#' member_directory_table(df)
#' @export
member_directory_table <- function(data, page_size = 60) {
  data <- as.data.frame(data)

  # Build a clean display name
  data$name <- paste(data$first_name, data$last_name)

  # Build location string
  data$location <- ifelse(
    is.na(data$city) & is.na(data$state), "",
    ifelse(is.na(data$city), as.character(data$state),
           ifelse(is.na(data$state), as.character(data$city),
                  paste0(data$city, ", ", data$state)))
  )

  # Country code for flags — try countrycode if available, else fall back
  iso2 <- NULL
  if (requireNamespace("countrycode", quietly = TRUE)) {
    iso2 <- countrycode::countrycode(
      data$country, origin = "country.name", destination = "iso2c",
      warn = FALSE
    )
  }
  if (is.null(iso2)) {
    iso2 <- toupper(substr(data$country, 1, 2))
  }
  data$country_code <- iso2

  tbl <- reactable::reactable(
    data,
    defaultPageSize = page_size,
    static          = TRUE,
    sortable        = TRUE,
    searchable      = TRUE,
    striped         = FALSE,
    highlight       = TRUE,
    theme           = apls_table_theme(),
    defaultColDef   = reactable::colDef(vAlign = "center", align = "left"),
    columns = list(
      first_name   = reactable::colDef(show = FALSE),
      last_name    = reactable::colDef(show = FALSE),
      city         = reactable::colDef(show = FALSE),
      state        = reactable::colDef(show = FALSE),
      country      = reactable::colDef(show = FALSE),
      country_code = reactable::colDef(show = FALSE),
      deceased     = reactable::colDef(show = FALSE),
      name = reactable::colDef(
        name = "Name", minWidth = 180,
        style = list(fontWeight = 600, color = "var(--apls-fg, #1f2937)"),
        cell = function(value, index) {
          code <- data$country_code[index]
          flag_url <- if (!is.na(code)) {
            paste0("https://flagcdn.com/w40/", tolower(code), ".png")
          } else {
            ""
          }
          htmltools::div(
            style = "display:flex;align-items:center;gap:10px;",
            if (nzchar(flag_url)) {
              htmltools::img(
                src = flag_url,
                alt = paste(data$country[index], "flag"),
                style = "width:22px;height:22px;border-radius:50%;object-fit:cover;"
              )
            },
            htmltools::span(value)
          )
        }
      ),
      degree = reactable::colDef(
        name = "Degree", maxWidth = 140,
        style = list(color = "var(--apls-muted, #6c757d)")
      ),
      location = reactable::colDef(
        name = "Location", minWidth = 160,
        style = list(color = "var(--apls-muted, #6c757d)")
      )
    )
  )
  htmltools::div(tbl, style = "max-width: 800px;")
}
