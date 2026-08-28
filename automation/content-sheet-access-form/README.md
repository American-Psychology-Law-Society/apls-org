# Website content Sheet access automation

This folder is the repository backup for a separate Google Form and bound
Apps Script project that grant approved AP-LS volunteers and staff Editor access
to allowlisted website-content spreadsheets. The workflow is intentionally
nontechnical for requesters. It does **not** run R, rebuild the website, copy
files into the repository, or publish anything.

The initial allowlist includes only:

- the leadership and committee-membership workbook;
- the committee-descriptions workbook; and
- the award-winners workbook.

Conference, presidential archives, Fellows, and telepsychology data must not be
added to this Form without a later review and an explicit registry change.

## Form design

Create a new Form in a controlled AP-LS account. Do not add these questions to
the public website-update Form. In **Settings → Responses**, select **Collect
email addresses → Verified**. The script uses only
`FormResponse.getRespondentEmail()` for sharing and notifications; it has no
typed-email fallback.

Apps Script's built-in Forms service reports only whether email collection is
enabled; it cannot distinguish **Verified** from **Responder input**. Therefore,
`setupAutomation()` can confirm that collection is on, but the owner must
visually confirm **Verified** during setup and every quarterly review. Do not
open the Form for responses until that check is complete.

Use these exact question titles and choices:

1. **Your name** — required short answer.
2. **Your AP-LS role** — required multiple choice:
   - `AP-LS staff`
   - `Executive Committee member`
   - `Committee chair/co-chair`
   - `General AP-LS member`
   - `Member of the public`
   - `Other`
3. **Which website content area do you need to edit?** — required multiple
   choice or dropdown. Use every friendly label in `CONTENT_AREAS` in
   `Code.gs`, with spelling and punctuation unchanged.
4. **Why do you need access?** — required paragraph.
5. **When should this access end?** — required date. This is informative; the
   protected authorization roster remains authoritative.
6. **Do you believe you already have access?** — required multiple choice:
   `Yes`, `No`, `Not sure`.
7. **Acknowledgements** — required checkboxes:
   - `I am signed in with the Google Account that should receive access.`
   - `I understand access applies to the whole spreadsheet file, not only the linked tab.`
   - `I will edit only the content area assigned to me.`
   - `I understand my edits are reviewed before website publication.`
8. **Upload a leadership headshot (optional)** — optional file upload. Permit
   image files only, allow at most one file, and set a 10 MB maximum.

The exact initial content-area choices and roster keys are:

| Form choice | `content_area_key` |
|---|---|
| Executive Committee roster | `leadership_ec` |
| Conference chairs roster | `leadership_conference_chairs` |
| Committee membership roster | `leadership_committee_membership` |
| Committee descriptions | `committee_descriptions` |
| Saleem Shah Award winners | `awards_saleem_shah` |
| Outstanding Teaching and Mentoring Award winners | `awards_teaching` |
| Book Award winners | `awards_book` |
| Undergraduate Paper Award winners | `awards_undergrad_paper` |
| Dissertation Award winners | `awards_dissertation` |
| Distinguished Contribution Award winners | `awards_distinguished` |
| REID Award and Grant recipients | `awards_reid` |

Use section branching from **Your AP-LS role**:

- The three eligible roles continue to the content-area section.
- General members, members of the public, and Other go to a short explanation
  that this Form is only for authorized website-content editors, then submit.
- Within the eligible route, show the headshot upload only for a leadership or
  committee-membership selection if the Form layout permits this cleanly.

Branching improves the experience but is not a security boundary. The script
requires an exact eligible role, exact allowlisted selection, verified email,
and matching active roster row before any Drive permission method is called.

A Form with file upload cannot be placed in a Shared Drive. Keep the Form and
its automatically created upload folder in the controlled account's **My
Drive**. Link the Form to a response spreadsheet before setup. The original
Form upload is always preserved.

Suggested introduction:

> Use this form only if your AP-LS duties require editing website source data
> in Google Sheets. Sign in with the Google Account that should receive access.
> AP-LS uses the verified address collected by Google Forms; an alternate typed
> address cannot receive access. Google grants access to the whole spreadsheet,
> not one tab. Editing the Sheet does not publish the website. A website
> administrator must import, review, validate, and publish changes separately.

## Before setup: verify leadership tab links

