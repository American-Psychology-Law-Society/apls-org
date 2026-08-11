#!/usr/bin/env Rscript
# Extract newsletter HTML from Gmail-saved email files.
#
# Usage: Rscript extract_newsletter.R <input_html> <output_html> [logo_output_path]
#
# Exits with code 0 on success, 1 on failure (e.g. inbox save without newsletter).
# If logo_output_path is provided, extracts the first large image
# (height >= 150 or width >= 300) from the newsletter body and saves it.

library(xml2)
library(httr)

extract_newsletter <- function(input_path, output_path, logo_path = NULL) {
  html <- readLines(input_path, encoding = "UTF-8", warn = FALSE)
  html_text <- paste(html, collapse = "\n")
  file_size <- nchar(html_text)

  doc <- read_html(html_text)

  bodycontainer <- xml_find_first(doc, "//div[@class='bodycontainer']")
  message_table <- xml_find_first(doc, "//table[@class='message']")

  # Heuristic: if file is >1MB and has no bodycontainer, likely an inbox save
  if (file_size > 1000000 && is.na(bodycontainer) && is.na(message_table)) {
    if (!grepl("AP-LS Monthly Newsletter", html_text, fixed = TRUE) &&
        !grepl("apls@memberclicks", html_text, fixed = TRUE)) {
      message("SKIP: ", input_path, " appears to be a Gmail inbox save without newsletter content.")
      return(FALSE)
    }
  }

  if (is.na(bodycontainer) && is.na(message_table)) {
    message("SKIP: ", input_path, " does not contain a recognizable email body.")
    return(FALSE)
  }

  # Extract the email body
  if (!is.na(bodycontainer)) {
    # Single email save format
    main_div <- xml_find_first(bodycontainer, "./div")
    if (is.na(main_div)) {
      message("SKIP: ", input_path, " has bodycontainer but no content div.")
      return(FALSE)
    }

    content_html <- as.character(main_div)

    # Find the email body start marker
    marker <- '<font size="-1"><u></u>'
    marker_idx <- regexpr(marker, content_html, fixed = TRUE)

    if (marker_idx > 0) {
      email_body <- substr(content_html, marker_idx + nchar(marker), nchar(content_html))
      email_body <- sub("^[\\n\\r\\t ]+", "", email_body)
    } else {
      email_body <- as.character(main_div)
    }
  } else {
    # message table format
    email_body <- as.character(message_table)
  }

  # Parse and clean
  body_doc <- read_html(email_body)

  # Remove Gmail tracking attributes
  for (el in xml_find_all(body_doc, "//*[@data-saferedirecturl]")) {
    xml_attr(el, "data-saferedirecturl") <- NULL
  }

  # Remove elements containing recipient-specific info
  recipient_patterns <- c(
    "em\\.marshall47@gmail\\.com",
    "Emma Marshall",
    "To:.*em\\.marshall47"
  )

  for (pattern in recipient_patterns) {
    nodes <- xml_find_all(body_doc, paste0("//*[contains(text(), '", pattern, "')]"))
    for (el in nodes) {
      parent <- xml_parent(el)
      if (!is.na(parent) && xml_name(parent) %in% c("a", "font", "span", "div")) {
        if (xml_name(parent) == "a" && grepl("^mailto:", xml_attr(parent, "href") %||% "")) {
          xml_remove(parent)
        } else if (trimws(xml_text(parent)) == trimws(xml_text(el))) {
          xml_remove(parent)
        }
      }
    }
  }

  # Remove mailto links to recipient
  mailto_nodes <- xml_find_all(body_doc, "//a[starts-with(@href, 'mailto:') and contains(@href, 'marshall')]")
  for (el in mailto_nodes) {
    xml_remove(el)
  }

  # Remove elements with replyto/recipient classes
  reply_nodes <- xml_find_all(body_doc, "//*[contains(@class, 'replyto') or contains(@class, 'recipient')]")
  for (el in reply_nodes) {
    xml_remove(el)
  }

  # Extract leading photo for thumbnail BEFORE inlining images
  if (!is.null(logo_path)) {
    raw_doc <- read_html(email_body)
    extract_leading_photo(raw_doc, logo_path)
  }

  # Inline images as base64 data URIs so the HTML is self-contained
  img_nodes <- xml_find_all(body_doc, "//img")
  for (img in img_nodes) {
    src <- xml_attr(img, "src") %||% ""
    if (src == "") next

    real_url <- NULL
    if (grepl("#", src) && grepl("googleusercontent.com", src)) {
      real_url <- tail(strsplit(src, "#")[[1]], 1)
    } else if (grepl("^https?://", src)) {
      real_url <- src
    }

    if (is.null(real_url)) next

    tryCatch({
      resp <- GET(real_url, user_agent("Mozilla/5.0"), timeout(30))
      if (status_code(resp) == 200) {
        image_data <- content(resp, "raw")
        mime_type <- guess_type(real_url)
        if (is.na(mime_type)) mime_type <- "image/png"
        b64_data <- base64enc::base64encode(image_data)
        xml_attr(img, "src") <- paste0("data:", mime_type, ";base64,", b64_data)
      }
    }, error = function(e) {
      message("WARNING: Could not download/inline image ", real_url, ": ", conditionMessage(e))
    })
  }

  cleaned <- as.character(body_doc)

  # Check if we still have recipient info
  if (grepl("em.marshall47", cleaned, fixed = TRUE)) {
    message("WARNING: Recipient email may still be present in output.")
  }

  writeLines(cleaned, output_path, useBytes = TRUE)
  return(TRUE)
}

