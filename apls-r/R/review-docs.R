#' Export a website page as a Word review copy
#'
#' Builds a Word review copy from a page in the rendered AP-LS website. The
#' copy includes the source path, live page URL, export date, and a short note
#' for reviewers. The source `.qmd` file is read but never changed.
#'
#' The website must be rendered first. Reading the rendered HTML keeps
#' computed content in the review copy and avoids rendering one website page
#' in isolation.
#'
#' @param page Path to a source `.qmd` page, relative to `project_root` or as
#'   an absolute path.
#' @param project_root Path to the Quarto website root. Defaults to the current
#'   working directory.
#' @param site_dir Rendered website directory, relative to `project_root`.
#'   Defaults to `"docs"`.
#' @param output_dir Directory for generated review copies, relative to
#'   `project_root` or as an absolute path. Defaults to `"review-exports"`.
#' @param site_url Public website URL used to construct a link to the live
#'   page. Use `NULL` to omit the link.
#' @param title Optional review-document title. By default, the title is read
#'   from the rendered page.
#' @param date Export date included in the document and filename.
#' @param include_code Whether to retain displayed source-code blocks.
#'   Defaults to `FALSE`.
#' @param overwrite Whether to replace an existing export with the same name.
#'
#' @return The absolute path to the generated `.docx` file.
#' @examples
#' \dontrun{
#' export_review_doc("awards/grants/impactgrant.qmd")
#' }
#' @export
export_review_doc <- function(
  page,
  project_root = ".",
  site_dir = "docs",
  output_dir = "review-exports",
  site_url = "https://ap-ls.org",
  title = NULL,
  date = Sys.Date(),
  include_code = FALSE,
  overwrite = FALSE
) {
  check_review_package("xml2")
  check_review_package("quarto")

  page_info <- review_page_info(
    page = page,
    project_root = project_root,
    site_dir = site_dir,
    site_url = site_url
  )
  prepared <- prepare_review_html(
    html = page_info$html,
    source = page_info$source,
    live_url = page_info$live_url,
    title = title,
    date = date,
    site_root = page_info$site_root,
    include_code = include_code
  )

  output_dir <- resolve_from_root(output_dir, page_info$project_root)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output <- file.path(
    output_dir,
    paste0(review_filename(prepared$title), " - Review Copy - ", date, ".docx")
  )

  if (file.exists(output) && !isTRUE(overwrite)) {
    stop(
      "Review copy already exists: ",
      output,
      ". Use `overwrite = TRUE` to replace it.",
      call. = FALSE
    )
  }
  if (file.exists(output)) {
    unlink(output)
  }

  input <- tempfile("aplsr-review-", fileext = ".html")
  on.exit(unlink(input), add = TRUE)
  xml2::write_html(prepared$document, input, options = "format")

  run_quarto_pandoc(
    input = input,
    output = output,
    resource_paths = c(dirname(page_info$html), page_info$site_root)
  )
  if (!file.exists(output)) {
    stop("Quarto did not create the review document.", call. = FALSE)
  }

  normalizePath(output, winslash = "/", mustWork = TRUE)
}

