test_that("apls_table_theme() returns a reactable theme", {
  expect_s3_class(apls_table_theme(), "reactableTheme")
})

test_that("awards_table() returns an htmltools tag", {
  df <- data.frame(year = c(2025, 2024), name = c("A. Smith", "B. Jones"))
  out <- awards_table(df)
  expect_s3_class(out, "shiny.tag")
})

test_that("awards_table() accepts a detail column", {
  df <- data.frame(
    year = 2025, name = "A. Smith", detail = "Early Career"
  )
  expect_s3_class(awards_table(df, detail = "detail"), "shiny.tag")
})

test_that("book_awards_table() returns an htmltools tag", {
  df <- data.frame(
    year = "2026", author = "Ed.", title = "A Book",
    url = "https://example.org", img = ""
  )
  expect_s3_class(book_awards_table(df), "shiny.tag")
})

test_that("dissertation_table() returns an htmltools tag", {
  df <- data.frame(year = 2026, first = "A", second = "B", third = "C")
  expect_s3_class(dissertation_table(df), "shiny.tag")
})
