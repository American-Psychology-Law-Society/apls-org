make_review_site_project <- function() {
  project <- tempfile("aplsr-review-site-")
  dir.create(file.path(project, "about"), recursive = TRUE)
  dir.create(file.path(project, "awards", "grants"), recursive = TRUE)
  dir.create(file.path(project, "docs", "about"), recursive = TRUE)
  dir.create(file.path(project, "docs", "awards", "grants"), recursive = TRUE)

  writeLines(
    "---\ntitle: About AP-LS\n---\n\nAbout source.",
    file.path(project, "about", "index.qmd")
  )
  writeLines(
    "---\ntitle: Impact Grant\n---\n\nGrant source.",
    file.path(project, "awards", "grants", "impactgrant.qmd")
  )
  writeLines(
    "---\ntitle: Draft\ndraft: true\n---",
    file.path(project, "draft.qmd")
  )
  writeLines("---\ntitle: Not Found\n---", file.path(project, "404.qmd"))

  writeLines(
    paste0(
      '<html><body><h1 class="title">About AP-LS</h1>',
      '<main id="quarto-document-content"><p>About.</p></main></body></html>'
    ),
    file.path(project, "docs", "about", "index.html")
  )
  writeLines(
    paste0(
      '<html><body><h1 class="title">Impact Grant</h1>',
      '<main id="quarto-document-content"><p>Grant.</p></main></body></html>'
    ),
    file.path(project, "docs", "awards", "grants", "impactgrant.html")
  )
  writeLines(
    paste0(
      '<html><body><h1 class="title">Not Found</h1>',
      '<main id="quarto-document-content"><p>Missing.</p></main></body></html>'
    ),
    file.path(project, "docs", "404.html")
  )
  writeLines(
    paste0(
      '<html><body><h1 class="title">Draft</h1>',
      '<main id="quarto-document-content"><p>Draft.</p></main></body></html>'
    ),
    file.path(project, "docs", "draft.html")
  )

  project
}

test_that("review_site_index() includes rendered pages and excludes 404", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)

  index <- review_site_index(project_root = project)

  expect_s3_class(index, "data.frame")
  expect_named(
    index,
    c("source", "rendered", "title", "section", "live_url", "source_hash")
  )
  expect_identical(
    index$source,
    c("about/index.qmd", "awards/grants/impactgrant.qmd")
  )
  expect_identical(
    index$live_url,
    c(
      "https://ap-ls.org/about/",
      "https://ap-ls.org/awards/grants/impactgrant.html"
    )
  )
  expect_identical(any(index$source == "draft.qmd"), FALSE)
  expect_identical(any(index$source == "404.qmd"), FALSE)
  expect_identical(all(nzchar(index$source_hash)), TRUE)
})

test_that("review_site_index() can include the 404 page", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)

  index <- review_site_index(project_root = project, include_404 = TRUE)

  expect_true("404.qmd" %in% index$source)
})

test_that("review page URLs resolve common website variants", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)
  index <- review_site_index(project_root = project)

  expect_identical(
    review_source_from_url("https://ap-ls.org/about/?from=footer#top", index),
    "about/index.qmd"
  )
  expect_identical(
    review_source_from_url(
      "https://www.ap-ls.org/awards/grants/impactgrant",
      index
    ),
    "awards/grants/impactgrant.qmd"
  )
  expect_error(
    review_source_from_url("https://example.org/about/", index),
    "must belong to"
  )
  expect_error(
    review_source_from_url("https://ap-ls.org/not-a-page.html", index),
    "does not match"
  )
})

test_that("publish_review_request() exports the page selected by URL", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)
  exported <- tempfile(fileext = ".docx")
  file.create(exported)
  on.exit(unlink(exported), add = TRUE)

  local_mocked_bindings(
    export_review_doc = function(page, ...) {
      expect_identical(page, "awards/grants/impactgrant.qmd")
      exported
    },
    drive_request_folder = function(drive_path, shared_drive) {
      expect_identical(drive_path, "Website Reviews/Requests")
      expect_identical(shared_drive, "ap-ls.org")
      data.frame(id = "request-folder", name = "Requests")
    },
    drive_upload_named_doc = function(file, folder, name) {
      expect_identical(file, exported)
      expect_identical(folder$id[[1L]], "request-folder")
      expect_identical(name, "WEB-20260826-001 - Impact Grant")
      structure(
        data.frame(id = "google-doc-id"),
        drive_resource = list(list(
          webViewLink = "https://docs.google.com/document/d/google-doc-id/edit"
        ))
      )
    },
    review_with_retry = function(operation, attempts = 3L) operation(),
    .package = "aplsr"
  )

  result <- publish_review_request(
    page_url = "https://ap-ls.org/awards/grants/impactgrant.html",
    request_id = "WEB-20260826-001",
    project_root = project,
    drive_path = "Website Reviews/Requests",
    shared_drive = "ap-ls.org",
    open = FALSE
  )

  expect_identical(result$source, "awards/grants/impactgrant.qmd")
  expect_identical(result$document_id, "google-doc-id")
  expect_identical(
    result$document_url,
    "https://docs.google.com/document/d/google-doc-id/edit"
  )
})

