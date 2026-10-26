# Conference Sheet seed

Use `apls-conference-seed.xlsx` to create the yearly Google Sheet. The CSVs are plain-text copies of the seed content.

1. Create a blank Google Sheet named **AP-LS Conference**.
2. Import the workbook with **File → Import → Upload → Replace spreadsheet**; remove the default `Sheet1` tab if present.
3. Preserve the exact tabs: `info`, `registration-rates`, `workshop-rates`, `workshops`.
4. Set general link access to Viewer and give co-chairs edit access directly.
5. Copy the ID from the Sheet URL into `SHEET_ID` in `conferences/_update-conference.R`.
6. From the project root, run `source("conferences/_update-conference.R")`. Compare `conferences/data/` with the seeds; resolve unexpected changes before continuing.

Co-chairs update the Sheet; the maintainer reruns the script and renders the site. Add one row per workshop to `workshops` as details are confirmed. Keep the seed workbook for future annual setup.
