test_that("rowwise_table() builds a data.table with named columns", {
  tab <- rowwise_table(
    ~a, ~b,
    1,  "x",
    2,  "y"
  )
  expect_s3_class(tab, "data.table")
  expect_identical(names(tab), c("a", "b"))
  expect_identical(nrow(tab), 2L)
})

test_that("rowwise_table() rejects non-rectangular input", {
  expect_error(rowwise_table(~a, ~b, 1), "rectangular")
})

test_that("rowwise_table() needs at least one column name", {
  expect_error(rowwise_table(1, 2), "No column names")
})
