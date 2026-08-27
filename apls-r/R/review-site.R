#' Build an index of website pages available for review
#'
#' Finds source `.qmd` files that have a corresponding rendered HTML page.
#' This avoids including drafts, templates, and package documentation that are
#' not part of the published website.
#'
#' @param project_root Path to the Quarto website root.
#' @param site_dir Rendered website directory, relative to `project_root`.
#' @param site_url Public website URL used to construct page links.
#' @param include_404 Whether to include the website's `404.qmd` page.
#'
#' @return A data frame with one row per reviewable website page.
#' @examples
#' \dontrun{
#' review_site_index()
#' }
#' @export
review_site_index <- function(
  project_root = ".",
  site_dir = "docs",
  site_url = "https://ap-ls.org",
  include_404 = FALSE
) {
  check_review_package("xml2")
  project_root <- normalize_existing_directory(project_root, "project_root")
  site_root <- resolve_from_root(site_dir, project_root)
  site_root <- normalize_existing_directory(site_root, "site_dir")

  sources <- list.files(
    project_root,
    pattern = "\\.qmd$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (!length(sources)) {
    return(empty_review_site_index())
  }

  sources <- normalizePath(sources, winslash = "/", mustWork = TRUE)
  root_prefix <- paste0(project_root, "/")
  relative <- substring(sources, nchar(root_prefix) + 1L)
  inside_site_dir <- startsWith(sources, paste0(site_root, "/"))
  relative <- relative[!inside_site_dir]
  sources <- sources[!inside_site_dir]

  drafts <- vapply(sources, review_source_is_draft, logical(1))
  relative <- relative[!drafts]
  sources <- sources[!drafts]

  rendered <- sub("\\.qmd$", ".html", relative, ignore.case = TRUE)
  rendered_paths <- file.path(site_root, rendered)
  keep <- file.exists(rendered_paths)
  if (!isTRUE(include_404)) {
    keep <- keep & basename(relative) != "404.qmd"
  }

  relative <- relative[keep]
  sources <- sources[keep]
  rendered <- gsub("\\\\", "/", rendered[keep])
  rendered_paths <- rendered_paths[keep]
  if (!length(relative)) {
    return(empty_review_site_index())
  }

  titles <- vapply(
    seq_along(relative),
    function(index) {
      document <- xml2::read_html(rendered_paths[[index]])
      review_page_title(document, NULL, relative[[index]])
    },
    character(1)
  )
  sections <- vapply(
    strsplit(relative, "/", fixed = TRUE),
    function(parts) if (length(parts) > 1L) parts[[1L]] else "site",
    character(1)
  )

  result <- data.frame(
    source = relative,
    rendered = rendered,
    title = titles,
    section = sections,
    live_url = vapply(
      rendered,
      review_live_url,
      character(1),
      site_url = site_url
    ),
    source_hash = unname(tools::md5sum(sources)),
    stringsAsFactors = FALSE
  )
  result[order(result$source), , drop = FALSE]
}

empty_review_site_index <- function() {
  data.frame(
    source = character(),
    rendered = character(),
    title = character(),
    section = character(),
    live_url = character(),
    source_hash = character(),
    stringsAsFactors = FALSE
  )
}

review_source_is_draft <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (!length(lines) || trimws(lines[[1L]]) != "---") {
    return(FALSE)
  }
  closing <- which(trimws(lines[-1L]) %in% c("---", "..."))
  if (!length(closing)) {
    return(FALSE)
  }
  front_matter <- lines[seq.int(2L, closing[[1L]])]
  any(grepl(
    "^\\s*draft\\s*:\\s*(true|yes)\\s*(?:#.*)?$",
    front_matter,
    ignore.case = TRUE,
    perl = TRUE
  ))
}

