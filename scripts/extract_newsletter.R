#!/usr/bin/env Rscript
# Extract newsletter HTML from Gmail-saved email files.
#
# Usage: Rscript extract_newsletter.R <input_html> <output_html> [logo_output_path] [page_title]
#
# Exits with code 0 on success, 1 on failure (e.g. inbox save without newsletter).
# If logo_output_path is provided, extracts the first large image
# (height >= 150 or width >= 300) from the newsletter body and saves it.

library(xml2)
library(httr)

# ------------------------------------------------------------------
# Accessibility sanitizer (shared)
#
# Applied to every extracted newsletter before writing, and sourced by
# scripts/sanitize-newsletter-archive.R to fix already-archived files.
# Fixes, per the axe-core full-site audit (WCAG 2.1 A/AA):
#   - images without alt            -> alt="" (archival email images have
#                                      no reliable alt source; empty alt
#                                      stops screen readers announcing URLs)
#   - iframes without title         -> title="Embedded content"
#   - image-only links without name -> aria-label from the href target
#   - links on dark template bands  -> cream text (#FBF9F4); Gmail "HTML
#                                      only" saves drop the external CSS
#                                      that used to keep those links white,
#                                      so they fall back to default blue
#                                      (#0000ee, ~1.3:1 on navy)
# ------------------------------------------------------------------

hex_to_luminance <- function(hex) {
  hex <- gsub("^#", "", trimws(hex))
  if (nchar(hex) == 3) {
    hex <- paste0(strsplit(hex, "")[[1]], strsplit(hex, "")[[1]], collapse = "")
  }
  if (nchar(hex) != 6 || grepl("[^0-9a-fA-F]", hex)) return(NA_real_)
  vals <- strtoi(substring(hex, c(1, 3, 5), c(2, 4, 6)), 16L) / 255
  lin <- ifelse(vals <= 0.03928, vals / 12.92, ((vals + 0.055) / 1.055)^2.4)
  0.2126 * lin[1] + 0.7152 * lin[2] + 0.0722 * lin[3]
}

# Find an element's own background from bgcolor attribute or inline style.
# Handles both hex (#003471) and rgb() functional notation — Gmail saves
# use rgb() in inline styles.
parse_bg_color <- function(bgcolor_attr, style) {
  if (!is.na(bgcolor_attr) &&
      grepl("^#?[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$", trimws(bgcolor_attr))) {
    return(paste0("#", gsub("^#", "", trimws(bgcolor_attr))))
  }
  if (!is.na(style)) {
    m <- regmatches(
      style,
      regexec("background(?:-color)?\\s*:\\s*(#[0-9a-fA-F]{3,6})\\b", style,
              ignore.case = TRUE, perl = TRUE)
    )[[1]]
    if (length(m) >= 2) return(m[2])
    m2 <- regmatches(
      style,
      regexec("background(?:-color)?\\s*:\\s*rgb\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*\\)",
              style, ignore.case = TRUE, perl = TRUE)
    )[[1]]
    if (length(m2) >= 4) {
      return(sprintf("#%02X%02X%02X",
                     as.integer(m2[2]), as.integer(m2[3]), as.integer(m2[4])))
    }
  }
  NA_character_
}

# Element's own foreground color from inline style, if any. The lookbehind
# is essential: a plain "color\\s*:" match would also hit "background-color".
parse_fg_color <- function(style) {
  if (is.na(style)) return(NA_character_)
  m <- regmatches(
    style,
    regexec("(?<![-a-z])color\\s*:\\s*(#[0-9a-fA-F]{3,6})\\b", style,
            ignore.case = TRUE, perl = TRUE)
  )[[1]]
  if (length(m) >= 2) return(m[2])
  m2 <- regmatches(
    style,
    regexec("(?<![-a-z])color\\s*:\\s*rgb\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*\\)",
            style, ignore.case = TRUE, perl = TRUE)
  )[[1]]
  if (length(m2) >= 4) {
    return(sprintf("#%02X%02X%02X",
                   as.integer(m2[2]), as.integer(m2[3]), as.integer(m2[4])))
  }
  NA_character_
}

