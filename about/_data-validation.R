# Shared validation and transactional file helpers for maintainer-run imports.

is_blank_value <- function(x) {
  is.na(x) | trimws(as.character(x)) == ""
}

validation_error <- function(label, message) {
  stop(sprintf("%s: %s", label, message), call. = FALSE)
}

assert_required_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    validation_error(
      label,
      sprintf("missing required column(s): %s", paste(missing, collapse = ", "))
    )
  }
  invisible(data)
}

assert_non_empty <- function(data, label) {
  if (!is.data.frame(data) || nrow(data) == 0) {
    validation_error(label, "contains no data rows")
  }
  invisible(data)
}

assert_required_values <- function(data, columns, label) {
  assert_required_columns(data, columns, label)
  for (column in columns) {
    bad <- which(is_blank_value(data[[column]]))
    if (length(bad) > 0) {
      validation_error(
        label,
        sprintf(
          "column '%s' is blank in row(s): %s",
          column,
          paste(bad, collapse = ", ")
        )
      )
    }
  }
  invisible(data)
}

assert_unique_rows <- function(data, columns, label) {
  assert_required_columns(data, columns, label)
  keys <- as.data.frame(
    lapply(data[columns], function(x) trimws(as.character(x))),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  duplicates <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
  if (any(duplicates)) {
    validation_error(
      label,
      sprintf(
        "duplicate values for %s in row(s): %s",
        paste(columns, collapse = " + "),
        paste(which(duplicates), collapse = ", ")
      )
    )
  }
  invisible(data)
}

assert_valid_emails <- function(data, column, label, allow_blank = FALSE) {
  assert_required_columns(data, column, label)
  values <- trimws(as.character(data[[column]]))
  blank <- is_blank_value(values)
  valid <- grepl(
    "^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+$",
    values
  )
  bad <- which((!allow_blank & blank) | (!blank & !valid))
  if (length(bad) > 0) {
    validation_error(
      label,
      sprintf("invalid email address in row(s): %s", paste(bad, collapse = ", "))
    )
  }
  invisible(data)
}

optional_mailto <- function(email) {
  values <- trimws(as.character(email))
  ifelse(is_blank_value(values), NA_character_, paste0("mailto:", values))
}

validate_leadership_inputs <- function(ec_data, conf_data) {
  assert_required_columns(ec_data, c("Name", "Position", "Email"), "EC")
  assert_non_empty(ec_data, "EC")
  assert_required_values(ec_data, c("Name", "Position"), "EC")
  assert_valid_emails(ec_data, "Email", "EC", allow_blank = TRUE)
  assert_unique_rows(ec_data, c("Name", "Position"), "EC")

  assert_required_columns(conf_data, c("Name", "Term", "Position"), "Conf_Chairs")
  assert_non_empty(conf_data, "Conf_Chairs")
  assert_required_values(conf_data, c("Name", "Term", "Position"), "Conf_Chairs")
  assert_unique_rows(conf_data, c("Name", "Term", "Position"), "Conf_Chairs")

  invisible(TRUE)
}

validate_committee_inputs <- function(descriptions, members, committee_tabs = NULL) {
  description_columns <- c(
    "key", "name", "description", "responsibilities", "values",
    "meetings", "membership", "reporting", "other", "chair", "email"
  )
  member_columns <- c("key", "Position", "Name", "Email", "Term", "Additional")

  assert_required_columns(descriptions, description_columns, "Committee descriptions")
  assert_non_empty(descriptions, "Committee descriptions")
  assert_required_values(descriptions, c("key", "name"), "Committee descriptions")
  assert_unique_rows(descriptions, "key", "Committee descriptions")
  assert_unique_rows(descriptions, "name", "Committee descriptions")
  assert_valid_emails(descriptions, "email", "Committee descriptions", allow_blank = TRUE)

  assert_required_columns(members, member_columns, "Committee membership")
  assert_non_empty(members, "Committee membership")
  assert_required_values(members, "key", "Committee membership")
  assert_valid_emails(members, "Email", "Committee membership", allow_blank = TRUE)
  assert_unique_rows(
    members,
    c("key", "Position", "Name", "Email", "Term", "Additional"),
    "Committee membership"
  )

  blank_member <- is_blank_value(members$Position) &
    is_blank_value(members$Name) &
    is_blank_value(members$Email) &
    is_blank_value(members$Term) &
    is_blank_value(members$Additional)
  if (any(blank_member)) {
    validation_error(
      "Committee membership",
      sprintf("contains an empty row at row(s): %s", paste(which(blank_member), collapse = ", "))
    )
  }

  unknown_keys <- setdiff(unique(members$key), descriptions$key)
  if (length(unknown_keys) > 0) {
    validation_error(
      "Committee membership",
      sprintf("unknown committee key(s): %s", paste(unknown_keys, collapse = ", "))
    )
  }

  if (!is.null(committee_tabs)) {
    committee_tabs <- trimws(as.character(committee_tabs))
    if (any(is_blank_value(committee_tabs)) || anyDuplicated(committee_tabs)) {
      validation_error("Leadership workbook", "committee tab names must be non-blank and unique")
    }
    missing_tabs <- setdiff(descriptions$key, committee_tabs)
    extra_tabs <- setdiff(committee_tabs, descriptions$key)
    if (length(missing_tabs) > 0 || length(extra_tabs) > 0) {
      pieces <- c(
        if (length(missing_tabs)) sprintf("missing tabs: %s", paste(missing_tabs, collapse = ", ")),
        if (length(extra_tabs)) sprintf("unrecognized tabs: %s", paste(extra_tabs, collapse = ", "))
      )
      validation_error("Leadership workbook", paste(pieces, collapse = "; "))
    }
  }

  invisible(TRUE)
}

atomic_replace_files <- function(staged_paths, target_paths) {
  if (length(staged_paths) == 0 || length(staged_paths) != length(target_paths)) {
    stop("Staged and target paths must be non-empty and have the same length.", call. = FALSE)
  }
  if (anyDuplicated(target_paths)) {
    stop("Target paths must be unique.", call. = FALSE)
  }
  missing <- staged_paths[!file.exists(staged_paths)]
  if (length(missing) > 0) {
    stop(sprintf("Staged file does not exist: %s", missing[1]), call. = FALSE)
  }

  target_dirs <- dirname(target_paths)
  if (any(!dir.exists(target_dirs))) {
    stop("Every target directory must exist before replacement.", call. = FALSE)
  }

  had_target <- file.exists(target_paths)
  backups <- vapply(
    seq_along(target_paths),
    function(i) {
      tempfile(
        pattern = paste0(".", basename(target_paths[i]), "-backup-"),
        tmpdir = target_dirs[i]
      )
    },
    character(1)
  )
  on.exit(unlink(backups[file.exists(backups)]), add = TRUE)

  for (i in which(had_target)) {
    if (!file.copy(target_paths[i], backups[i], overwrite = FALSE, copy.mode = TRUE)) {
      stop(sprintf("Could not back up %s; no files were replaced.", target_paths[i]), call. = FALSE)
    }
  }

  installed <- rep(FALSE, length(target_paths))
  tryCatch(
    {
      for (i in seq_along(target_paths)) {
        if (!file.rename(staged_paths[i], target_paths[i])) {
          stop(sprintf("Could not replace %s", target_paths[i]), call. = FALSE)
        }
        installed[i] <- TRUE
      }
    },
    error = function(error) {
      for (i in seq_along(target_paths)) {
        if (had_target[i] && file.exists(backups[i])) {
          file.copy(backups[i], target_paths[i], overwrite = TRUE, copy.mode = TRUE)
        } else if (!had_target[i] && installed[i] && file.exists(target_paths[i])) {
          unlink(target_paths[i])
        }
      }
      stop(
        sprintf("File replacement failed and prior files were restored: %s", conditionMessage(error)),
        call. = FALSE
      )
    }
  )

  invisible(target_paths)
}