#' Publish a complete website review snapshot to Google Drive
#'
#' Exports every rendered website page as a Word review copy and uploads it as
#' a native Google Doc. A local manifest is updated after every page so an
#' interrupted run can resume without re-uploading completed pages.
#'
#' @param project_root Path to the Quarto website root.
#' @param drive_path Folder path in My Drive or a Google Shared Drive. Missing
#'   folders are created.
#' @param shared_drive Optional exact Shared Drive name.
#' @param site_dir Rendered website directory.
#' @param site_url Public website URL.
#' @param output_dir Local directory for snapshots and manifests.
#' @param snapshot_id Folder name for this snapshot.
#' @param index_name Name of the Google Sheet that maps website URLs to the
#'   current review documents. The same Sheet is updated on later runs so Form
#'   automation can keep using one file ID.
#' @param date Date used in review-document filenames.
#' @param render Whether to render the complete Quarto project first.
#' @param dry_run Whether to return the planned manifest without writing or
#'   uploading anything.
#' @param resume Whether to reuse a matching manifest from an interrupted run.
#' @param include_404 Whether to include the website's 404 page.
#'
#' @return Invisibly, the snapshot manifest as a data frame.
#' @examples
#' \dontrun{
#' publish_review_site(
#'   drive_path = "Website Reviews/Full Site",
#'   shared_drive = "ap-ls.org",
#'   dry_run = TRUE
#' )
#' }
#' @export
publish_review_site <- function(
  project_root = ".",
  drive_path = "Website Reviews/Full Site",
  shared_drive = NULL,
  site_dir = "docs",
  site_url = "https://ap-ls.org",
  output_dir = "review-exports/full-site",
  snapshot_id = paste("Site Snapshot", Sys.Date()),
  index_name = "AP-LS Website Review Index",
  date = Sys.Date(),
  render = TRUE,
  dry_run = TRUE,
  resume = TRUE,
  include_404 = FALSE
) {
  project_root <- normalize_existing_directory(project_root, "project_root")
  validate_snapshot_id(snapshot_id)
  validate_snapshot_id(index_name)
  validate_review_flag(render, "render")
  validate_review_flag(dry_run, "dry_run")
  validate_review_flag(resume, "resume")

  if (isTRUE(render)) {
    render_review_site(project_root)
  }
  index <- review_site_index(
    project_root = project_root,
    site_dir = site_dir,
    site_url = site_url,
    include_404 = include_404
  )
  if (!nrow(index)) {
    stop("No rendered website pages were found.", call. = FALSE)
  }

  snapshot_dir <- file.path(
    resolve_from_root(output_dir, project_root),
    snapshot_id
  )
  manifest_path <- file.path(snapshot_dir, "manifest.csv")
  manifest <- new_review_manifest(index, snapshot_dir, snapshot_id, date)
  if (isTRUE(resume) && file.exists(manifest_path)) {
    manifest <- resume_review_manifest(manifest, manifest_path)
  }
  if (isTRUE(dry_run)) {
    return(invisible(manifest))
  }

  dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)
  snapshot_folder <- drive_snapshot_folder(
    drive_path = drive_path,
    shared_drive = shared_drive,
    snapshot_id = snapshot_id
  )
  write_review_manifest(manifest, manifest_path)

  for (row in seq_len(nrow(manifest))) {
    if (identical(manifest$status[[row]], "uploaded")) {
      next
    }
    manifest$attempts[[row]] <- manifest$attempts[[row]] + 1L
    manifest$error[[row]] <- ""
    manifest$updated_at[[row]] <- review_timestamp()

    tryCatch(
      {
        local_file <- manifest$local_file[[row]]
        if (!file.exists(local_file)) {
          local_file <- export_review_doc(
            page = manifest$source[[row]],
            project_root = project_root,
            site_dir = site_dir,
            output_dir = dirname(local_file),
            site_url = site_url,
            title = manifest$title[[row]],
            date = date,
            overwrite = TRUE
          )
          manifest$local_file[[row]] <- local_file
        }
        manifest$status[[row]] <- "exported"
        manifest$updated_at[[row]] <- review_timestamp()
        write_review_manifest(manifest, manifest_path)

        uploaded <- review_with_retry(function() {
          drive_upload_snapshot_doc(
            file = local_file,
            snapshot_folder = snapshot_folder,
            source = manifest$source[[row]],
            name = tools::file_path_sans_ext(basename(local_file))
          )
        })
        manifest$document_id[[row]] <- drive_result_id(uploaded)
        manifest$document_url[[row]] <- drive_result_url(uploaded)
        manifest$status[[row]] <- "uploaded"
        manifest$updated_at[[row]] <- review_timestamp()
      },
      error = function(error) {
        manifest$status[[row]] <<- "failed"
        manifest$error[[row]] <<- conditionMessage(error)
        manifest$updated_at[[row]] <<- review_timestamp()
      }
    )
    write_review_manifest(manifest, manifest_path)
  }

  index_file <- review_with_retry(function() {
    drive_publish_site_index(
      file = manifest_path,
      drive_path = drive_path,
      shared_drive = shared_drive,
      name = index_name
    )
  })
  index_id <- drive_result_id(index_file)
  index_url <- drive_spreadsheet_url(index_file)
  attr(manifest, "index_spreadsheet_id") <- index_id
  attr(manifest, "index_spreadsheet_url") <- index_url
  message(
    "Website review index ready. Set SITE_INDEX_SPREADSHEET_ID to: ",
    index_id
  )

  invisible(manifest)
}

