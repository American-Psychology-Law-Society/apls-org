# aplsr

Shared R helper functions for the [American Psychology-Law Society
(AP-LS)](https://ap-ls.org) Quarto website.

These functions were extracted from the site's `assets/apls_functions.R` so that
pages can use `library(aplsr)` instead of `source()`-ing a script.

## Installation

```r
# install.packages("pak")
pak::pak("APLS-org/apls-r")
# or:
# remotes::install_github("APLS-org/apls-r")
```

## What's included

**Award tables** (built on [reactable](https://glin.github.io/reactable/)):

- `awards_table()`: year + recipient table (with an optional muted detail
  column for award type / affiliation / advisor).
- `book_awards_table()`: Year / Author / Title, with linked titles.
- `dissertation_table()`: Year / 1st / 2nd / 3rd place.
- `apls_table_theme()`: the shared house style used by all of the above.
- `awards_timeline()`: optional [quarto-timeline](https://emilhvitfeldt.github.io/quarto-timeline/)
  output instead of a table.

**HTML / UI helpers:**

- `carousel()`: a Bootstrap 5 image carousel.
- `create_inline_object()`: an inline icon + link.
- `generate_info_bar()`: an info-bar block.

**Utilities:**

- `rowwise_table()`: build a `data.table` row by row (adapted from
  `mlr3misc`).
- `export_review_doc()`: create a clean Word review copy from a rendered
  website page without modifying its `.qmd` source.
- `upload_review_doc()`: upload that review copy to an existing Google Drive
  folder and convert it to a native Google Doc.
- `review_site_index()`: list the rendered website pages available for review
  and map their public URLs to their `.qmd` sources.
- `publish_review_site()`: create a versioned, resumable Google Drive snapshot
  of the entire rendered website.
- `publish_review_request()`: turn a submitted AP-LS page URL into one Google
  review document.

## Usage in a Quarto page

```r
library(aplsr)

data <- read.csv("../data/saleem-shah.csv")
awards_table(data, name = "name")
```

## Send a page for review in Google Docs

This workflow gives someone an ordinary Google Doc to comment on without
giving them access to the website source. You decide which page to export,
share the Google Doc with the right people, and make any approved changes in
the `.qmd` file yourself.

Start in the website project. If you are working with the local copy of
`aplsr`, load it with:

```r
devtools::load_all("apls-r")
```

Render the full website, then export the page you want reviewed:

```r
review_file <- export_review_doc(
  "awards/grants/impactgrant.qmd",
  overwrite = TRUE
)
```

The Word file is saved in `review-exports/`. It includes the page text, a link
to the live page, and a short note asking reviewers to use Suggesting mode for
wording changes and comments for everything else. The source `.qmd` file is
not changed.

### Connect to Google Drive

The first time you upload a review copy, sign in to the Google account that
has access to the destination folder:

```r
googledrive::drive_auth()
googledrive::drive_user()
```

`drive_user()` shows which account R is using. If it is the wrong account,
sign in again:

```r
googledrive::drive_deauth()
googledrive::drive_auth(email = "your-address@example.com")
```

### Upload to a Google Shared Drive

List the Shared Drives available to the signed-in account:

```r
googledrive::shared_drive_find()$name
```

Copy the drive name exactly as it appears, then upload the review copy to an
existing folder in that drive:

```r
upload_review_doc(
  review_file,
  drive_path = "Website Reviews/Grants",
  shared_drive = "ap-ls.org",
  open = TRUE
)
```

The upload is converted to a native Google Doc by default. Setting
`open = TRUE` opens it in your browser when the upload finishes.

### If the result is `character(0)`

If `shared_drive_find()$name` returns `character(0)`, the signed-in account
cannot see any actual Google Shared Drives. The folder may instead be in My
Drive or under **Shared with me**. The easiest option is to open that folder in
Google Drive, copy its URL from the browser, and use the URL directly:

```r
upload_review_doc(
  review_file,
  drive_path = "https://drive.google.com/drive/folders/FOLDER_ID",
  open = TRUE
)
```

Do not include `shared_drive` when you use a folder URL. If the folder is
supposed to live in a Shared Drive, ask the drive manager to add the account
shown by `drive_user()`, then authenticate again.

The upload function does not change sharing permissions. In Google Drive,
give reviewers **Commenter** access to the document or its folder. They can
then suggest wording and leave requests while you keep control of the website
source.

## Publish the full website for review

Start with a dry run. It finds `.qmd` sources that have a matching rendered
HTML page, excludes drafts and the 404 page, and shows what would be published
without creating local files or contacting Google Drive:

```r
devtools::load_all("apls-r")

site_plan <- publish_review_site(
  drive_path = "Website Reviews/Full Site",
  shared_drive = "ap-ls.org",
  render = TRUE,
  dry_run = TRUE
)

nrow(site_plan)
site_plan[c("source", "live_url", "status")]
```

When the plan looks right, publish it:

```r
site_manifest <- publish_review_site(
  drive_path = "Website Reviews/Full Site",
  shared_drive = "ap-ls.org",
  render = TRUE,
  dry_run = FALSE,
  resume = TRUE
)
```

The function creates the missing Drive folders and a dated folder such as
`Site Snapshot 2026-08-26`. Website subdirectories are reproduced inside that
folder. A local `manifest.csv` records each source page, Google Doc link,
attempt count, and any error. The same manifest is also published as the
stable Google Sheet **AP-LS Website Review Index** in `Website Reviews/Full
Site`. Later snapshots update that Sheet without changing its file ID, so the
website-request automation can reliably match a submitted page URL to its
Google Doc.

After publishing, retrieve the index ID needed during Apps Script setup:

```r
attr(site_manifest, "index_spreadsheet_id")
```

If the connection stops, run the same command again on the same day. With
`resume = TRUE`, completed pages are skipped and failed or unfinished pages
are attempted again. Existing snapshots are not overwritten, preserving
reviewer comments from earlier runs.

To give a snapshot a specific name, set it explicitly in both the original and
resumed commands:

```r
publish_review_site(
  drive_path = "Website Reviews/Full Site",
  shared_drive = "ap-ls.org",
  snapshot_id = "Site Snapshot 2026-08-26",
  render = FALSE,
  dry_run = FALSE,
  resume = TRUE
)
```

Use `render = FALSE` only when the full site was already rendered and the
contents of `docs/` are current.

## Process a submitted page-update request

The website-update Form email contains a ready-to-run command like this:

```r
devtools::load_all("apls-r")

publish_review_request(
  page_url = "https://ap-ls.org/awards/grants/impactgrant.html",
  request_id = "WEB-20260826-001",
  project_root = ".",
  drive_path = "Website Reviews/Requests",
  shared_drive = "ap-ls.org",
  open = TRUE
)
```

The function accepts normal page-address variations, checks that the URL
belongs to `ap-ls.org`, finds its local source, exports the rendered page, and
opens the uploaded Google Doc. It creates missing destination folders and
reuses an exact-name document if the same request is run again. It never
changes the `.qmd` file. Free-text Form answers are not included in the
executable code.

The version-controlled Google Form automation and its one-time setup
instructions live in [`automation/website-update-form`](../automation/website-update-form/README.md).

## Development

```r
devtools::document()
devtools::test()
devtools::check()
```

## License

MIT (c) American Psychology-Law Society.