extract_leading_photo <- function(doc, logo_path) {
  img_nodes <- xml_find_all(doc, "//img")
  for (img in img_nodes) {
    src <- xml_attr(img, "src") %||% ""
    if (src == "") next

    height <- parse_dim(xml_attr(img, "height"))
    width <- parse_dim(xml_attr(img, "width"))

    # Also check style for dimensions
    style <- xml_attr(img, "style") %||% ""
    if (is.na(height)) {
      m <- regmatches(style, regexec("height:\\s*(\\d+(?:\\.\\d+)?)px", style, ignore.case = TRUE))[[1]]
      if (length(m) > 1) height <- as.integer(as.numeric(m[2]))
    }
    if (is.na(width)) {
      m <- regmatches(style, regexec("width:\\s*(\\d+(?:\\.\\d+)?)px", style, ignore.case = TRUE))[[1]]
      if (length(m) > 1) width <- as.integer(as.numeric(m[2]))
    }

    # Heuristic: must be reasonably large
    if (!is.na(height) && height < 150 && !is.na(width) && width < 300) next
    if (!is.na(height) && height < 150) next

    # Determine real URL
    real_url <- NULL
    if (grepl("#", src) && grepl("googleusercontent.com", src)) {
      real_url <- tail(strsplit(src, "#")[[1]], 1)
    } else if (grepl("^https?://", src)) {
      real_url <- src
    } else if (grepl("^data:", src)) {
      real_url <- src
    }

    if (is.null(real_url)) next

    tryCatch({
      if (grepl("^data:", real_url)) {
        # Parse data URI
        parts <- strsplit(sub("^data:", "", real_url), ",")[[1]]
        header <- parts[1]
        b64 <- paste(parts[-1], collapse = ",")
        mime_type <- sub(";.*$", "", header)
        image_data <- base64enc::base64decode(b64)
      } else {
        resp <- GET(real_url, user_agent("Mozilla/5.0"), timeout(30))
        image_data <- content(resp, "raw")
        mime_type <- guess_type(real_url)
        if (is.na(mime_type)) mime_type <- "image/png"
      }

      dir.create(dirname(logo_path), showWarnings = FALSE, recursive = TRUE)
      writeBin(image_data, logo_path)
      message("LOGO: Saved leading photo to ", logo_path, " (", mime_type, ")")
      return(TRUE)
    }, error = function(e) {
      message("WARNING: Could not extract leading photo: ", conditionMessage(e))
    })
  }

  message("WARNING: No suitable leading photo found.")
  return(FALSE)
}

parse_dim <- function(value) {
  if (is.na(value) || is.null(value)) return(NA_integer_)
  value <- trimws(as.character(value))
  if (value == "") return(NA_integer_)
  num <- suppressWarnings(as.numeric(value))
  if (is.na(num)) return(NA_integer_)
  as.integer(num)
}

guess_type <- function(url) {
  ext <- tolower(tools::file_ext(url))
  types <- c(
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    svg = "image/svg+xml",
    webp = "image/webp"
  )
  types[ext] %||% NA_character_
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)[1]) y else x

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2 || length(args) > 3) {
  cat("Usage: extract_newsletter.R <input_html> <output_html> [logo_output_path]\n")
  quit(status = 1)
}

logo_path <- if (length(args) == 3) args[3] else NULL
success <- extract_newsletter(args[1], args[2], logo_path)
quit(status = if (success) 0 else 1)