#' Publish one requested website page for review
#'
#' Resolves a public AP-LS page URL to its local `.qmd` source, creates a
#' review copy, and uploads it as a native Google Doc. The source file is never
#' changed.
#'
#' @param page_url Public URL of the website page to review.
#' @param request_id Safe request identifier, such as `WEB-20260826-001`.
#' @param project_root Path to the Quarto website root.
#' @param drive_path Google Drive folder path for review requests. Missing
#'   folders are created.
#' @param shared_drive Optional exact Shared Drive name.
#' @param site_dir Rendered website directory.
#' @param site_url Public website URL.
#' @param output_dir Local directory for request exports.
#' @param open Whether to open the uploaded Google Doc.
#'
#' @return Invisibly, a list describing the source and uploaded document.
#' @examples
#' \dontrun{
#' publish_review_request(
#'   page_url = "https://ap-ls.org/awards/grants/impactgrant.html",
#'   request_id = "WEB-20260826-001",
#'   drive_path = "Website Reviews/Requests",
#'   shared_drive = "ap-ls.org"
#' )
#' }
#' @export
publish_review_request <- function(
  page_url,
  request_id,
  project_root = ".",
  drive_path = "Website Reviews/Requests",
  shared_drive = NULL,
  site_dir = "docs",
  site_url = "https://ap-ls.org",
  output_dir = "review-exports/requests",
  open = interactive()
) {
  validate_request_id(request_id)
  index <- review_site_index(
    project_root = project_root,
    site_dir = site_dir,
    site_url = site_url
  )
  source <- review_source_from_url(page_url, index, site_url = site_url)
  row <- match(source, index$source)
  request_output <- file.path(output_dir, request_id)

  file <- export_review_doc(
    page = source,
    project_root = project_root,
    site_dir = site_dir,
    output_dir = request_output,
    site_url = site_url,
    title = index$title[[row]],
    overwrite = TRUE
  )
  folder <- review_with_retry(function() {
    drive_request_folder(drive_path, shared_drive)
  })
  uploaded <- review_with_retry(function() {
    drive_upload_named_doc(
      file = file,
      folder = folder,
      name = paste(request_id, index$title[[row]], sep = " - ")
    )
  })
  if (isTRUE(open)) {
    googledrive::drive_browse(uploaded)
  }

  invisible(list(
    request_id = request_id,
    source = source,
    page_url = index$live_url[[row]],
    local_file = file,
    document_id = drive_result_id(uploaded),
    document_url = drive_result_url(uploaded)
  ))
}

review_source_from_url <- function(
  page_url,
  index,
  site_url = "https://ap-ls.org"
) {
  path <- normalize_review_url_path(page_url, site_url)
  indexed_paths <- vapply(
    index$live_url,
    normalize_review_url_path,
    character(1),
    site_url = site_url
  )
  match <- which(indexed_paths == path)
  if (length(match) != 1L) {
    stop(
      "The page URL does not match one rendered website page: ",
      page_url,
      call. = FALSE
    )
  }
  index$source[[match]]
}

normalize_review_url_path <- function(page_url, site_url) {
  if (!is.character(page_url) || length(page_url) != 1L || !nzchar(page_url)) {
    stop("`page_url` must be one non-empty URL.", call. = FALSE)
  }
  if (!is.character(site_url) || length(site_url) != 1L || !nzchar(site_url)) {
    stop("`site_url` must be one non-empty URL.", call. = FALSE)
  }

  page_url <- trimws(page_url)
  page_url <- sub("[?#].*$", "", page_url)
  if (!grepl("^https?://", page_url, ignore.case = TRUE)) {
    stop("`page_url` must be an HTTP or HTTPS URL.", call. = FALSE)
  }
  page_host <- tolower(sub("^https?://([^/]+).*$", "\\1", page_url))
  site_host <- tolower(sub("^https?://([^/]+).*$", "\\1", site_url))
  allowed_hosts <- unique(c(
    site_host,
    sub("^www\\.", "", site_host),
    paste0("www.", sub("^www\\.", "", site_host))
  ))
  if (!page_host %in% allowed_hosts) {
    stop("`page_url` must belong to ", site_host, ".", call. = FALSE)
  }

  path <- sub("^https?://[^/]+", "", page_url, ignore.case = TRUE)
  path <- utils::URLdecode(path)
  path <- sub("^/+", "", path)
  if (grepl("(^|/)\\.\\.(/|$)", path)) {
    stop("`page_url` contains an invalid path.", call. = FALSE)
  }
  if (!nzchar(path)) {
    return("index.html")
  }
  if (endsWith(path, "/")) {
    return(paste0(path, "index.html"))
  }
  if (!grepl("\\.[A-Za-z0-9]+$", path)) {
    path <- paste0(path, ".html")
  }
  path
}