# Replace (or append) the foreground color declaration in an inline style.
set_fg_color <- function(style, color) {
  style <- style %||% ""
  if (grepl("(?<![-a-z])color\\s*:", style, perl = TRUE)) {
    sub("(?<![-a-z])color\\s*:[^;]+", paste0("color:", color), style,
        perl = TRUE)
  } else {
    paste0("color:", color, ";", style)
  }
}

contrast_ratio <- function(lum1, lum2) {
  hi <- max(lum1, lum2); lo <- min(lum1, lum2)
  (hi + 0.05) / (lo + 0.05)
}

# Text that is only whitespace and/or non-breaking spaces is still empty for
# accessibility-name purposes (xml_text does not strip &nbsp;).
is_empty_text <- function(x) {
  trimws(gsub("\u00A0", " ", x)) == ""
}

sanitize_newsletter_doc <- function(doc) {
  # Images without alt text
  for (img in xml_find_all(doc, "//img[not(@alt)]")) {
    xml_attr(img, "alt") <- ""
  }

  # Embedded iframes without a title
  for (fr in xml_find_all(doc, "//iframe[not(@title)]")) {
    xml_attr(fr, "title") <- "Embedded content"
  }

  # aria-label on tables and their parts (MemberClicks templates label
  # layout tables "divider", "header", and so on). ARIA prohibits naming
  # these elements, and the labels are layout junk, so remove them.
  for (el in xml_find_all(doc, "//table[@aria-label] | //tbody[@aria-label] | //tr[@aria-label] | //td[@aria-label]")) {
    xml_attr(el, "aria-label") <- NULL
  }

  # Dead empty anchors (<a href=""> with no text and no image) are Gmail
  # save artifacts — they are focusable, nameless, and render nothing.
  # Remove them (axe link-name). Named anchor targets have no href and
  # are not matched here.
  for (a in xml_find_all(doc, "//a[@href and normalize-space(@href) = '']")) {
    if (is_empty_text(xml_text(a)) &&
        length(xml_find_all(a, ".//img")) == 0) {
      xml_remove(a)
    }
  }

  for (a in xml_find_all(doc, "//a[@href]")) {
    href <- xml_attr(a, "href")
    style <- xml_attr(a, "style") %||% ""
    # Links with no accessible name (no text — not even &nbsp; — and no
    # aria-label) get one from their target. This covers image-only links
    # and Spark/MemberClicks redirects whose only content is "&nbsp;".
    if (is_empty_text(xml_text(a)) &&
        is.na(xml_attr(a, "aria-label"))) {
      lbl <- if (grepl("^mailto:", href)) {
        paste("Email", sub("^mailto:", "", href))
      } else if (grepl("^https?://", href)) {
        paste("Open link to", sub("^https?://([^/]+).*$", "\\1", href))
      } else {
        "Link"
      }
      xml_attr(a, "aria-label") <- lbl
    }

    # Links with no author-specified color sitting on a dark band get
    # cream text. Threshold 0.25 luminance ~= anything darker than #888.
    if (grepl("(?<![-a-z])color\\s*:", style, perl = TRUE)) next
    for (p in xml_parents(a)) {
      bg <- parse_bg_color(xml_attr(p, "bgcolor"), xml_attr(p, "style"))
      if (!is.na(bg)) {
        lum <- hex_to_luminance(bg)
        if (!is.na(lum) && lum < 0.25) {
          xml_attr(a, "style") <- paste0("color:#FBF9F4;", style)
        }
        break
      }
    }
  }

  # General text contrast: email templates hard-code colors that fail WCAG
  # once the external CSS is gone. Two repairs:
  #   - dark/default text on a dark band  -> cream (#FBF9F4)
  #   - low-contrast inline color on a light band -> brand navy (#1F4E96)
  # Only elements with direct text are touched, and only when the failing
  # color is the element's own (inherited colors belong to the ancestor
  # and are handled there).
  text_xpath <- paste0(
    "//p | //td | //span | //font | //li | //div | //strong | //em |",
    " //h1 | //h2 | //h3 | //h4 | //h5 | //h6"
  )
  for (el in xml_find_all(doc, text_xpath)) {
    direct <- paste(vapply(xml_contents(el), function(n) {
      if (xml_type(n) == "text") xml_text(n) else ""
    }, character(1)), collapse = "")
    if (!nzchar(trimws(gsub("\u00A0", " ", direct)))) next

    bg <- NA_character_
    for (p in c(list(el), xml_parents(el))) {
      bg <- parse_bg_color(xml_attr(p, "bgcolor"), xml_attr(p, "style"))
      if (!is.na(bg)) break
    }
    if (is.na(bg)) next
    lbg <- hex_to_luminance(bg)
    if (is.na(lbg)) next

    style <- xml_attr(el, "style")
    fg <- parse_fg_color(style)
    lfg <- if (!is.na(fg)) hex_to_luminance(fg) else 0  # default text = black

    if (!is.na(lfg) && contrast_ratio(lfg, lbg) >= 4.5) next

    if (lbg < 0.25) {
      xml_attr(el, "style") <- set_fg_color(style, "#FBF9F4")
    } else if (lbg > 0.7 && !is.na(fg)) {
      xml_attr(el, "style") <- set_fg_color(style, "#1F4E96")
    }
  }

  invisible(doc)
}

