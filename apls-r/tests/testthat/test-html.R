test_that("create_inline_object() returns an HTML string", {
  out <- create_inline_object("envelope", "Email", "mailto:x@y.z")
  expect_type(out, "character")
  expect_length(out, 1)
  expect_match(out, "inline-object")
  expect_match(out, "mailto:x@y.z", fixed = TRUE)
})

test_that("generate_info_bar() returns an HTML string", {
  out <- generate_info_bar(
    list(icon = "fa fa-star", title = "T", text = "B", link = "#", ctr = "Go")
  )
  expect_type(out, "character")
  expect_match(out, "info-bar")
})

test_that("carousel() returns an htmltools tag", {
  items <- list(list(caption = "c", image = "i.png", link = "#"))
  expect_s3_class(carousel("gallery", 5000, items), "shiny.tag")
  # slide images use the caption as alt text
  expect_match(as.character(carousel("gallery", 5000, items)), 'alt="c"',
               fixed = TRUE)
})
