# Website update Form automation

This folder backs up the bound Apps Script source (`Code.gs` and `appsscript.json`) for the website update Form.

## Setup and required configuration

Keep the Form and its upload folder in a controlled AP-LS account's My Drive, link a response spreadsheet, and retain verified email collection. Form question titles/choices used by the script must match `Code.gs` exactly.

In the response spreadsheet's **Extensions → Apps Script** project, replace `Code.gs` and the manifest with this folder's copies, enable the Advanced Drive service, and set these Script Properties:

- `FORM_ID`
- `ADMIN_EMAIL`
- `REQUEST_FOLDER_ID` (the Shared Drive `Website Reviews/Requests` folder)
- `SITE_INDEX_SPREADSHEET_ID` (from `attr(site_manifest, "index_spreadsheet_id")` after `publish_review_site()`)
- `SHARED_DRIVE_NAME` (`ap-ls.org`)
- `SITE_BASE_URL` (`https://ap-ls.org`)

Run `setupAutomation()` and authorize it. Run `showWebsitePrefillSetting()` and copy its assignment into `APLS_PAGE_URL_ENTRY` in `assets/a11y.html`. Test with a second account before using the production Form. Setup creates **Automation Log**, **Active Requests**, and **Archived Requests**, plus submission, status-edit, and hourly retry triggers. It is safe to rerun.

## Normal operation and recovery

Internal staff and committee routes receive a matched review Doc link; general and public routes receive a normal confirmation. For internal requesters, the script grants the verified respondent Commenter access to the matched Doc. Uploads are copied to the request folder; originals remain in the Form upload area.

Work from **Active Requests**. Set status to `In progress` or `Waiting for information`; use `Completed` to archive. Set an archived row to `Restore` to return it to active work. Do not edit or move raw Form responses or **Automation Log** rows.

- `repairRequestTracker()` rebuilds missing tracker rows and repairs status processing.
- `reprocessLatestFormResponse()` retries processing the newest response after correcting the cause of failure.
- The hourly trigger retries failed notifications (up to five attempts).

Do not send a document link when access failed. Fix the account, Drive sharing, or configuration issue, then use the recovery function. Keep Form response headers and question labels stable because the script reads them by name.