validate_request_id <- function(request_id) {
  valid <- is.character(request_id) &&
    length(request_id) == 1L &&
    !is.na(request_id) &&
    grepl("^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$", request_id)
  if (!valid) {
    stop(
      "`request_id` may contain only letters, numbers, hyphens, and underscores.",
      call. = FALSE
    )
  }
  invisible(request_id)
}

validate_snapshot_id <- function(snapshot_id) {
  if (
    !is.character(snapshot_id) ||
      length(snapshot_id) != 1L ||
      !nzchar(snapshot_id) ||
      grepl("[/\\\\:*?\"<>|]", snapshot_id)
  ) {
    stop("`snapshot_id` must be one safe folder name.", call. = FALSE)
  }
  invisible(snapshot_id)
}

validate_review_flag <- function(value, argument) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop("`", argument, "` must be `TRUE` or `FALSE`.", call. = FALSE)
  }
  invisible(value)
}

render_review_site <- function(project_root) {
  check_review_package("quarto")
  quarto::quarto_render(input = project_root, quiet = TRUE)
  invisible(project_root)
}

new_review_manifest <- function(index, snapshot_dir, snapshot_id, date) {
  local_files <- vapply(
    seq_len(nrow(index)),
    function(row) {
      folder <- dirname(index$source[[row]])
      if (identical(folder, ".")) {
        folder <- ""
      }
      file.path(
        snapshot_dir,
        folder,
        paste0(
          review_filename(index$title[[row]]),
          " - Review Copy - ",
          date,
          ".docx"
        )
      )
    },
    character(1)
  )
  data.frame(
    snapshot_id = rep(snapshot_id, nrow(index)),
    source = index$source,
    rendered = index$rendered,
    title = index$title,
    live_url = index$live_url,
    source_hash = index$source_hash,
    local_file = local_files,
    document_id = rep("", nrow(index)),
    document_url = rep("", nrow(index)),
    status = rep("planned", nrow(index)),
    attempts = integer(nrow(index)),
    error = rep("", nrow(index)),
    updated_at = rep("", nrow(index)),
    stringsAsFactors = FALSE
  )
}

resume_review_manifest <- function(current, manifest_path) {
  previous <- utils::read.csv(
    manifest_path,
    stringsAsFactors = FALSE,
    na.strings = character()
  )
  required <- names(current)
  if (!all(required %in% names(previous))) {
    stop(
      "The existing snapshot manifest has an unexpected format.",
      call. = FALSE
    )
  }
  for (row in seq_len(nrow(current))) {
    old <- which(
      previous$source == current$source[[row]] &
        previous$source_hash == current$source_hash[[row]]
    )
    if (length(old) == 1L) {
      current[row, ] <- previous[old, required, drop = FALSE]
    }
  }
  current
}

write_review_manifest <- function(manifest, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(path, ".tmp")
  utils::write.csv(manifest, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) {
    unlink(temporary)
    stop("Could not update the snapshot manifest.", call. = FALSE)
  }
  invisible(path)
}

review_timestamp <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
}

drive_snapshot_folder <- function(drive_path, shared_drive, snapshot_id) {
  base <- drive_request_folder(drive_path, shared_drive)
  drive_ensure_child_folder(base, snapshot_id)
}

drive_request_folder <- function(drive_path, shared_drive) {
  check_review_package("googledrive")
  if (
    !is.character(drive_path) || length(drive_path) != 1L || !nzchar(drive_path)
  ) {
    stop("`drive_path` must be one non-empty folder path.", call. = FALSE)
  }
  drive <- if (is.null(shared_drive)) {
    googledrive::drive_get(id = "root")
  } else {
    found <- googledrive::shared_drive_get(name = shared_drive)
    if (nrow(found) != 1L) {
      stop(
        "`shared_drive` must identify exactly one Shared Drive.",
        call. = FALSE
      )
    }
    found
  }
  drive_ensure_folder_path(drive, drive_path)
}