#' Upload a Word review copy to Google Drive
#'
#' Uploads a file created by [export_review_doc()] to an existing folder in My
#' Drive or a Google Shared Drive. The Word file is converted to a native
#' Google Doc by default, ready for comments and suggested edits.
#'
#' This function does not manage sharing. Set access in Google Drive after the
#' upload; Commenter access is usually the right choice for reviewers.
#'
#' @param file Path to a `.docx` review copy.
#' @param drive_path Existing folder path or Google Drive folder URL.
#' @param shared_drive Optional name of a Google Shared Drive. Leave this as
#'   `NULL` for a My Drive path or when `drive_path` is a folder URL.
#' @param name Optional Google Drive filename. The default removes the `.docx`
#'   extension when converting to Google Docs.
#' @param convert Whether to convert the upload to a native Google Doc.
#' @param open Whether to open the uploaded document in a browser.
#'
#' @return Invisibly, a [googledrive::dribble] describing the uploaded file.
#' @examples
#' \dontrun{
#' file <- export_review_doc("awards/grants/impactgrant.qmd")
#' upload_review_doc(
#'   file,
#'   drive_path = "Website Reviews/Grants",
#'   shared_drive = "ap-ls.org",
#'   open = TRUE
#' )
#' }
#' @export
upload_review_doc <- function(
  file,
  drive_path,
  shared_drive = NULL,
  name = NULL,
  convert = TRUE,
  open = interactive()
) {
  check_review_package("googledrive")

  if (!is.character(file) || length(file) != 1L || !file.exists(file)) {
    stop("`file` must identify an existing review document.", call. = FALSE)
  }
  if (!identical(tolower(tools::file_ext(file)), "docx")) {
    stop("`file` must be a `.docx` review document.", call. = FALSE)
  }
  if (
    !is.character(drive_path) || length(drive_path) != 1L || !nzchar(drive_path)
  ) {
    stop(
      "`drive_path` must be an existing Google Drive folder path or URL.",
      call. = FALSE
    )
  }
  if (
    !is.null(shared_drive) &&
      (!is.character(shared_drive) ||
        length(shared_drive) != 1L ||
        !nzchar(shared_drive))
  ) {
    stop("`shared_drive` must be `NULL` or a non-empty name.", call. = FALSE)
  }

  if (is.null(name)) {
    name <- if (isTRUE(convert)) {
      tools::file_path_sans_ext(basename(file))
    } else {
      basename(file)
    }
  }

  uploaded <- drive_upload_review(
    file = normalizePath(file, winslash = "/", mustWork = TRUE),
    drive_path = drive_path,
    shared_drive = shared_drive,
    name = name,
    convert = convert
  )
  if (isTRUE(open)) {
    googledrive::drive_browse(uploaded)
  }

  invisible(uploaded)
}

check_review_package <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(
      "Package `",
      package,
      "` is required for this operation.",
      call. = FALSE
    )
  }
}

review_page_info <- function(page, project_root, site_dir, site_url) {
  if (!is.character(page) || length(page) != 1L || !nzchar(page)) {
    stop("`page` must be a path to one `.qmd` file.", call. = FALSE)
  }
  if (!identical(tolower(tools::file_ext(page)), "qmd")) {
    stop("`page` must be a `.qmd` file.", call. = FALSE)
  }

  project_root <- normalize_existing_directory(project_root, "project_root")
  page_path <- resolve_from_root(page, project_root)
  if (!file.exists(page_path)) {
    stop("Source page does not exist: ", page_path, call. = FALSE)
  }
  page_path <- normalizePath(page_path, winslash = "/", mustWork = TRUE)
  root_prefix <- paste0(project_root, "/")
  if (!startsWith(page_path, root_prefix)) {
    stop("`page` must be inside `project_root`.", call. = FALSE)
  }

  source <- substring(page_path, nchar(root_prefix) + 1L)
  rendered_relative <- sub("\\.qmd$", ".html", source, ignore.case = TRUE)
  site_root <- resolve_from_root(site_dir, project_root)
  html <- file.path(site_root, rendered_relative)
  if (!file.exists(html)) {
    stop(
      "Rendered page does not exist: ",
      html,
      ". Render the full website before exporting a review copy.",
      call. = FALSE
    )
  }

  list(
    project_root = project_root,
    site_root = normalizePath(site_root, winslash = "/", mustWork = TRUE),
    source = source,
    html = normalizePath(html, winslash = "/", mustWork = TRUE),
    live_url = review_live_url(rendered_relative, site_url)
  )
}

