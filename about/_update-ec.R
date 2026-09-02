# Run from the project root with a Google account that can read the workbook:
#   source("about/_update-ec.R")

library(googlesheets4)
library(dplyr)
library(yaml)
library(here)
library(stringr)

source(here("about", "_data-validation.R"))

update_leadership_data <- function() {
  SHEET_ID <- "16RGHgDI7snPwaHfvF1gxTLAMet1V5_kM_4iHog2h7m8"

  ec_data <- read_sheet(SHEET_ID, sheet = "EC", col_types = "c")
  conf_data <- read_sheet(SHEET_ID, sheet = "Conf_Chairs", col_types = "c")

  assert_required_columns(ec_data, c("Name", "Position", "Email"), "EC")
  assert_required_columns(conf_data, c("Name", "Term", "Position"), "Conf_Chairs")

  ec_data <- ec_data |>
    mutate(across(all_of(c("Name", "Position", "Email")), ~ trimws(as.character(.x))))
  conf_data <- conf_data |>
    mutate(across(all_of(c("Name", "Term", "Position")), ~ trimws(as.character(.x))))

  # Validate both source tabs before constructing or replacing either output.
  validate_leadership_inputs(ec_data, conf_data)

  ec_list <- ec_data |>
    mutate(
      url = optional_mailto(Email),
      first = tolower(str_extract(Name, "^\\S+")),
      last = tolower(str_replace(str_extract(Name, "(?<=\\s).*$"), " ", "-")),
      base_path = paste0("presidents/imgs/", first, "_", last),
      image = case_when(
        Position %in% c("President", "Past President", "President Elect") &
          file.exists(here("about", paste0(base_path, ".png"))) ~ paste0(base_path, ".png"),
        Position %in% c("President", "Past President", "President Elect") &
          file.exists(here("about", paste0(base_path, ".jpg"))) ~ paste0(base_path, ".jpg"),
        Position %in% c("President", "Past President", "President Elect") &
          file.exists(here("about", paste0(base_path, ".jpeg"))) ~ paste0(base_path, ".jpeg"),
        .default = NA_character_
      )
    ) |>
    rename(text = Position, name = Name) |>
    select(name, text, url, image)

  # Convert to list, dropping optional fields that have no value.
  ec_list <- lapply(seq_len(nrow(ec_list)), function(i) {
    row <- as.list(ec_list[i, ])
    if (is.na(row$url)) row$url <- NULL
    if (is.na(row$image)) row$image <- NULL
    row
  })

  conf_list <- conf_data |>
    mutate(
      text = paste0(Term, " Conference ", Position)
    ) |>
    rename(name = Name) |>
    select(name, text)

  conf_list <- lapply(seq_len(nrow(conf_list)), function(i) {
    as.list(conf_list[i, ])
  })

  targets <- c(
    here("about", "executive-committee.yml"),
    here("about", "conf-chairs.yml")
  )
  staged <- vapply(
    targets,
    function(target) {
      tempfile(
        pattern = paste0(".", basename(target), "-"),
        tmpdir = dirname(target),
        fileext = ".tmp"
      )
    },
    character(1)
  )
  on.exit(unlink(staged[file.exists(staged)]), add = TRUE)

  write_yaml(ec_list, staged[1])
  write_yaml(conf_list, staged[2])

  # Parse both staged files before replacing either committed file.
  parsed <- lapply(staged, read_yaml)
  if (!identical(parsed[[1]], ec_list) || !identical(parsed[[2]], conf_list)) {
    stop("Staged leadership YAML did not round-trip successfully; existing files were preserved.", call. = FALSE)
  }

  atomic_replace_files(staged, targets)
  message("Updated: ", paste(targets, collapse = ", "))
  invisible(targets)
}

update_leadership_data()
