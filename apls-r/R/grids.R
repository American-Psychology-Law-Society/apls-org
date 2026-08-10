#' Resource card grid
#'
#' Builds a grid of link cards, each with a Bootstrap icon, a title, and a
#' one-line description. Used on the home page and the resources page.
#'
#' @param content A data frame with columns `category`, `name`, `icon`,
#'   `url`, and `text`, typically built with [rowwise_table()]. `icon` is a
#'   Bootstrap Icons name without the `bi-` prefix.
#'
#' @return An [htmltools::div()] containing the grid markup.
#' @examples
#' content <- rowwise_table(~category, ~name, ~icon, ~url, ~text,
#'                          "general", "Job Posts", "briefcase-fill",
#'                          "jobs/", "Browse recent job listings")
#' resource_grid(content)
#' @importFrom htmltools div h3 p a span tags HTML tagList
#' @export
resource_grid <- function(content) {
  cards <- Map(
    function(category, name, icon, url, text) {
      div(
        class = "grid__item",
        h3(
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