Google Sheets permissions apply to the entire file. A tab GID is only the
number after `#gid=` in a Sheet URL; it makes the emailed link open on the
relevant tab. It does not restrict access to that tab.

Open the leadership workbook as its owner, select each tab, and replace these
fail-closed values in `CONTENT_AREAS`:

- `REPLACE_WITH_EC_GID`
- `REPLACE_WITH_CONF_CHAIRS_GID`
- `REPLACE_WITH_APPROVED_COMMITTEE_TAB`
- `REPLACE_WITH_COMMITTEE_TAB_GID`

`setupAutomation()` refuses to run while any enabled entry contains a
placeholder or a nonnumeric GID. If committee chairs need different direct tab
links, replace the generic committee-membership entry with one immutable entry
per approved committee tab and use the corresponding keys in the roster. Do
not ask respondents for a tab name, spreadsheet ID, GID, path, command, or URL.

## One-time setup

1. Create an approved destination folder for copied leadership headshots. Keep
   its sharing limited to the AP-LS administrators who manage website images.
2. Open the new Form's response spreadsheet and choose **Extensions → Apps
   Script**. Replace the starter source and manifest with `Code.gs` and
   `appsscript.json` from this folder.
3. In the Apps Script editor, add **Drive API** under **Services**. The manifest
   records Drive API v3 as an advanced service.
4. In **Project settings → Script Properties**, set:
   - `FORM_ID`: ID from the new Form's edit URL.
   - `ADMIN_EMAIL`: website administrator notification address.
   - `HEADSHOT_FOLDER_ID`: ID of the approved destination folder, not the
     Form's upload folder.
5. Run `setupAutomation()` manually as the controlled automation account and
   approve the requested permissions.
6. Confirm that **Authorized Requesters** is protected so only the automation
   owner/administrator can edit it. The setup function creates a non-warning
   sheet protection, disables domain editing, and removes other explicit
   protection editors. Recheck this manually if ownership changes.
7. Populate and validate the authorization roster, then run
   `setupAutomation()` again.
8. Protect headers, formulas, structural columns, and unrelated tabs in each
   source workbook. Test protections with a nonadministrator account.
9. Use a duplicate Form, response spreadsheet, source workbooks, and headshot
   folder for staging tests before production.

Running setup repeatedly is safe. It validates configuration and exact sheet
headers, recreates only missing triggers, repairs tracker rows, and does not
alter raw Form responses or create Drive permissions.

## Authorization roster

`setupAutomation()` creates the protected **Authorized Requesters** tab with
these exact headers, in this order:

| Header | Required value |
|---|---|
| `email` | Lowercase Google Account address that Forms will verify. |
| `role` | One exact eligible role choice. |
| `content_area_key` | One exact key from `CONTENT_AREAS`, not its label. |
| `active` | Checked/`TRUE` only while the authorization is active. |
| `service_end_date` | Required future date for active rows. |

Use one row per email, role, and content-area key. A person authorized for
several areas needs several rows. Duplicate scope rows, expired active rows,
invalid emails, unknown keys, and ineligible roles make setup fail and make a
submission fail closed. Changing the Form's role or content label cannot grant
access without a current matching roster row.

The response workbook contains personal email addresses and service dates.
Limit its Drive access, do not publish it, and apply the organization's records
retention policy.

## Permission behavior

For an authorized request, the script lists existing permissions with Advanced
Drive v3 and `supportsAllDrives: true`:

- direct Editor or higher: record **ALREADY ADEQUATE**, create nothing;
- inherited individual Editor or higher: record **INHERITED**, create nothing;
- direct Viewer/Commenter: upgrade that direct permission to Editor and record
  **PREEXISTING_DIRECT_UPGRADED**;
- no adequate direct access: create one direct `writer` permission and record
  **AUTOMATION_CREATED_DIRECT**.

An inherited permission for the same individual can be recognized when Drive
returns that user's email on the permission. The Drive permissions list does
not expand Google Group membership, so the automation cannot reliably detect
that a person already has access through a group; it may create a redundant
direct permission. Administrators should manage group-based access at the
group source.

Editor is the least privilege that permits Sheet editing; Commenter is not
enough. The script serializes permission operations with a script lock. It
deduplicates trigger replays by Form response ID and active grants by normalized
verified email plus spreadsheet ID. A later request for another tab in the same
workbook reuses the active grant and creates neither a second permission nor a
second Active Requests row, but its raw response and Automation Log row remain.

