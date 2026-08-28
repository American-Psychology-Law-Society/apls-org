# Content Sheet Access Form implementation

## Outcome

Create a separate Google Forms workflow that grants authorized AP-LS staff,
Executive Committee members, and committee chairs Editor access to approved
website-content spreadsheets. The workflow must use verified respondent email,
preserve raw responses, track and archive access requests, support safe retries
and offboarding, and notify the website administrator of manual local update and
validation steps. It must never publish website changes automatically.

Initial scope is limited to the leadership/committee workbooks and award-winner
workbook. The leadership route may optionally accept a headshot image, copy it
to an approved Google Drive folder, and report its stored link without adding it
to the website automatically.

## Work items

- [x] Harden `about/_update-ec.R` with schema validation, duplicate checks,
      non-empty safeguards, and atomic YAML replacement.
- [x] Replace render-time Google Sheet reads in `about/committees.qmd` with
      committed local data and add a maintainer-run import script for committee
      descriptions and membership.
- [x] Add backed-up Apps Script source and manifest under
      `automation/content-sheet-access-form/` with verified-email authorization,
      hard-coded spreadsheet/tab allowlists, protected authorization roster,
      Editor permission deduplication, optional headshot copying, notifications,
      logs, Active/Archived request tracking, retry, repair, and offboarding.
- [x] Add setup, Form-question, validation, maintenance, recovery, and test
      documentation, including explicit manual publishing steps.
- [x] Add and run proportionate static/local tests for R import behavior and
      Apps Script safety invariants without calling Google services.
- [x] Review all changes for scope, preserve unrelated work, and record any
      Google-side setup that remains manual.
