#' Bootstrap image carousel
#'
#' Builds a Bootstrap 5 "carousel" component from a list of items.
#'
#' @param id The carousel element id.
#' @param duration Slide interval in milliseconds.
#' @param items A list of items, each a list with `caption`, `image`, and
#'   `link` elements.
#'
#' @return An [htmltools::div()] containing the carousel markup.
#' @examples
#' carousel("gallery", 5000,
#'          list(list(caption = "One", image = "a.png", link = "#")))
#' @importFrom htmltools div a img tags span tagList tagAppendAttributes
#' @export
carousel <- function(id, duration, items) {
  index <- -1
  items <- lapply(items, function(item) {
    index <<- index + 1
    carouselItem(item$caption, item$image, item$link, index, duration)
  })

  indicators <- div(
    class = "carousel-indicators",
    tagList(lapply(items, function(item) item$button))
  )
  items <- div(
    class = "carousel-inner",
    tagList(lapply(items, function(item) item$item))
  )
  div(
    id = id, class = "carousel carousel-dark slide", `data-bs-ride` = "carousel",
    indicators,
    items,
    navButton(id, "prev", "Previous"),
    navButton(id, "next", "Next")
  )
}

# Internal: a single carousel slide (button + item).
carouselItem <- function(caption, image, link, index, interval) {
  button <- tags$button(
    type = "button",
    `data-bs-target` = "#gallery-carousel",
    `data-bs-slide-to` = index,
    `aria-label` = paste("Slide", index + 1)
  )
  if (index == 0) {
    button <- tagAppendAttributes(
      button, class = "active", `aria-current` = "true"
    )
  }
  item <- div(
    class = paste0("carousel-item", ifelse(index == 0, " active", "")),
    `data-bs-interval` = interval,
    a(href = link, img(src = image, class = "d-block  mx-auto border", alt = caption)),
    div(
      class = "carousel-caption d-none d-md-block",
      tags$p(class = "fw-light", caption)
    )
  )
  list(button = button, item = item)
}

# Internal: previous/next navigation control for the carousel.
navButton <- function(targetId, type, text) {
  tags$button(
    class = paste0("carousel-control-", type),
    type = "button",
    `data-bs-target` = paste0("#", targetId),
    `data-bs-slide` = type,
    span(class = paste0("carousel-control-", type, "-icon"), `aria-hidden` = "true"),
    span(class = "visually-hidden", text)
  )
}

#' Inline icon + link span
#'
#' Returns an HTML string for an inline Font Awesome icon followed by a link.
#'
#' @param icon Font Awesome icon name (without the `fa-` prefix).
#' @param text Link text.
#' @param url Link URL.
#'
#' @return A length-one character vector of HTML.
#' @examples
#' create_inline_object("envelope", "Email us", "mailto:office@ap-ls.org")
#' @export
create_inline_object <- function(icon, text, url) {
  sprintf(
    '<span class="inline-object"><i class="fa fa-%s"></i><a href="%s">%s</a></span>',
    icon, url, text
  )
}

#' Info bar with icon, title, text, and call-to-action
#'
#' Returns an HTML string for a horizontal "info bar" block.
#'
#' @param info A list with `icon`, `title`, `text`, `link`, and `ctr`
#'   (call-to-action label) elements.
#'
#' @return A length-one character vector of HTML.
#' @examples
#' generate_info_bar(list(icon = "fa fa-star", title = "Title",
#'                        text = "Body", link = "#", ctr = "Learn more"))
#' @export
generate_info_bar <- function(info) {
  info_bar_icon_class   <- "info-bar__icon"
  info_bar_text_class   <- "info-bar__text"
  info_bar_title_class  <- "info-bar__title"
  info_bar_center_class <- "info-bar__center"

  paste0(
    "<div class=info-bar container mt-3>",
    "<div class=class=d-flex justify-content-around mb-3'>",
    "<div class='", info_bar_icon_class, "' class=p-2'>",
    "<i class='", info$icon, "'></i>",
    "</div>",
    "<div class='", info_bar_text_class, "' class=p-2'>",
    "<h3 class='", info_bar_title_class, "'>", info$title, "</h3>",
    "<p class='lead'>", info$text, "</p>",
    "</div>",
    "<div class='", info_bar_center_class, "' class=p-2'>",
    "<a href='", info$link, "' class='btn btn-outline-primary'>", info$ctr, "</a>",
    "</div>",
    "</div>",
    "</div>"
  )
}