prepare_review_html <- function(
  html,
  source,
  live_url,
  title,
  date,
  site_root,
  include_code
) {
  document <- xml2::read_html(html)
  main <- xml2::xml_find_first(
    document,
    "//*[@id='quarto-document-content'] | //*[@role='main']"
  )
  if (inherits(main, "xml_missing")) {
    stop(
      "Rendered page does not contain `#quarto-document-content`.",
      call. = FALSE
    )
  }

  page_title <- review_page_title(document, title, source)
  content <- xml2::read_html(
    paste0("<!doctype html><html><body>", as.character(main), "</body></html>")
  )
  normalize_review_structure(content)
  clean_review_content(content, include_code = include_code)
  normalize_review_resources(content, dirname(html), site_root)

  title_nodes <- xml2::xml_find_all(
    content,
    "//h1[contains(concat(' ', normalize-space(@class), ' '), ' title ')]"
  )
  xml2::xml_remove(title_nodes)

  escaped_title <- htmltools::htmlEscape(page_title)
  escaped_source <- htmltools::htmlEscape(source)
  escaped_date <- htmltools::htmlEscape(as.character(date))
  live_line <- if (is.null(live_url)) {
    ""
  } else {
    escaped_url <- htmltools::htmlEscape(live_url)
    paste0(
      "<p><strong>Live page:</strong> <a href=\"",
      escaped_url,
      "\">",
      escaped_url,
      "</a></p>"
    )
  }
  main_content <- xml2::xml_find_first(
    content,
    "//main | //*[@role='main']"
  )
  content_html <- paste(
    vapply(xml2::xml_contents(main_content), as.character, character(1)),
    collapse = ""
  )

  review_document <- xml2::read_html(paste0(
    "<!doctype html><html><head><meta charset=\"utf-8\"></head>",
    "<body><main id=\"quarto-document-content\">",
    "<h1>",
    escaped_title,
    "</h1>",
    "<div><h2>Review instructions</h2>",
    "<p><strong>Source page:</strong> ",
    escaped_source,
    "</p>",
    live_line,
    "<p><strong>Exported:</strong> ",
    escaped_date,
    "</p>",
    "<p>Suggest exact wording changes in Suggesting mode. Use comments for ",
    "anything else, such as a missing section, broken link, image, table, or ",
    "layout request. The website editor will make approved changes in the ",
    "source file.</p></div><hr>",
    content_html,
    "</main></body></html>"
  ))

  list(document = review_document, title = page_title)
}

normalize_review_structure <- function(document) {
  normalize_review_tabsets(document)
  normalize_review_callouts(document)
  normalize_review_role_tables(document)
  invisible(document)
}

normalize_review_tabsets <- function(document) {
  tabsets <- xml2::xml_find_all(
    document,
    "//*[contains(concat(' ', normalize-space(@class), ' '), ' panel-tabset ')]"
  )
  for (tabset in tabsets) {
    labels <- trimws(xml2::xml_text(xml2::xml_find_all(
      tabset,
      ".//*[contains(concat(' ', normalize-space(@class), ' '), ' nav-tabs ')]//a"
    )))
    panes <- xml2::xml_find_all(
      tabset,
      ".//*[contains(concat(' ', normalize-space(@class), ' '), ' tab-content ')]/*[contains(concat(' ', normalize-space(@class), ' '), ' tab-pane ')]"
    )
    count <- min(length(labels), length(panes))
    if (count > 0L) {
      for (index in seq_len(count)) {
        heading <- xml2::read_html(paste0(
          "<h2>",
          htmltools::htmlEscape(labels[[index]]),
          "</h2>"
        ))
        heading <- xml2::xml_find_first(heading, "//h2")
        first <- xml2::xml_find_first(panes[[index]], "./*")
        if (inherits(first, "xml_missing")) {
          xml2::xml_add_child(panes[[index]], heading)
        } else {
          xml2::xml_add_sibling(first, heading, .where = "before")
        }
      }
    }
    xml2::xml_remove(xml2::xml_find_all(
      tabset,
      ".//*[contains(concat(' ', normalize-space(@class), ' '), ' nav-tabs ')]"
    ))
  }
  invisible(document)
}

normalize_review_callouts <- function(document) {
  callouts <- xml2::xml_find_all(
    document,
    "//*[contains(concat(' ', normalize-space(@class), ' '), ' callout ')]"
  )
  for (callout in rev(callouts)) {
    title <- xml2::xml_find_first(
      callout,
      ".//*[contains(concat(' ', normalize-space(@class), ' '), ' callout-title-container ')]"
    )
    body <- xml2::xml_find_first(
      callout,
      ".//*[contains(concat(' ', normalize-space(@class), ' '), ' callout-body ')]"
    )
    if (inherits(body, "xml_missing")) {
      next
    }

    title_text <- if (inherits(title, "xml_missing")) {
      "Note"
    } else {
      visible_text <- xml2::xml_find_all(
        title,
        ".//text()[not(ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' screen-reader-only ')])]"
      )
      trimws(paste(xml2::xml_text(visible_text), collapse = ""))
    }
    body_html <- paste(
      vapply(xml2::xml_contents(body), as.character, character(1)),
      collapse = ""
    )
    replacement <- xml2::read_html(paste0(
      "<blockquote><p><strong>",
      htmltools::htmlEscape(title_text),
      "</strong></p>",
      body_html,
      "</blockquote>"
    ))
    xml2::xml_replace(
      callout,
      xml2::xml_find_first(replacement, "//blockquote")
    )
  }
  invisible(document)
}