extract_newsletter <- function(input_path, output_path, logo_path = NULL,
                               title = NULL) {
  html <- readLines(input_path, encoding = "UTF-8", warn = FALSE)
  html_text <- paste(html, collapse = "\n")
  file_size <- nchar(html_text)

  doc <- read_html(html_text)

  bodycontainer <- xml_find_first(doc, "//div[@class='bodycontainer']")
  message_table <- xml_find_first(doc, "//table[@class='message']")

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

    footer_keywords <- c(
    "This email was sent to",
    "Remove My Email",
    "Manage Preferences",
    "Privacy Policy",
    "Powered by MemberClicks",
    "6510 Telecom Dr",
    "704-456-7276",
    "office@ap-ls.org"
  )

  email_body_lower <- tolower(email_body)
  for (kw in footer_keywords) {
    kw_lower <- tolower(kw)
    pos <- regexpr(kw_lower, email_body_lower, fixed = TRUE)
    if (pos[1] > 0) {
      # Find the start of the HTML tag containing this text
      tag_start <- max(
        gregexpr("<", substr(email_body, 1, pos[1] - 1))[[1]],
        na.rm = TRUE
      )
      if (is.finite(tag_start) && tag_start > 0) {
        email_body <- substr(email_body, 1, tag_start - 1)
      } else {
        email_body <- substr(email_body, 1, pos[1] - 1)
      }
      break
    }
  }

  # Parse and clean
  body_doc <- read_html(email_body)

  # Remove Gmail tracking attributes to hide mah identity
  for (el in xml_find_all(body_doc, "//*[@data-saferedirecturl]")) {
    xml_attr(el, "data-saferedirecturl") <- NULL
  }

  # Remove elements containing recipient-specific info -- eventually fix this if the people will give me freaking access again but I digress
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

  # Also remove any 1x1 tracking pixels that remain
  tracking_imgs <- xml_find_all(body_doc, "//img[@width='1' and @height='1']")
  for (el in tracking_imgs) {
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

  # Accessibility fixes (alt text, iframe titles, link names, dark-band
  # link colors) before serializing.
  sanitize_newsletter_doc(body_doc)

  # Wrap the email body in a complete document: the raw serialization is a
  # bare <html><body> fragment with no lang, no head, and no title (axe
  # html-has-lang / document-title).
  body_el <- xml_find_first(body_doc, "//body")
  inner <- paste(
    vapply(xml_children(body_el), as.character, character(1)),
    collapse = "\n"
  )
  page_title <- if (!is.null(title)) title else "AP-LS Newsletter"
  cleaned <- sprintf(
    paste0(
      "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n",
      "<meta charset=\"utf-8\">\n",
      "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
      "<title>%s</title>\n</head>\n<body>\n%s\n</body>\n</html>"
    ),
    page_title, inner
  )

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

# Only run the CLI when executed directly (Rscript), not when source()d by
# sanitize-newsletter-archive.R.
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2 || length(args) > 4) {
    cat("Usage: extract_newsletter.R <input_html> <output_html> [logo_output_path] [page_title]\n")
    quit(status = 1)
  }

  logo_path <- if (length(args) >= 3) args[3] else NULL
  page_title <- if (length(args) == 4) args[4] else NULL
  success <- extract_newsletter(args[1], args[2], logo_path, page_title)
  quit(status = if (success) 0 else 1)
}
