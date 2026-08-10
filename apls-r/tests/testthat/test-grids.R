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