test_that("publish_review_request() rejects unsafe request IDs", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)

  expect_error(
    publish_review_request(
      page_url = "https://ap-ls.org/about/",
      request_id = 'WEB-001\") ; system("bad")',
      project_root = project,
      drive_path = "Website Reviews/Requests",
      open = FALSE
    ),
    "letters, numbers, hyphens, and underscores"
  )
})

test_that("publish_review_site() dry run plans one row per rendered page", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)

  manifest <- publish_review_site(
    project_root = project,
    drive_path = "Website Reviews/Full Site",
    shared_drive = "ap-ls.org",
    snapshot_id = "Site Snapshot 2026-08-26",
    render = FALSE,
    dry_run = TRUE
  )

  expect_s3_class(manifest, "data.frame")
  expect_equal(nrow(manifest), 2L)
  expect_true(all(manifest$status == "planned"))
  expect_true(all(manifest$attempts == 0L))
  expect_true(all(!file.exists(manifest$local_file)))
})

test_that("publish_review_site() checkpoints uploads and resumes", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)
  exports <- 0L
  uploads <- 0L

  local_mocked_bindings(
    drive_snapshot_folder = function(drive_path, shared_drive, snapshot_id) {
      expect_identical(drive_path, "Website Reviews/Full Site")
      expect_identical(shared_drive, "ap-ls.org")
      expect_identical(snapshot_id, "Site Snapshot 2026-08-26")
      list(id = "snapshot-folder")
    },
    export_review_doc = function(page, output_dir, title, date, ...) {
      exports <<- exports + 1L
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      output <- file.path(
        output_dir,
        paste0(title, " - Review Copy - ", date, ".docx")
      )
      file.create(output)
      normalizePath(output, winslash = "/", mustWork = TRUE)
    },
    drive_upload_snapshot_doc = function(file, snapshot_folder, source, name) {
      uploads <<- uploads + 1L
      id <- paste0("doc-", uploads)
      structure(
        data.frame(id = id),
        drive_resource = list(list(
          webViewLink = paste0(
            "https://docs.google.com/document/d/",
            id,
            "/edit"
          )
        ))
      )
    },
    drive_publish_site_index = function(file, drive_path, shared_drive, name) {
      expect_identical(file.exists(file), TRUE)
      expect_identical(drive_path, "Website Reviews/Full Site")
      expect_identical(shared_drive, "ap-ls.org")
      expect_identical(name, "AP-LS Website Review Index")
      structure(
        data.frame(id = "site-index"),
        drive_resource = list(list(
          webViewLink = paste0(
            "https://docs.google.com/spreadsheets/d/site-index/edit"
          )
        ))
      )
    },
    review_with_retry = function(operation, attempts = 3L) operation(),
    .package = "aplsr"
  )

  first <- publish_review_site(
    project_root = project,
    drive_path = "Website Reviews/Full Site",
    shared_drive = "ap-ls.org",
    snapshot_id = "Site Snapshot 2026-08-26",
    date = as.Date("2026-08-26"),
    render = FALSE,
    dry_run = FALSE
  )

  expect_equal(exports, 2L)
  expect_equal(uploads, 2L)
  expect_true(all(first$status == "uploaded"))
  expect_identical(attr(first, "index_spreadsheet_id"), "site-index")
  expect_identical(
    attr(first, "index_spreadsheet_url"),
    "https://docs.google.com/spreadsheets/d/site-index/edit"
  )
  expect_true(file.exists(file.path(
    project,
    "review-exports",
    "full-site",
    "Site Snapshot 2026-08-26",
    "manifest.csv"
  )))

  second <- publish_review_site(
    project_root = project,
    drive_path = "Website Reviews/Full Site",
    shared_drive = "ap-ls.org",
    snapshot_id = "Site Snapshot 2026-08-26",
    date = as.Date("2026-08-26"),
    render = FALSE,
    dry_run = FALSE,
    resume = TRUE
  )

  expect_equal(exports, 2L)
  expect_equal(uploads, 2L)
  expect_true(all(second$status == "uploaded"))
})

test_that("publish_review_site() records a page failure and continues", {
  project <- make_review_site_project()
  on.exit(unlink(project, recursive = TRUE), add = TRUE)

  local_mocked_bindings(
    drive_snapshot_folder = function(...) list(id = "snapshot-folder"),
    export_review_doc = function(page, output_dir, title, date, ...) {
      if (identical(page, "about/index.qmd")) {
        stop("Example export failure")
      }
      dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      output <- file.path(
        output_dir,
        paste0(title, " - Review Copy - ", date, ".docx")
      )
      file.create(output)
      output
    },
    drive_upload_snapshot_doc = function(...) data.frame(id = "uploaded"),
    drive_publish_site_index = function(...) data.frame(id = "site-index"),
    review_with_retry = function(operation, attempts = 3L) operation(),
    .package = "aplsr"
  )

  manifest <- publish_review_site(
    project_root = project,
    drive_path = "Website Reviews/Full Site",
    snapshot_id = "Site Snapshot 2026-08-26",
    date = as.Date("2026-08-26"),
    render = FALSE,
    dry_run = FALSE
  )

  expect_identical(manifest$status, c("failed", "uploaded"))
  expect_match(manifest$error[[1L]], "Example export failure", fixed = TRUE)
  expect_identical(manifest$attempts, c(1L, 1L))
})

