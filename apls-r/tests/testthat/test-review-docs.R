make_review_project <- function() {
  project <- tempfile("aplsr-review-project-")
  dir.create(file.path(project, "about"), recursive = TRUE)
  dir.create(file.path(project, "docs", "about"), recursive = TRUE)
  writeLines(
    "---\ntitle: Community Standards\n---\n\nSource text.",
    file.path(project, "about", "index.qmd")
  )
  file.create(file.path(project, "docs", "about", "image.png"))
  writeLines(
    c(
      "<!doctype html><html><body>",
      '<h1 class="title">Community Standards</h1>',
      '<main id="quarto-document-content">',
      "<nav>Page contents</nav>",
      "<p>Review this paragraph.</p>",
      '<div class="panel-tabset">',
      '<ul class="nav nav-tabs"><li><a>Overview</a></li><li><a>Past Recipients</a></li></ul>',
      '<div class="tab-content">',
      '<div class="tab-pane"><p>First tab text.</p></div>',
      '<div class="tab-pane">',
      '<div class="callout"><div class="callout-header"><div class="callout-title-container"><span class="screen-reader-only">Caution</span>Important</div></div><div class="callout-body"><p>Callout text.</p></div></div>',
      '<div class="Reactable" role="table">',
      '<div class="rt-thead" role="rowgroup"><div role="row"><div role="columnheader">Year</div><div role="columnheader">Recipient</div><div role="columnheader">Institution</div></div></div>',
      '<div class="rt-tbody" role="rowgroup"><div role="row"><div role="cell"><div class="rt-td-inner">2026</div></div><div role="cell"><div class="rt-td-inner"><div><div>Example Person</div><div>Small grant</div></div></div></div><div role="cell"><div class="rt-td-inner">Example University</div></div></div></div>',
      "</div></div></div></div>",
      '<div class="cell-code"><pre class="sourceCode">hidden_code()</pre></div>',
      '<img src="image.png" alt="Example">',
      "<script>remove_me()</script>",
      "</main></body></html>"
    ),
    file.path(project, "docs", "about", "index.html")
  )
  project
}

test_that("export_review_doc() creates a clean review copy", {
  project <- make_review_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)
  source <- file.path(project, "about", "index.qmd")
  source_before <- readLines(source)

  local_mocked_bindings(
    run_quarto_pandoc = function(input, output, resource_paths) {
      file.copy(input, output)
      invisible(output)
    },
    .package = "aplsr"
  )

  output <- export_review_doc(
    "about/index.qmd",
    project_root = project,
    date = as.Date("2026-08-26")
  )
  review <- paste(readLines(output), collapse = "\n")

  expect_identical(
    basename(output),
    "Community Standards - Review Copy - 2026-08-26.docx"
  )
  expect_match(review, "Review instructions", fixed = TRUE)
  expect_match(review, "Review this paragraph.", fixed = TRUE)
  expect_match(review, "<h2>Overview</h2>", fixed = TRUE)
  expect_match(review, "<h2>Past Recipients</h2>", fixed = TRUE)
  expect_match(review, "<strong>Important</strong>", fixed = TRUE)
  expect_match(review, "Callout text.", fixed = TRUE)
  expect_match(review, "<table>", fixed = TRUE)
  expect_match(review, "width: 10%", fixed = TRUE)
  expect_match(review, "Example Person - Small grant", fixed = TRUE)
  expect_match(review, "https://ap-ls.org/about/", fixed = TRUE)
  expect_match(
    review,
    normalizePath(
      file.path(project, "docs", "about", "image.png"),
      winslash = "/"
    ),
    fixed = TRUE
  )
  expect_no_match(review, "Page contents", fixed = TRUE)
  expect_no_match(review, "nav-tabs", fixed = TRUE)
  expect_no_match(review, "CautionImportant", fixed = TRUE)
  expect_no_match(review, "hidden_code", fixed = TRUE)
  expect_no_match(review, "remove_me", fixed = TRUE)
  expect_identical(readLines(source), source_before)
})

test_that("custom-layout pages use their role=main content", {
  project <- make_review_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)
  writeLines(
    c(
      "<!doctype html><html><head><title>Custom Home</title></head><body>",
      '<div id="quarto-content"><div role="main">',
      "<h2>Welcome</h2><p>Custom homepage content.</p>",
      "</div></div></body></html>"
    ),
    file.path(project, "docs", "index.html")
  )
  writeLines(
    "---\npagetitle: Custom Home\npage-layout: custom\n---",
    file.path(project, "index.qmd")
  )

  local_mocked_bindings(
    run_quarto_pandoc = function(input, output, resource_paths) {
      file.copy(input, output)
      invisible(output)
    },
    .package = "aplsr"
  )

  output <- export_review_doc(
    "index.qmd",
    project_root = project,
    output_dir = "exports",
    date = as.Date("2026-08-26")
  )
  rendered <- paste(readLines(output, warn = FALSE), collapse = "\n")
  expect_match(rendered, "Custom homepage content", fixed = TRUE)
})

test_that("upload_review_doc() passes a review copy to the Drive uploader", {
  file <- tempfile(fileext = ".docx")
  file.create(file)
  on.exit(unlink(file), add = TRUE)

  local_mocked_bindings(
    drive_upload_review = function(
      file,
      drive_path,
      shared_drive,
      name,
      convert
    ) {
      list(
        file = file,
        drive_path = drive_path,
        shared_drive = shared_drive,
        name = name,
        convert = convert
      )
    },
    .package = "aplsr"
  )

  uploaded <- upload_review_doc(
    file,
    drive_path = "Website Reviews/Governance",
    shared_drive = "AP-LS",
    open = FALSE
  )

  expect_identical(uploaded$drive_path, "Website Reviews/Governance")
  expect_identical(uploaded$shared_drive, "AP-LS")
  expect_identical(uploaded$name, tools::file_path_sans_ext(basename(file)))
  expect_identical(uploaded$convert, TRUE)
})
