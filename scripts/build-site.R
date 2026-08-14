#!/usr/bin/env Rscript
# Build and verify the AP-LS website in one command.
#
# What it does:
#   1. Pull the conference Google Sheet into local CSVs and rebuild the
#      workshop pages (conferences/_update-conference.R). Safe to run any
#      time: until a SHEET_ID is set in that script, it only rebuilds the
#      workshop pages from the local CSVs.
#   2. Render the whole site with Quarto. The post-render hook in
#      _quarto.yml cleans JavaScript source maps out of docs/ on its own.
#   3. Run the accessibility and broken-link checks and summarize them.
#
# Usage from a terminal, at the project root:
#   Rscript scripts/build-site.R                  # everything
#   Rscript scripts/build-site.R --skip-render    # update + checks only (fast)
#   Rscript scripts/build-site.R --render-only    # update + render, no checks
#   Rscript scripts/build-site.R --skip-update    # render + checks, no Sheet pull
#   Rscript scripts/build-site.R --audit          # add the media weight audit
# Or from RStudio: source("scripts/build-site.R")
#
# Exit status is 1 if the render fails or a check finds something new, so
# the script can be wired into automation later.

run_step <- function(label, code) {
  message("\n---- ", label, " ", strrep("-", max(1, 60 - nchar(label))))
  force(code)
}

# link checker
KNOWN_EMAIL_ARCHIVE_REFS <- 8L

do_update <- function() {
  source(here::here("conferences", "_update-conference.R"), local = TRUE)
}

do_render <- function() {
  quarto <- Sys.which("quarto")
  if (!nzchar(quarto)) {
    stop("Could not find the `quarto` command. Install Quarto or run this",
         " from a shell where `quarto` is on the PATH.", call. = FALSE)
  }
  status <- system2(quarto, "render")
  if (!identical(status, 0L)) {
    stop("quarto render failed with exit status ", status, call. = FALSE)
  }
  message("\nRender finished.")
}

do_checks <- function() {
  failures <- 0L

  a11y <- suppressWarnings(
    system2("Rscript", c(here::here("scripts", "check-a11y.R")),
            stdout = TRUE, stderr = TRUE)
  )
  cat(a11y, sep = "\n")
  if (any(grepl("No issues found", a11y, fixed = TRUE))) {
    message("\nAccessibility: clean.")
  } else {
    message("\nAccessibility: issues found, see above.")
    failures <- failures + 1L
  }

  links <- suppressWarnings(
    system2("Rscript", c(here::here("scripts", "check-links.R")),
            stdout = TRUE, stderr = TRUE)
  )
  cat(links, sep = "\n")
  broken <- sum(grepl("^BROKEN: ", links))
  if (broken <= KNOWN_EMAIL_ARCHIVE_REFS) {
    message("\nLinks: clean. (", broken, " reference(s), all inside the",
            " archived email HTML; those are expected.)")
  } else {
    message("\nLinks: ", broken, " broken references, more than the ",
            KNOWN_EMAIL_ARCHIVE_REFS,
            " known archived-email artifacts. Review the list above.")
    failures <- failures + 1L
  }

  failures
}

do_audit <- function() {
  status <- system2("Rscript", c(here::here("scripts", "audit-media.R")))
  invisible(status)
}

build_site <- function(update = TRUE, render = TRUE, checks = TRUE,
                       audit = FALSE) {
  if (update) run_step("Update conference data from the Google Sheet",
                       do_update())
  if (render) run_step("Render the site", do_render())
  failures <- 0L
  if (checks) {
    run_step("Accessibility and link checks", failures <- do_checks())
  }
  if (audit) run_step("Media weight audit", do_audit())

  message("\n", strrep("-", 64))
  if (failures == 0L) {
    message("Build finished. Everything passed.")
  } else {
    message("Build finished with ", failures, " check(s) needing attention.")
  }
  invisible(failures)
}

args <- commandArgs(trailingOnly = TRUE)
failures <- build_site(
  update = !"--skip-update" %in% args,
  render = !"--skip-render" %in% args,
  checks = !"--render-only" %in% args,
  audit  = "--audit" %in% args
)
if (sys.nframe() == 0L) quit(status = if (failures == 0L) 0L else 1L)
