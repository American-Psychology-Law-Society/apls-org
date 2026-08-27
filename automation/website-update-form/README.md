# Website update request automation

This folder contains the backed-up source for the Google Apps Script that
processes the AP-LS website update request Form. The Form remains the simple
public interface; contributors do not need R, Git, or access to the website
source.

## Form questions

Keep the current requester-role choices, but use these question titles so the
automation can identify responses reliably:

1. **Your name** — required short answer.
2. **Your email address** — use the Form setting **Collect email addresses →
   Verified**. A typed email question may remain for display, but it is never
   used to grant document access.
3. **Request is being made by:** — required; retain the current choices.
4. **Page URL** — required short answer. Description: “Paste the address of
   the ap-ls.org page that needs an update.”
5. **What kind of update is this?** — wording or clarity; factual correction;
   date or deadline; link or file; add or remove content; accessibility; other.
6. **What needs to change?** — required long answer.
7. **Suggested replacement wording (optional)** — long answer.
8. **Upload supporting files (optional)** — file upload. Allow common office
   documents, PDFs, and images, with a reasonable number and size limit.
9. **Link to supporting material (optional)** — short answer. This is the
   fallback for files already stored in a Shared Drive or files that cannot be
   uploaded through the Form.
10. **When is this needed? (optional)** — date.
11. **Do you already have access to the ap-ls.org Shared Drive?** — yes; no;
    not sure.
12. **Is there anything else we should know about this change?** — long
    answer.

The Form must remain in a controlled AP-LS account’s **My Drive** because a
Form containing a file-upload question cannot live in a Shared Drive. Link the
Form to a response spreadsheet before setting up the automation.

## One-time setup

1. Run `publish_review_site()` from the website project to create the full-site
   Google Docs snapshot and the stable **AP-LS Website Review Index** Google
   Sheet. Record the value returned by
   `attr(site_manifest, "index_spreadsheet_id")`.
2. In the `ap-ls.org` Shared Drive, create `Website Reviews/Requests` and copy
   the folder ID from its browser URL.
3. Open the Form's **Website updates** response spreadsheet and choose
   **Extensions → Apps Script**. This creates a project owned by the controlled
   AP-LS account and linked to the response spreadsheet.
4. Replace the starter `Code.gs` with the `Code.gs` from this folder. In the
   Apps Script editor, add the **Drive API** under **Services**. The backed-up
   `appsscript.json` in this folder records the same service and runtime
   configuration.
5. In **Project settings → Script Properties**, add:

   - `FORM_ID`: the ID from the Form edit URL.
   - `ADMIN_EMAIL`: the address that should receive requests.
   - `REQUEST_FOLDER_ID`: the ID of `Website Reviews/Requests`.
   - `SITE_INDEX_SPREADSHEET_ID`: the ID printed after publishing the full-site
     review snapshot.
   - `SHARED_DRIVE_NAME`: `ap-ls.org`.
   - `SITE_BASE_URL`: `https://ap-ls.org`.

6. Confirm that the Advanced Google Drive service is enabled.
7. Run `setupAutomation()` manually and approve the requested permissions.
8. Run `showWebsitePrefillSetting()`. Copy the printed assignment into the top
   of `assets/a11y.html`, replacing the empty `APLS_PAGE_URL_ENTRY` value. This
   uses Google’s verified prefilled URL instead of guessing the question’s
   internal entry number.
9. Submit a test request from a second Google account that has the same access
   a normal reviewer will have.

`setupAutomation()` creates **Automation Log**, **Active Requests**, and
**Archived Requests** sheets. It installs the Form submission trigger, the
request-status edit trigger, and an hourly retry trigger. Running it again is
safe because it will not create duplicate triggers or request rows.

For the staff and Executive Committee/committee-chair Form routes, the
confirmation email contains the Google Doc matched from the submitted page
URL. General AP-LS members and public requesters receive a normal submission
confirmation instead. If an internal request does not match an uploaded page,
the requester receives a follow-up notice and the administrator email records
the lookup failure instead of sending a broken link.

Before emailing an internal requester, the automation grants the verified
Google Forms respondent email **Commenter** access to that one Google Doc. It
does not grant access for the general-member, public, or Other routes. If the
Shared Drive or Google Workspace administrator blocks external sharing, the
attempt is recorded as **ACCESS FAILED**, the inaccessible link is withheld,
and the administrator receives the failure details.

## Track and archive requests

Use **Active Requests** for day-to-day work; do not move or delete rows from
the Form response tab or **Automation Log**.

1. A new submission appears in **Active Requests** with status **New**.
2. Change the status to **In progress** or **Waiting for information** while
   working on it.
3. Change the status to **Completed** when the request is resolved. The row is
   copied to **Archived Requests**, timestamped, and then removed from the
   active sheet.
4. To reopen a request, change its archived status to **Restore**. It returns
   to **Active Requests** with status **In progress**.

The raw Form response and Automation Log row are never moved or deleted. The
hourly trigger also repairs missing tracker rows and processes a status change
if the edit trigger was temporarily unavailable. Run `repairRequestTracker()`
manually at any time to perform the same safe repair immediately.

The script validates page addresses with its own Apps Script-compatible URL
parser. Browser-only globals such as `URL` are not used because they are not
available in Google Apps Script trigger executions.

If a submission trigger fails before writing to **Automation Log**, correct
the underlying problem and run `reprocessLatestFormResponse()`. It processes
only the newest Form response and is safe to run again because the response ID
prevents duplicates.

## Safeguards

- Every request has a stable ID such as `WEB-20260826-001`.
- The Form response ID prevents repeated trigger events from creating
  duplicate requests.
- The response spreadsheet and Automation Log remain the source of truth if
  email delivery fails.
- Archiving moves only the working copy. The Form response and Automation Log
  remain as permanent backups, and request IDs prevent duplicate tracker rows.
- Review access uses only Google Forms' verified respondent email, grants the
  least-privileged Commenter role, and is limited to the matched document.
- Failed administrator emails are retried hourly, up to five attempts.
- Attachments are copied into a request-specific Shared Drive folder. The
  original Form upload is retained, and its link is recorded if copying fails.
- Only a validated AP-LS URL and generated request ID appear in executable R
  code. Free-text responses are never inserted into the code block.
- Administrator email includes a plain-text version as well as formatted HTML.

## Test before production

Use a duplicate Form and a staging folder first. Test a valid page, URL query
parameters, an external URL, no attachment, several attachments, a Shared
Drive link, a wrong Google account, an intentional email failure, and a
repeated trigger. Confirm that the emailed R command creates the correct review
document before replacing the website footer link.
