# Website content Sheet access automation

Backup for a separate Form and bound Apps Script that grant approved editors access to allowlisted website-content spreadsheets. It does not import data or publish the site. The allowlist is defined by `CONTENT_AREAS` in `Code.gs`; change it only with a deliberate access review.

## Configure and deploy

1. Create a Form in a controlled AP-LS account's My Drive, link a response spreadsheet, and set **Collect email addresses → Verified**. Keep the required question titles, role choices, and content-area labels in sync with `Code.gs`. Forms cannot be stored in a Shared Drive when file upload is used.
2. Set real leadership workbook tab GIDs in `CONTENT_AREAS`; remove all `REPLACE_WITH_*` placeholders. A GID only opens a tab; access is to the whole workbook.
3. In the response spreadsheet's Apps Script project, use this folder's `Code.gs` and `appsscript.json`, enable Drive API v3, and set Script Properties: `FORM_ID`, `ADMIN_EMAIL`, and `HEADSHOT_FOLDER_ID` (approved admin-only folder).
4. Run `setupAutomation()` as the controlled automation account and authorize it. Populate **Authorized Requesters** and run setup again. Keep that roster protected and restricted to administrators.
5. Protect headers, formulas, and unrelated tabs in source workbooks. Stage with copies of the Form, response sheet, workbooks, and folders before production.

## Authorization and routine operation

The protected **Authorized Requesters** sheet is the source of truth. Required headers, in order: `email`, `role`, `content_area_key`, `active`, `service_end_date`. Add one row per email/role/content key; use the exact eligible role and key. Active rows need a future end date. The script fails closed for invalid, duplicate, expired, or unmatched entries. Review access at least quarterly and during committee transitions.

Only the verified Forms respondent email is used. The script grants Editor access to the allowlisted workbook, not just the linked tab. It reuses adequate existing access and logs whether access was preexisting, inherited, upgraded, or created. Group membership may not be visible to Drive, so review group access at its source. Requester emails containing a Sheet link are sent only after access is confirmed.

Use **Active Requests** to track work. Do not rename headers or alter raw Form response or **Automation Log** rows. `setupAutomation()` creates **Automation Log**, **Active Requests**, **Archived Requests**, and the protected roster; it installs triggers and is safe to rerun.

The optional headshot upload is copied only for eligible registry entries, after authorization, when it is JPEG/PNG/WebP and no larger than 10 MB. The original is retained. Review and prepare any accepted image separately; no upload publishes to the site.

## Recovery if things go wrong or you delete stuff?

- `reprocessLatestFormResponse()` processes the newest response or retries its failed operations after the cause is fixed.
- `retryFailedOperations()` retries failed work immediately; hourly retry handles failures automatically, up to five attempts.
- `repairRequestTracker()` rebuilds missing working rows without changing permissions.
- `reviewExpiringAccess()` flags access due within 14 days or overdue; run quarterly.

For offboarding, deactivate every applicable roster row, select the person's **Active Requests** row, set `workflow_status` to `Revocation approved`, then run `revokeSelectedActiveAccess()`. It deletes only a verified direct permission created by this automation when no current roster authorization remains. Handle inherited, group, preexisting, or upgraded access at its source. `Closed (access retained)` archives tracking only; `Restore` reopens tracking and does not change Drive access.

## Publishing changes

An administrator reviews Sheet edits and any headshot, runs the update command listed in the notification from a configured website checkout, inspects generated files, validates and renders the affected pages, then follows the normal Git review and deployment process. Form submissions and Sheet edits never publish automatically.

After setup or ownership changes, verify the Form's verified-email setting, Script Properties, Drive API, triggers, roster protection, registry IDs/GIDs, workbook protections, and automation owner. Keep response data restricted; it contains personal information.
