# Creating the AP-LS Conference Google Sheet

This folder holds the seed content for the conference Google Sheet,
seeded with the current 2027 values. Use the workbook
`apls-conference-seed.xlsx` (all four tabs in one file); the four CSVs
are the same content in plain-text form, kept for reference.

## Steps

1. In Google Drive, create a new blank Google Sheet and name it
   **AP-LS Conference**.
2. In the Sheet, choose **File > Import > Upload**, pick
   `apls-conference-seed.xlsx`, and set the import location to
   **Replace spreadsheet**. That one upload creates all four tabs.
   Delete the empty default tab ("Sheet1") if it survives the import.
3. Check that the four tabs are named exactly: `info`,
   `registration-rates`, `workshop-rates`, `workshops`. The update script
   looks for those names.
4. Share the Sheet: **Share > General access > Anyone with the link**,
   role **Viewer**. The script reads without a login, so the link must be
   view-only public. Give co-chairs edit access by email as usual.
5. Copy the Sheet's ID from its URL (the long string between `/d/` and
   `/edit`) and paste it into `SHEET_ID` at the top of
   `conferences/_update-conference.R`.
6. From the project root, run `source("conferences/_update-conference.R")`.
   It should report all four CSVs written, and
   `git diff conferences/data/` should show **no changes**, because the
   seeds here match the committed data. If you see a diff, something in
   the import changed a value; compare and fix before going on.

## After that

Co-chairs edit the Sheet, someone runs
`source("conferences/_update-conference.R")`, and the conference pages are
rendered from the result. The `workshops` tab starts with header row only;
add one row per workshop as they are confirmed (semicolons separate
multiple presenters, categories, or objectives).

Keep this folder. It is the blank starting point if a fresh Sheet is ever
needed, for example at a yearly rollover.
