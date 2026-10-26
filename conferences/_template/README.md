# Conference page template

Copy this directory's contents into `conferences/` for a new year. Keep `_template/` intact; Quarto excludes it from the published site.

## Annual rollover

1. Move the previous year's live conference files (`index.qmd`, `index.css`, `images/`, `data/`, `cfp/`, and `preconference/`) into `conferences/archive/<year>/`. Fix archived links to point to `../index.qmd` and update the menu label in `_quarto.yml`.
2. Copy the contents of `_template/` into `conferences/`.
3. Replace placeholders listed in the comment at the top of `index.qmd`; check seed CSVs too. Add `images/logo.png` and `images/hotel.png`.
4. Set up the year's conference Sheet using `conferences/sheet-id/README.md`, then put its ID in `conferences/_update-conference.R`.
5. From the project root, run `source("conferences/_update-conference.R")` and review the generated CSVs and workshop pages.
6. Run `quarto preview` from the project root and inspect the conference pages before publishing.

## During the year

Co-chairs edit the conference Sheet; run `source("conferences/_update-conference.R")` after changes. The Sheet tab names and headers are specified in the script comments and must remain unchanged. It writes CSVs under `conferences/data/` and builds workshop pages. The site render reads these local files and does not require Google access.

Update yearly facts in the copied page files and seed data. Stage-specific page instructions are comments in `cfp/index.qmd` and `preconference/index.qmd`.
