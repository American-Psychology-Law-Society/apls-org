test_that("resource_grid() returns an htmltools tag with one card per row", {
  content <- rowwise_table(~category, ~name, ~icon, ~url, ~text,
                           "general", "Job Posts", "briefcase-fill",
                           "jobs/", "Browse recent job listings",
                           "general", "Videos", "play-circle",
                           "videos/", "Webinars and talks")
  out <- resource_grid(content)
  expect_s3_class(out, "shiny.tag")
  html <- as.character(out)
  expect_match(html, "grid grid-three", fixed = TRUE)
  expect_match(html, "bi bi-briefcase-fill", fixed = TRUE)
  # two rows in, two cards out
  expect_equal(lengths(regmatches(html, gregexpr("grid__item", html, fixed = TRUE))), 2)
  # template appends the trailing period
  expect_match(html, "Browse recent job listings.", fixed = TRUE)
})

test_that("resource_grid() title_level controls the card heading tag", {
  content <- rowwise_table(~category, ~name, ~icon, ~url, ~text,
                           "general", "Job Posts", "briefcase-fill",
                           "jobs/", "Browse recent job listings")
  # default stays h3 (backward compatible)
  expect_match(as.character(resource_grid(content)),
               '<h3 class="grid__title">', fixed = TRUE)
  # h2 for a grid sitting directly under an h1 (homepage)
  expect_match(as.character(resource_grid(content, title_level = 2L)),
               '<h2 class="grid__title">', fixed = TRUE)
  expect_match(as.character(resource_grid(content, title_level = 4)),
               '<h4 class="grid__title">', fixed = TRUE)
  # invalid levels are rejected
  expect_error(resource_grid(content, title_level = 1L))
  expect_error(resource_grid(content, title_level = 7L))
})