normalize_review_role_tables <- function(document) {
  tables <- xml2::xml_find_all(document, "//*[@role='table']")
  for (table in rev(tables)) {
    headers <- trimws(xml2::xml_text(xml2::xml_find_all(
      table,
      ".//*[@role='columnheader']"
    )))
    rows <- xml2::xml_find_all(
      table,
      ".//*[@role='rowgroup'][contains(concat(' ', normalize-space(@class), ' '), ' rt-tbody ')]//*[@role='row']"
    )
    if (!length(headers) || !length(rows)) {
      next
    }

    header_html <- paste0(
      "<th>",
      htmltools::htmlEscape(headers),
      "</th>",
      collapse = ""
    )
    rows_html <- vapply(
      rows,
      function(row) {
        cells <- xml2::xml_find_all(row, "./*[@role='cell']")
        values <- vapply(cells, review_role_cell_text, character(1))
        paste0(
          "<tr>",
          paste0(
            "<td>",
            htmltools::htmlEscape(values),
            "</td>",
            collapse = ""
          ),
          "</tr>"
        )
      },
      character(1)
    )
    replacement <- xml2::read_html(paste0(
      "<table>",
      review_table_colgroup(headers),
      "<thead><tr>",
      header_html,
      "</tr></thead><tbody>",
      paste0(rows_html, collapse = ""),
      "</tbody></table>"
    ))
    xml2::xml_replace(table, xml2::xml_find_first(replacement, "//table"))
  }
  invisible(document)
}

review_table_colgroup <- function(headers) {
  if (identical(headers, c("Year", "Recipient", "Institution"))) {
    return(paste0(
      "<colgroup>",
      "<col style=\"width: 10%;\">",
      "<col style=\"width: 42%;\">",
      "<col style=\"width: 48%;\">",
      "</colgroup>"
    ))
  }
  ""
}

review_role_cell_text <- function(cell) {
  inner <- xml2::xml_find_first(
    cell,
    ".//*[contains(concat(' ', normalize-space(@class), ' '), ' rt-td-inner ')]"
  )
  if (inherits(inner, "xml_missing")) {
    return(trimws(xml2::xml_text(cell)))
  }

  leaves <- xml2::xml_find_all(inner, ".//*[not(*)]")
  values <- trimws(xml2::xml_text(leaves))
  values <- unique(values[nzchar(values)])
  if (!length(values)) {
    return(trimws(xml2::xml_text(inner)))
  }
  paste(values, collapse = " - ")
}

review_page_title <- function(document, title, source) {
  if (!is.null(title)) {
    if (!is.character(title) || length(title) != 1L || !nzchar(title)) {
      stop("`title` must be `NULL` or a non-empty string.", call. = FALSE)
    }
    return(title)
  }

  title_node <- xml2::xml_find_first(
    document,
    "//h1[contains(concat(' ', normalize-space(@class), ' '), ' title ')]"
  )
  if (!inherits(title_node, "xml_missing")) {
    page_title <- trimws(xml2::xml_text(title_node))
    if (nzchar(page_title)) {
      return(page_title)
    }
  }

  tools::toTitleCase(tools::file_path_sans_ext(basename(source)))
}