test_that("empty sites and invalid publishing options fail clearly", {
  project <- tempfile("aplsr-empty-site-")
  dir.create(file.path(project, "docs"), recursive = TRUE)
  on.exit(unlink(project, recursive = TRUE), add = TRUE)

  expect_equal(nrow(review_site_index(project_root = project)), 0L)
  expect_error(
    publish_review_site(
      project_root = project,
      render = FALSE,
      dry_run = TRUE
    ),
    "No rendered website pages"
  )
  expect_error(
    publish_review_site(
      project_root = project,
      snapshot_id = "bad/folder",
      render = FALSE
    ),
    "safe folder name"
  )
  expect_error(
    publish_review_site(project_root = project, render = NA),
    "must be `TRUE` or `FALSE`"
  )
})

test_that("Drive result helpers support real dribble-like columns", {
  uploaded <- data.frame(id = "doc-id", stringsAsFactors = FALSE)
  uploaded$drive_resource <- I(list(list(
    webViewLink = "https://docs.google.com/document/d/doc-id/edit"
  )))

  expect_identical(drive_result_id(uploaded), "doc-id")
  expect_identical(
    drive_result_url(uploaded),
    "https://docs.google.com/document/d/doc-id/edit"
  )
  expect_identical(
    drive_result_url(data.frame(id = "fallback-id")),
    "https://docs.google.com/document/d/fallback-id/edit"
  )
  expect_identical(drive_result_id(list()), "")
  expect_identical(drive_result_url(list()), "")
})

test_that("Drive folder helpers reuse exact folders and create missing ones", {
  parent <- data.frame(id = "parent", name = "parent")
  existing <- data.frame(id = "child", name = "Awards")
  created <- data.frame(id = "new", name = "About")

  local_mocked_bindings(
    drive_list_children = function(parent, type = NULL) existing,
    drive_create_folder = function(name, parent) stop("should not create"),
    .package = "aplsr"
  )
  expect_identical(drive_ensure_child_folder(parent, "Awards"), existing)

  local_mocked_bindings(
    drive_list_children = function(parent, type = NULL) existing[0, ],
    drive_create_folder = function(name, parent) {
      expect_identical(name, "About")
      created
    },
    .package = "aplsr"
  )
  expect_identical(drive_ensure_child_folder(parent, "About"), created)
})

test_that("snapshot uploads reuse an exact existing document", {
  file <- tempfile(fileext = ".docx")
  file.create(file)
  on.exit(unlink(file), add = TRUE)
  folder <- data.frame(id = "folder", name = "folder")
  existing <- data.frame(id = "doc", name = "About - Review Copy")

  local_mocked_bindings(
    drive_ensure_folder_path = function(parent, path) parent,
    drive_list_children = function(parent, type = NULL) existing,
    drive_upload_google_doc = function(...) stop("should not upload"),
    .package = "aplsr"
  )

  result <- drive_upload_snapshot_doc(
    file,
    snapshot_folder = folder,
    source = "about/index.qmd",
    name = "About - Review Copy"
  )
  expect_identical(result, existing)
})

test_that("site index publishing updates one stable Google Sheet", {
  file <- tempfile(fileext = ".csv")
  file.create(file)
  on.exit(unlink(file), add = TRUE)
  folder <- data.frame(id = "folder", name = "Full Site")
  existing <- data.frame(
    id = "site-index",
    name = "AP-LS Website Review Index"
  )

  local_mocked_bindings(
    drive_request_folder = function(drive_path, shared_drive) folder,
    drive_list_children = function(parent, type = NULL) existing,
    drive_update_site_index = function(index, file) {
      expect_identical(index, existing)
      expect_identical(file.exists(file), TRUE)
      index
    },
    drive_upload_site_index = function(...) stop("should not upload"),
    .package = "aplsr"
  )

  result <- drive_publish_site_index(
    file,
    drive_path = "Website Reviews/Full Site",
    shared_drive = "ap-ls.org",
    name = "AP-LS Website Review Index"
  )
  expect_identical(result, existing)
  expect_identical(
    drive_spreadsheet_url(data.frame(id = "fallback-id")),
    "https://docs.google.com/spreadsheets/d/fallback-id/edit"
  )
})

test_that("retry helper returns successes and preserves final errors", {
  expect_identical(review_with_retry(function() "ok"), "ok")
  expect_error(
    review_with_retry(function() stop("Drive unavailable"), attempts = 1L),
    "Drive unavailable"
  )
})
