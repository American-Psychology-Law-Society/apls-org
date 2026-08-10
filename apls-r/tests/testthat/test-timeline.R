test_that("awards_timeline() emits timeline fenced divs newest-first", {
  df <- data.frame(
    year = c(2024, 2026),
    content = c("**Older**", "**Newer**")
  )
  out <- paste(capture.output(awards_timeline(df)), collapse = "\n")
  expect_match(out, "::: \\{.timeline")
  expect_match(out, 'data-label="2026"')
  # newest year should appear before the older one
  expect_lt(regexpr("2026", out), regexpr("2024", out))
})
