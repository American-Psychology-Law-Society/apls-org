# aplsr

Shared R helpers for the AP-LS Quarto site. Edit package code here; install or load this local package from the website project.

## Install and develop

```r
pak::pak("APLS-org/apls-r")
# During local development, from the website project:
devtools::load_all("apls-r")
```

The package supplies award tables/timelines and themes, carousel and page UI helpers, `rowwise_table()`, and Google Docs review helpers (`export_review_doc()`, `upload_review_doc()`, `review_site_index()`, `publish_review_site()`, `publish_review_request()`). Check function help in R for arguments.

## Export one page for review

Render the site first, then run from the website project root:

```r
review_file <- export_review_doc("awards/grants/impactgrant.qmd", overwrite = TRUE)
```

The Word file is written under `review-exports/`. Authenticate with the Google account that can access the destination folder, then upload:

```r
googledrive::drive_auth()
upload_review_doc(review_file, drive_path = "Website Reviews/Grants",
                  shared_drive = "ap-ls.org", open = TRUE)
```

For a folder outside a Shared Drive, use its Drive folder URL as `drive_path` and omit `shared_drive`. Sharing permissions are managed in Drive.

## Publish the full review snapshot

Preview the eligible rendered pages with a dry run:

```r
site_plan <- publish_review_site(
  drive_path = "Website Reviews/Full Site", shared_drive = "ap-ls.org",
  render = TRUE, dry_run = TRUE
)
```

When the plan is correct, publish/resume it:

```r
site_manifest <- publish_review_site(
  drive_path = "Website Reviews/Full Site", shared_drive = "ap-ls.org",
  render = TRUE, dry_run = FALSE, resume = TRUE
)
attr(site_manifest, "index_spreadsheet_id")
```

The index spreadsheet ID is used by the website-update Form automation. Keep the same snapshot ID when resuming a named snapshot. Set `render = FALSE` only when `docs/` is current. Existing snapshots preserve reviewer comments.

## Process a website-update request

Use the validated command from the administrator notification; typical form:

```r
publish_review_request(
  page_url = "https://ap-ls.org/awards/grants/impactgrant.html",
  request_id = "WEB-20260826-001", project_root = ".",
  drive_path = "Website Reviews/Requests", shared_drive = "ap-ls.org",
  open = TRUE
)
```

Only use the submitted AP-LS page URL and generated request ID. Reviewers comment on the Google Doc; apply approved edits to the `.qmd` source yourself.

## Package changes

Run `devtools::document()` after changing exported functions or documentation, and update `NAMESPACE`/`man/` through roxygen. Keep Google Drive authentication interactive; never store credentials in the package.