drive_ensure_folder_path <- function(parent, path) {
  parts <- strsplit(gsub("\\\\", "/", path), "/", fixed = TRUE)[[1L]]
  parts <- parts[nzchar(parts)]
  for (part in parts) {
    parent <- drive_ensure_child_folder(parent, part)
  }
  parent
}

drive_ensure_child_folder <- function(parent, name) {
  children <- drive_list_children(parent, type = "folder")
  exact <- children[children$name == name, , drop = FALSE]
  if (nrow(exact) > 1L) {
    stop("More than one Drive folder is named `", name, "`.", call. = FALSE)
  }
  if (nrow(exact) == 1L) {
    return(exact)
  }
  drive_create_folder(name, parent)
}

drive_upload_snapshot_doc <- function(file, snapshot_folder, source, name) {
  folder <- snapshot_folder
  relative_folder <- dirname(source)
  if (!identical(relative_folder, ".")) {
    folder <- drive_ensure_folder_path(folder, relative_folder)
  }

  drive_upload_named_doc(file, folder, name)
}

drive_upload_named_doc <- function(file, folder, name) {
  children <- drive_list_children(folder)
  exact <- children[children$name == name, , drop = FALSE]
  if (nrow(exact) > 1L) {
    stop("More than one Drive item is named `", name, "`.", call. = FALSE)
  }
  if (nrow(exact) == 1L) {
    return(exact)
  }
  drive_upload_google_doc(file, folder, name)
}

drive_publish_site_index <- function(file, drive_path, shared_drive, name) {
  folder <- drive_request_folder(drive_path, shared_drive)
  children <- drive_list_children(folder)
  exact <- children[children$name == name, , drop = FALSE]
  if (nrow(exact) > 1L) {
    stop("More than one Drive item is named `", name, "`.", call. = FALSE)
  }
  if (nrow(exact) == 1L) {
    return(drive_update_site_index(exact, file))
  }
  drive_upload_site_index(file, folder, name)
}

drive_update_site_index <- function(index, file) {
  googledrive::drive_update(index, media = file)
}

drive_upload_site_index <- function(file, folder, name) {
  googledrive::drive_upload(
    media = file,
    path = folder,
    name = name,
    type = "spreadsheet",
    overwrite = FALSE
  )
}

drive_list_children <- function(parent, type = NULL) {
  googledrive::drive_ls(path = parent, type = type)
}

drive_create_folder <- function(name, parent) {
  googledrive::drive_mkdir(name = name, path = parent)
}

drive_upload_google_doc <- function(file, folder, name) {
  googledrive::drive_upload(
    media = file,
    path = folder,
    name = name,
    type = googledrive::drive_mime_type("document"),
    overwrite = FALSE
  )
}

review_with_retry <- function(operation, attempts = 3L) {
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    result <- tryCatch(operation(), error = identity)
    if (!inherits(result, "error")) {
      return(result)
    }
    last_error <- result
    if (attempt < attempts) {
      Sys.sleep(2^(attempt - 1L))
    }
  }
  stop(conditionMessage(last_error), call. = FALSE)
}

drive_result_id <- function(uploaded) {
  if (is.data.frame(uploaded) && "id" %in% names(uploaded) && nrow(uploaded)) {
    return(as.character(uploaded$id[[1L]]))
  }
  if (is.list(uploaded) && !is.null(uploaded$id)) {
    return(as.character(uploaded$id[[1L]]))
  }
  ""
}

drive_result_url <- function(uploaded) {
  resources <- if (
    is.data.frame(uploaded) && "drive_resource" %in% names(uploaded)
  ) {
    uploaded$drive_resource
  } else {
    attr(uploaded, "drive_resource", exact = TRUE)
  }
  if (length(resources) && !is.null(resources[[1L]]$webViewLink)) {
    return(as.character(resources[[1L]]$webViewLink))
  }
  id <- drive_result_id(uploaded)
  if (nzchar(id)) {
    return(paste0("https://docs.google.com/document/d/", id, "/edit"))
  }
  ""
}

drive_spreadsheet_url <- function(uploaded) {
  resources <- if (
    is.data.frame(uploaded) && "drive_resource" %in% names(uploaded)
  ) {
    uploaded$drive_resource
  } else {
    attr(uploaded, "drive_resource", exact = TRUE)
  }
  if (length(resources) && !is.null(resources[[1L]]$webViewLink)) {
    return(as.character(resources[[1L]]$webViewLink))
  }
  id <- drive_result_id(uploaded)
  if (nzchar(id)) {
    return(paste0("https://docs.google.com/spreadsheets/d/", id, "/edit"))
  }
  ""
}
