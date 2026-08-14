#' Resource card grid
#'
#' Builds a grid of link cards, each with a Bootstrap icon, a title, and a
#' one-line description. Used on the home page and the resources page.
#'
#' @param content A data frame with columns `category`, `name`, `icon`,
#'   `url`, and `text`, typically built with [rowwise_table()]. `icon` is a
#'   Bootstrap Icons name without the `bi-` prefix.
#' @param title_level Heading level for the card titles (integer 2–6,
#'   default 3). Card titles are real headings, so choose the level that
#'   continues the page outline: one below the heading of the section
#'   containing the grid. Styling is class-based (`.grid__title`), so the
#'   level does not change the cards' appearance.
#'
#' @return An [htmltools::div()] containing the grid markup.
#' @examples
#' content <- rowwise_table(~category, ~name, ~icon, ~url, ~text,
#'                          "general", "Job Posts", "briefcase-fill",
#'                          "jobs/", "Browse recent job listings")
#' resource_grid(content)
#' resource_grid(content, title_level = 2L)  # grid sitting directly under an h1
#' @importFrom htmltools div p a span tags HTML tagList
#' @export
resource_grid <- function(content, title_level = 3L) {
  title_level <- as.integer(title_level)
  if (is.na(title_level) || title_level < 2L || title_level > 6L) {
    stop("`title_level` must be an integer between 2 and 6.", call. = FALSE)
  }
  heading <- tags[[paste0("h", title_level)]]
  cards <- Map(
    function(category, name, icon, url, text) {
      div(
        class = "grid__item",
        heading(
          class = "grid__title",
          tags$i(class = sprintf("bi bi-%s grid__title-icon", icon)),
          HTML("&nbsp;"),
          name
        ),
        p(
          paste0(text, "."),
          a(
            href = url, "aria-label" = sprintf("Go to %s", name),
            span(class = "grid__link-box")
          )
        )
      )
    },
    content$category, content$name, content$icon, content$url, content$text
  )
  div(class = "grid grid-three", tagList(cards))
}