Google grants access to the spreadsheet file, not a tab. Protected sheets and
ranges reduce accidental editing but do not make other tabs confidential.
Separate confidential content into a different file.

Personal Google accounts work when explicitly rostered and when the source
file's Shared Drive/Workspace policy permits external sharing. If policy blocks
the grant, the script records **FAILED**, withholds the Sheet link from the
requester, and tells the administrator. It never changes Shared Drive policy.

## Headshots

Headshots are processed only after authorization and only for entries whose
`headshotEligible` registry value is `true`. Runtime checks are independent of
the Form settings:

- zero or one upload only;
- Drive metadata MIME type must be JPEG, PNG, or WebP;
- metadata size must be present and no more than 10 MB;
- the copy receives a generated name such as
  `ACCESS-20260827-001__original-name.jpg` after unsafe filename characters are
  removed;
- the original Form upload is never moved or deleted.

The destination file ID, URL, status, attempts, and error are logged. Before a
retry copies anything, the script checks the recorded file ID and searches the
destination folder for the deterministic name, preventing duplicate copies. A
rejected or failed upload never enters the repository and never publishes to
the website. The administrator must review the stored image, prepare the final
web asset separately, and follow the normal repository workflow.

An upload on an award or committee-description request is not copied. A
headshot failure does not undo otherwise valid Sheet access; it is explicit in
the administrator notification and in the requester message.

## Tracking, retries, and recovery

The raw Form response tab is never changed by the automation.
`setupAutomation()` adds:

- **Automation Log** — immutable request identity plus separate access,
  headshot, administrator-email, and requester-email statuses, attempt counts,
  provenance, IDs, URLs, errors, and timestamps;
- **Active Requests** — one working row per verified email and spreadsheet;
- **Archived Requests** — denied, revoked, and administratively closed rows;
- **Authorized Requesters** — protected authorization source of truth.

Do not rename headers or manually move/delete Automation Log or raw-response
rows. Each request receives a stable ID such as `ACCESS-20260827-001`.

The hourly trigger retries only failed operations, up to five attempts. It
re-reads the original Form response and current roster and resolves the current
hard-coded registry before another Drive operation. It does not recreate an
already successful permission or headshot copy. Administrator and requester
emails have independent statuses and attempts. A requester email containing a
Sheet link is not sent until access is **GRANTED**, **UPGRADED TO EDITOR**, or
**ALREADY ADEQUATE**.

If a failed headshot copy later succeeds, the automation sends the
administrator a refreshed notification containing the stored file link. It
does not recreate the Sheet permission.

Recovery functions:

- `reprocessLatestFormResponse()` — process the newest raw response if its
  trigger failed, or give its failed operations one fresh bounded attempt after
  configuration/policy is corrected. Response and grant deduplication remain
  active.
- `retryFailedOperations()` — run the same bounded retry immediately instead
  of waiting for the hourly trigger.
- `repairRequestTracker()` — recreate missing working rows from Automation Log
  without changing permissions or raw responses.
- `reviewExpiringAccess()` — mark active grants due within 14 days or overdue.
- `revokeSelectedActiveAccess()` — safe administrator-invoked revocation; see
  below.

If Apps Script reports a repeated failure, correct the underlying Form,
roster, Drive policy, folder, or email issue first. Never fix a request by
typing a different spreadsheet ID or email into Automation Log.

## Access review, offboarding, and archiving

Run `reviewExpiringAccess()` at least quarterly and near committee transitions.
It marks rows whose roster service end is within 14 days as **Review due** and
marks expired rows **OVERDUE**. It does not silently delete access.

For a direct permission created by this automation:

1. Confirm that no continuing AP-LS duty requires the same workbook.
2. Uncheck `active` for every applicable email/workbook scope in **Authorized
   Requesters**. A still-current roster entitlement makes revocation fail
   closed.
3. Select the person's row in **Active Requests**.
4. Set `workflow_status` to `Revocation approved`.
5. Run `revokeSelectedActiveAccess()` manually.