clean_review_content <- function(document, include_code) {
  remove <- c(
    "//script",
    "//style",
    "//noscript",
    "//nav",
    "//*[contains(concat(' ', normalize-space(@class), ' '), ' anchorjs-link ')]",
    "//*[contains(concat(' ', normalize-space(@class), ' '), ' code-copy-button ')]"
  )
  if (!isTRUE(include_code)) {
    remove <- c(
      remove,
      "//*[contains(concat(' ', normalize-space(@class), ' '), ' cell-code ')]",
      "//pre[contains(concat(' ', normalize-space(@class), ' '), ' sourceCode ')]"
    )
  }
  xml2::xml_remove(xml2::xml_find_all(
    document,
    paste(remove, collapse = " | ")
  ))
  invisible(document)
}

normalize_review_resources <- function(document, html_dir, site_root) {
  nodes <- xml2::xml_find_all(document, "//*[@src]")
  for (node in nodes) {
    src <- xml2::xml_attr(node, "src")
    if (is_remote_reference(src)) {
      next
    }

    path <- sub("[?#].*$", "", utils::URLdecode(src))
    candidate <- if (startsWith(path, "/")) {
      file.path(site_root, substring(path, 2L))
    } else {
      file.path(html_dir, path)
    }
    if (file.exists(candidate)) {
      xml2::xml_set_attr(
        node,
        "src",
        normalizePath(candidate, winslash = "/", mustWork = TRUE)
      )
    }
  }
  invisible(document)
}

run_quarto_pandoc <- function(input, output, resource_paths) {
  quarto <- quarto::quarto_path()
  resource_path <- paste(unique(resource_paths), collapse = .Platform$path.sep)
  result <- suppressWarnings(system2(
    quarto,
    c(
      "pandoc",
      shQuote(input),
      "--from=html",
      "--to=docx",
      "--output",
      shQuote(output),
      paste0("--resource-path=", shQuote(resource_path))
    ),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(result, "status")
  if (!is.null(status) && status != 0L) {
    stop(
      "Quarto could not create the review document:\n",
      paste(result, collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(output)
}

drive_upload_review <- function(file, drive_path, shared_drive, name, convert) {
  drive <- if (is.null(shared_drive)) {
    NULL
  } else {
    googledrive::shared_drive_get(name = shared_drive)
  }
  if (!is.null(drive) && nrow(drive) != 1L) {
    stop(
      "`shared_drive` must identify exactly one Shared Drive.",
      call. = FALSE
    )
  }

  folder <- googledrive::drive_get(path = drive_path, shared_drive = drive)
  if (nrow(folder) != 1L) {
    stop(
      "`drive_path` must identify exactly one existing folder.",
      call. = FALSE
    )
  }

  type <- if (isTRUE(convert)) {
    googledrive::drive_mime_type("document")
  } else {
    NULL
  }
  googledrive::drive_upload(
    media = file,
    path = folder,
    name = name,
    type = type,
    overwrite = FALSE
  )
}

review_live_url <- function(rendered_relative, site_url) {
  if (is.null(site_url)) {
    return(NULL)
  }
  if (!is.character(site_url) || length(site_url) != 1L || !nzchar(site_url)) {
    stop("`site_url` must be `NULL` or a non-empty URL.", call. = FALSE)
  }

  path <- gsub("\\\\", "/", rendered_relative)
  path <- sub("index\\.html$", "", path, ignore.case = TRUE)
  paste0(sub("/+$", "", site_url), "/", path)
}

review_filename <- function(title) {
  filename <- gsub("[/\\\\:*?\"<>|]", "-", title)
  filename <- gsub("[[:space:]]+", " ", trimws(filename))
  if (!nzchar(filename)) {
    return("Website Page")
  }
  filename
}

resolve_from_root <- function(path, root) {
  if (is_absolute_path(path)) {
    path
  } else {
    file.path(root, path)
  }
}

normalize_existing_directory <- function(path, argument) {
  if (!is.character(path) || length(path) != 1L || !dir.exists(path)) {
    stop("`", argument, "` must identify an existing directory.", call. = FALSE)
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

is_absolute_path <- function(path) {
  grepl("^(/|[A-Za-z]:[/\\\\])", path)
}

is_remote_reference <- function(path) {
  is.na(path) ||
    !nzchar(path) ||
    startsWith(path, "#") ||
    startsWith(path, "//") ||
    grepl("^[A-Za-z][A-Za-z0-9+.-]*:", path)
}
