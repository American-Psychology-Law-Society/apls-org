# Creating the AP-LS Conference Google Sheet

The four CSVs in this folder are the tabs of the conference Google Sheet,
seeded with the current 2027 values. Creating the Sheet takes about five
minutes.

## Steps

1. In Google Drive, create a new blank Google Sheet and name it
   **AP-LS Conference**.
2. For each CSV in this folder: in the Sheet, choose
   **File > Import > Upload**, pick the CSV, set the import location to
   **Insert new sheet**, and leave the separator detection on automatic.
   Each import adds a tab named after the file. When all four are in,
   delete the empty default tab ("Sheet1").
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