The function verifies the recorded provenance, exact live permission ID,
verified email, direct/noninherited status, absence of another Active Requests
row, and absence of any current authorization-roster entitlement for that
email/workbook before deletion. It then records **REVOKED** and archives the
working row. It refuses to delete preexisting, upgraded, group, domain,
inherited, Shared Drive membership, or otherwise mismatched access. Handle
those at their source and document the administrator action.

To close tracking while intentionally retaining access, choose
`Closed (access retained)`. The edit trigger archives that working row without
changing Drive. To reopen a working row, set its archived status to `Restore`;
restoration does not grant or recreate a permission.

The raw Form response and Automation Log are never archived or deleted.

## Administrator notification and manual publishing

For an allowlisted area, the administrator email is assembled from immutable
registry values and includes:

- approved Sheet/tab and access status;
- hard-coded local R update command;
- generated files to inspect;
- hard-coded validation commands;
- pages to render;
- headshot status and stored destination link when available; and
- a warning that editing the Sheet does not publish the site.

Free-text name, purpose, acknowledgements, or dates are displayed as data only.
They never enter an R command, shell command, file path, Sheet ID, GID, or URL.

The maintainer workflow is always manual:

1. Review the Sheet changes and headshot, if any.
2. From a locally configured website checkout, run the exact command in the
   administrator email, such as `source("about/_update-ec.R")` or
   `source("awards/_update-awards.R")`.
3. Inspect every listed generated file and run the listed validation steps.
4. Render every listed page and inspect it visually.
5. Review the complete Git diff and use the normal review, commit, and
   deployment process.

No Form submission or Sheet edit invokes these steps automatically.

## Staging test matrix

Use copies of all Google resources and record expected/actual results.

| Test | Expected result |
|---|---|
| Authorized AP-LS staff account | One direct Editor grant or adequate existing access; one Active row; correct tab link. |
| Authorized EC member | Grant only for the exact rostered content key. |
| Authorized chair with personal Google account | Grant succeeds only when external sharing policy permits it. |
| General member, public, Other, blank, or altered role | No Drive permission call; denial logged; no Sheet ID/link disclosed to requester. |
| Eligible role but missing/inactive/expired roster row | Denied before Drive permission or headshot processing. |
| Tampered content label, arbitrary ID, GID, path, command, or URL | No exact allowlist match; denied. |
| Replayed submit trigger | Existing response ID causes a no-op. |
| New request for another tab in same workbook | Existing active grant reused; no second permission or Active row; new raw/log record retained. |
| Existing direct Viewer/Commenter | Upgraded once to Editor; provenance prevents automatic offboarding deletion. |
| Existing direct Editor or higher | No mutation; preexisting direct provenance recorded. |
| Existing inherited individual Editor | No mutation; inherited provenance recorded. |
| Existing access through a Google Group | Group membership may not be visible in the file permission list; a redundant direct grant is possible and group access is managed at its source. |
| External sharing/Drive API failure | Failure and attempt logged; requester gets no Sheet link; administrator gets error. |
| Protected headers/unrelated tabs | Requester edits intended cells but cannot alter protected areas. |
| No headshot | Status `NONE`; no destination file. |
| One JPEG, PNG, or WebP under 10 MB | One deterministic copy; original retained; stored URL logged. |
| Two uploads, wrong MIME, oversized file | Rejected, no copy, explicit log/admin status. |
| Transient headshot copy failure and retry | One destination copy at most; retry finds copy by ID/name. |
| Administrator email failure | Permission/copy state retained; only failed email retries. |
| Requester email failure | Permission not recreated; only requester email retries. |
| Access retry after policy correction | Original verified response and current roster revalidated; one grant at most. |
| Five failed attempts | Hourly retries stop; row remains visible for administrator recovery. |
| Tracker row removed accidentally | `repairRequestTracker()` recreates working state; raw response/log unchanged. |
| Revocation of automation-created direct permission | Exact permission removed and row archived. |
| Revocation of preexisting/inherited permission | Function refuses deletion and marks administrator action required. |
| Close/restore | Archive/restore changes tracking only and never recreates or deletes access. |

After production launch, recheck quarterly: Form verified-email setting and
question labels, roster editors and dates, content registry IDs/GIDs,
workbook protections, Drive API service, Script Properties, installed triggers,
automation owner/backup owner, administrator address, headshot-folder policy,
and the deployed Apps Script against this repository backup.
