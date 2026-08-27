/**
 * AP-LS website update request automation.
 *
 * This is intended to run from the Form response spreadsheet's Apps Script
 * project with installable Form-submit and spreadsheet-edit triggers.
 * Configuration belongs in Script Properties; do not put account addresses
 * or Drive IDs in this file.
 */

const AP_LS_CONFIG = Object.freeze({
  logSheetName: 'Automation Log',
  activeSheetName: 'Active Requests',
  archivedSheetName: 'Archived Requests',
  handlerName: 'onWebsiteUpdateRequest',
  retryHandlerName: 'retryFailedNotifications',
  workflowEditHandlerName: 'onRequestStatusEdit',
  maximumEmailAttempts: 5,
  propertyNames: Object.freeze({
    formId: 'FORM_ID',
    administratorEmail: 'ADMIN_EMAIL',
    requestFolderId: 'REQUEST_FOLDER_ID',
    siteIndexSpreadsheetId: 'SITE_INDEX_SPREADSHEET_ID',
    sharedDriveName: 'SHARED_DRIVE_NAME',
    siteBaseUrl: 'SITE_BASE_URL'
  }),
  questions: Object.freeze({
    name: ['Your name'],
    email: ['Your email address', 'Email address'],
    role: ['Request is being made by:'],
    pageUrl: ['Page URL', 'Which website page needs an update?'],
    updateType: ['What kind of update is this?'],
    changeDetails: ['What needs to change?'],
    replacementText: ['Suggested replacement wording (optional)'],
    supportingLink: ['Link to supporting material (optional)'],
    neededBy: ['When is this needed? (optional)'],
    driveAccess: ['Do you already have access to the ap-ls.org Shared Drive?'],
    additionalNotes: ['Is there anything else we should know about this change?'],
    attachments: ['Upload supporting files (optional)']
  })
});

const AP_LS_LOG_HEADERS = Object.freeze([
  'response_id',
  'request_id',
  'submitted_at',
  'name',
  'email',
  'role',
  'page_url',
  'update_type',
  'change_details',
  'replacement_text',
  'supporting_link',
  'needed_by',
  'drive_access',
  'additional_notes',
  'attachment_links',
  'attachment_status',
  'review_document_url',
  'review_document_status',
  'email_status',
  'confirmation_status',
  'attempts',
  'last_error',
  'updated_at'
]);

const AP_LS_TRACKER_HEADERS = Object.freeze([
  'request_id',
  'submitted_at',
  'name',
  'email',
  'role',
  'page_url',
  'update_type',
  'change_details',
  'replacement_text',
  'supporting_link',
  'needed_by',
  'additional_notes',
  'attachment_links',
  'review_document_url',
  'workflow_status',
  'completed_at',
  'archived_at',
  'workflow_updated_at'
]);

const AP_LS_ACTIVE_STATUSES = Object.freeze([
  'New',
  'In progress',
  'Waiting for information',
  'Completed'
]);

const AP_LS_ARCHIVED_STATUSES = Object.freeze([
  'Completed',
  'Restore'
]);

/**
 * Validates configuration, creates the log sheet, and installs triggers.
 * Run this manually once after setting Script Properties.
 */
function setupAutomation() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheetId = form.getDestinationId();
  if (!spreadsheetId) {
    throw new Error('The Form must be linked to a response spreadsheet first.');
  }

  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const logSheet = ensureLogSheet_(spreadsheet);
  ensureWorkflowSheets_(spreadsheet);
  syncRequestTrackers_(spreadsheet, logSheet);
  validateFormQuestions_(form);
  validateReviewIndex_(settings);
  ensureTrigger_(AP_LS_CONFIG.handlerName, form);
  ensureWorkflowEditTrigger_(spreadsheet);
  ensureRetryTrigger_();
}

/**
 * Prints the verified Google Forms entry key for the Page URL question.
 * Paste the printed assignment into assets/a11y.html in the website project.
 *
 * @return {string} JavaScript assignment for the website configuration.
 */
function showWebsitePrefillSetting() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const pageItem = form.getItems().find(function(item) {
    return AP_LS_CONFIG.questions.pageUrl.includes(item.getTitle());
  });
  if (!pageItem || pageItem.getType() !== FormApp.ItemType.TEXT) {
    throw new Error('Page URL must be a short-answer question before generating the prefill setting.');
  }

  const marker = 'APLS_CURRENT_PAGE_URL';
  const response = form.createResponse().withItemResponse(
    pageItem.asTextItem().createResponse(marker)
  );
  const prefilledUrl = response.toPrefilledUrl();
  const match = prefilledUrl.match(/[?&](entry\.\d+)=APLS_CURRENT_PAGE_URL(?:&|$)/);
  if (!match) {
    throw new Error('Google Forms did not return a recognizable prefilled Page URL.');
  }
  const setting = 'window.APLS_PAGE_URL_ENTRY = "' + match[1] + '";';
  console.log(setting);
  return setting;
}

/**
 * Handles a Form submission. This must be an installable Form trigger.
 *
 * @param {GoogleAppsScript.Events.FormsOnFormSubmit} event Form event.
 */
function onWebsiteUpdateRequest(event) {
  if (!event || !event.response) {
    throw new Error('This function must be called by a Google Form submit trigger.');
  }

  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const sheet = ensureLogSheet_(spreadsheet);
  const responseId = event.response.getId();

  if (findLogRow_(sheet, 'response_id', responseId)) {
    return;
  }

  const request = requestFromResponse_(event.response, settings);
  request.responseId = responseId;
  request.requestId = nextRequestId_();

  const attachmentResult = copyAttachments_(
    request.attachmentIds,
    request.requestId,
    settings.requestFolderId
  );
  request.attachmentLinks = attachmentResult.links.join('\n');
  request.attachmentStatus = attachmentResult.status;
  const reviewDocument = reviewDocumentForRequest_(request, settings);
  request.reviewDocumentUrl = reviewDocument.url;
  request.reviewDocumentStatus = reviewDocument.status;
  request.emailStatus = 'PENDING';
  request.confirmationStatus = request.email ? 'PENDING' : 'NOT REQUESTED';
  request.attempts = 0;
  request.lastError = attachmentResult.errors
    .concat(reviewDocument.errors)
    .join(' | ');

  const row = appendRequest_(sheet, request);
  try {
    appendActiveRequest_(spreadsheet, request);
  } catch (trackerError) {
    request.lastError = joinErrors_(
      request.lastError,
      'Request tracker: ' + trackerError.message
    );
    updateLogCells_(sheet, row, {
      last_error: request.lastError,
      updated_at: new Date()
    });
  }
  sendAndRecord_(sheet, row, request, settings);
}

/**
 * Moves completed requests to Archived Requests and restores rows marked
 * Restore. This must be an installable spreadsheet edit trigger.
 *
 * @param {GoogleAppsScript.Events.SheetsOnEdit} event Spreadsheet edit event.
 */
function onRequestStatusEdit(event) {
  if (!event || !event.range) {
    throw new Error('This function must be called by a spreadsheet edit trigger.');
  }

  const sheet = event.range.getSheet();
  const sheetName = sheet.getName();
  if (![AP_LS_CONFIG.activeSheetName, AP_LS_CONFIG.archivedSheetName]
      .includes(sheetName)) {
    return;
  }

  const statusColumn = AP_LS_TRACKER_HEADERS.indexOf('workflow_status') + 1;
  const firstColumn = event.range.getColumn();
  const lastColumn = event.range.getLastColumn();
  if (statusColumn < firstColumn || statusColumn > lastColumn) return;

  const firstRow = Math.max(event.range.getRow(), 2);
  const lastRow = event.range.getLastRow();
  const spreadsheet = sheet.getParent();
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    for (let row = lastRow; row >= firstRow; row -= 1) {
      const status = String(sheet.getRange(row, statusColumn).getValue()).trim();
      if (sheetName === AP_LS_CONFIG.activeSheetName && status === 'Completed') {
        archiveTrackerRow_(spreadsheet, row);
      } else if (
        sheetName === AP_LS_CONFIG.archivedSheetName && status === 'Restore'
      ) {
        restoreTrackerRow_(spreadsheet, row);
      }
    }
  } finally {
    lock.releaseLock();
  }
}

/**
 * Repairs tracker sheets and processes any status changes missed by a trigger.
 * It is safe to run this function more than once.
 */
function repairRequestTracker() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const logSheet = ensureLogSheet_(spreadsheet);
  repairRequestTracker_(spreadsheet, logSheet);
}

/**
 * Reprocesses the most recent Form response when a trigger failed before it
 * reached the Automation Log. Repeated runs are safe because response IDs are
 * deduplicated by onWebsiteUpdateRequest().
 */
function reprocessLatestFormResponse() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const responses = form.getResponses();
  if (!responses.length) {
    throw new Error('The Form has no responses to reprocess.');
  }
  const response = responses[responses.length - 1];
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const logSheet = ensureLogSheet_(spreadsheet);
  const rowNumber = findLogRow_(logSheet, 'response_id', response.getId());
  if (!rowNumber) {
    onWebsiteUpdateRequest({response: response});
    return;
  }
  repairLoggedResponse_(response, settings, spreadsheet, logSheet, rowNumber);
}

function repairLoggedResponse_(response, settings, spreadsheet, logSheet, rowNumber) {
  const headers = headerMap_(
    logSheet.getRange(1, 1, 1, AP_LS_LOG_HEADERS.length).getValues()[0]
  );
  const logged = requestFromLogRow_(
    logSheet.getRange(rowNumber, 1, 1, AP_LS_LOG_HEADERS.length).getValues()[0],
    headers
  );
  const request = requestFromResponse_(response, settings);
  request.responseId = response.getId();
  request.requestId = logged.requestId;
  request.attachmentLinks = logged.attachmentLinks;
  request.attachmentStatus = logged.attachmentStatus;
  request.emailStatus = logged.emailStatus;
  request.confirmationStatus = logged.confirmationStatus;
  request.attempts = logged.attempts;

  const reviewDocument = reviewDocumentForRequest_(request, settings);
  request.reviewDocumentUrl = reviewDocument.url;
  request.reviewDocumentStatus = reviewDocument.status;
  request.lastError = reviewDocument.errors.join(' | ');

  updateLogCells_(logSheet, rowNumber, {
    review_document_url: request.reviewDocumentUrl,
    review_document_status: request.reviewDocumentStatus,
    last_error: request.lastError,
    updated_at: new Date()
  });
  updateTrackerReviewDocument_(
    spreadsheet,
    request.requestId,
    request.reviewDocumentUrl
  );

  if (!reviewDocumentAccessReady_(request)) {
    throw new Error(
      request.lastError || 'Google Doc access could not be granted.'
    );
  }
  try {
    sendConfirmationEmail_(request);
    updateLogCells_(logSheet, rowNumber, {
      confirmation_status: 'SENT',
      updated_at: new Date()
    });
  } catch (error) {
    updateLogCells_(logSheet, rowNumber, {
      confirmation_status: 'FAILED',
      last_error: joinErrors_(request.lastError, error.message),
      updated_at: new Date()
    });
    throw error;
  }
}

/**
 * Retries administrator notifications that did not send successfully.
 * The setup function installs this as an hourly trigger.
 */
function retryFailedNotifications() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const sheet = ensureLogSheet_(spreadsheet);
  const values = sheet.getDataRange().getValues();
  if (values.length >= 2) {
    const headers = headerMap_(values[0]);
    for (let index = 1; index < values.length; index += 1) {
      const row = values[index];
      const status = String(row[headers.email_status] || '');
      const attempts = Number(row[headers.attempts] || 0);
      if (status === 'SENT' || attempts >= AP_LS_CONFIG.maximumEmailAttempts) {
        continue;
      }
      sendAndRecord_(sheet, index + 1, requestFromLogRow_(row, headers), settings);
    }
  }

  repairRequestTracker_(spreadsheet, sheet);
}

function requestFromResponse_(response, settings) {
  const answers = {};
  const attachmentIds = [];

  response.getItemResponses().forEach(function(itemResponse) {
    const item = itemResponse.getItem();
    const title = item.getTitle().trim();
    const answer = itemResponse.getResponse();
    answers[title] = Array.isArray(answer) ? answer.join('\n') : String(answer || '');
    if (item.getType() === FormApp.ItemType.FILE_UPLOAD && Array.isArray(answer)) {
      answer.forEach(function(fileId) { attachmentIds.push(fileId); });
    }
  });

  const verifiedRespondentEmail = response.getRespondentEmail() || '';
  const respondentEmail = verifiedRespondentEmail ||
    answerFor_(answers, AP_LS_CONFIG.questions.email);

  return {
    submittedAt: response.getTimestamp(),
    name: answerFor_(answers, AP_LS_CONFIG.questions.name),
    email: respondentEmail,
    sharingEmail: verifiedRespondentEmail,
    role: answerFor_(answers, AP_LS_CONFIG.questions.role),
    pageUrl: normalizePageUrl_(
      answerFor_(answers, AP_LS_CONFIG.questions.pageUrl),
      settings.siteBaseUrl
    ),
    updateType: answerFor_(answers, AP_LS_CONFIG.questions.updateType),
    changeDetails: answerFor_(answers, AP_LS_CONFIG.questions.changeDetails),
    replacementText: answerFor_(answers, AP_LS_CONFIG.questions.replacementText),
    supportingLink: answerFor_(answers, AP_LS_CONFIG.questions.supportingLink),
    neededBy: answerFor_(answers, AP_LS_CONFIG.questions.neededBy),
    driveAccess: answerFor_(answers, AP_LS_CONFIG.questions.driveAccess),
    additionalNotes: answerFor_(answers, AP_LS_CONFIG.questions.additionalNotes),
    attachmentIds: attachmentIds
  };
}

function answerFor_(answers, titles) {
  for (let index = 0; index < titles.length; index += 1) {
    if (Object.prototype.hasOwnProperty.call(answers, titles[index])) {
      return answers[titles[index]];
    }
  }
  return '';
}

function normalizePageUrl_(value, siteBaseUrl) {
  if (!value) throw new Error('A website page URL is required.');
  const page = parseHttpUrl_(value);
  const site = parseHttpUrl_(siteBaseUrl);
  const pageHost = page.hostname.replace(/^www\./, '');
  const siteHost = site.hostname.replace(/^www\./, '');
  if (!['http:', 'https:'].includes(page.protocol) || pageHost !== siteHost) {
    throw new Error('The page URL must belong to ' + siteHost + '.');
  }
  return 'https://' + siteHost + (page.pathname || '/');
}

function parseHttpUrl_(value) {
  const match = String(value || '').trim().match(
    /^(https?):\/\/([^\/?#]+)(\/[^?#]*)?(?:\?[^#]*)?(?:#.*)?$/i
  );
  if (!match) {
    throw new Error('The page URL must be a complete HTTP or HTTPS URL.');
  }
  return {
    protocol: match[1].toLowerCase() + ':',
    hostname: match[2].toLowerCase(),
    pathname: match[3] || '/'
  };
}

function reviewDocumentForRequest_(request, settings) {
  if (!isInternalReviewerRole_(request.role)) {
    return {url: '', status: 'NOT REQUESTED', errors: []};
  }
  try {
    const url = lookupReviewDocument_(
      request.pageUrl,
      settings.siteIndexSpreadsheetId,
      settings.siteBaseUrl
    );
    if (!url) {
      return {
        url: '',
        status: 'NOT FOUND',
        errors: ['No full-site review document matched ' + request.pageUrl]
      };
    }
    const access = grantReviewDocumentAccess_(url, request.sharingEmail);
    return {
      url: url,
      status: 'FOUND; ' + access.status,
      errors: access.errors
    };
  } catch (error) {
    return {
      url: '',
      status: 'LOOKUP FAILED',
      errors: ['Review document lookup: ' + error.message]
    };
  }
}

function grantReviewDocumentAccess_(documentUrl, verifiedEmail) {
  if (!verifiedEmail) {
    return {
      status: 'ACCESS NOT GRANTED',
      errors: [
        'Review access requires the verified email collected by Google Forms.'
      ]
    };
  }
  const email = String(verifiedEmail).trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return {
      status: 'ACCESS NOT GRANTED',
      errors: ['The verified respondent email is not valid: ' + verifiedEmail]
    };
  }
  const match = String(documentUrl).match(
    /^https:\/\/docs\.google\.com\/document\/d\/([A-Za-z0-9_-]+)(?:\/|$)/
  );
  if (!match) {
    return {
      status: 'ACCESS NOT GRANTED',
      errors: ['The review document URL is not a recognized Google Doc link.']
    };
  }

  const fileId = match[1];
  try {
    const result = Drive.Permissions.list(fileId, {
      fields: 'permissions(id,emailAddress,role,type)',
      supportsAllDrives: true
    });
    const existing = (result.permissions || []).find(function(permission) {
      return permission.type === 'user' &&
        String(permission.emailAddress || '').toLowerCase() === email;
    });
    if (existing) {
      if (['commenter', 'writer', 'fileOrganizer', 'organizer', 'owner']
          .includes(existing.role)) {
        return {status: 'ACCESS ALREADY GRANTED', errors: []};
      }
      Drive.Permissions.update(
        {role: 'commenter'},
        fileId,
        existing.id,
        {supportsAllDrives: true}
      );
      return {status: 'ACCESS GRANTED', errors: []};
    }

    Drive.Permissions.create(
      {type: 'user', role: 'commenter', emailAddress: email},
      fileId,
      {
        sendNotificationEmail: false,
        supportsAllDrives: true,
        fields: 'id'
      }
    );
    return {status: 'ACCESS GRANTED', errors: []};
  } catch (error) {
    return {
      status: 'ACCESS FAILED',
      errors: ['Could not grant Google Doc access to ' + email + ': ' + error.message]
    };
  }
}

function reviewDocumentAccessReady_(request) {
  const status = String(request.reviewDocumentStatus || '');
  return status.includes('ACCESS GRANTED') ||
    status.includes('ACCESS ALREADY GRANTED');
}

function isInternalReviewerRole_(role) {
  const value = String(role || '').toLowerCase();
  return value.includes('ap-ls staff') ||
    value.includes('executive committee') ||
    value.includes('committee chair') ||
    value.includes('committee co-chair') ||
    value.includes('committee chair/co-chair');
}

function lookupReviewDocument_(pageUrl, spreadsheetId, siteBaseUrl) {
  const spreadsheet = SpreadsheetApp.openById(spreadsheetId);
  const sheets = spreadsheet.getSheets();
  if (!sheets.length) {
    throw new Error('The website review index has no sheets.');
  }
  const values = sheets[0].getDataRange().getValues();
  if (values.length < 2) return '';

  const headers = headerMap_(values[0]);
  ['live_url', 'document_url', 'status'].forEach(function(header) {
    if (!Object.prototype.hasOwnProperty.call(headers, header)) {
      throw new Error('The website review index is missing ' + header + '.');
    }
  });

  const requestedPage = pageLookupKey_(pageUrl, siteBaseUrl);
  for (let row = 1; row < values.length; row += 1) {
    const indexedPage = String(values[row][headers.live_url] || '');
    if (!indexedPage) continue;
    if (pageLookupKey_(indexedPage, siteBaseUrl) !== requestedPage) continue;
    if (String(values[row][headers.status] || '').toLowerCase() !== 'uploaded') {
      return '';
    }
    return String(values[row][headers.document_url] || '').trim();
  }
  return '';
}

function pageLookupKey_(value, siteBaseUrl) {
  const page = parseHttpUrl_(normalizePageUrl_(value, siteBaseUrl));
  let path;
  try {
    path = decodeURIComponent(page.pathname).replace(/^\/+/, '');
  } catch (error) {
    throw new Error('The page URL contains invalid encoded characters.');
  }
  if (!path) return 'index.html';
  if (path.endsWith('/')) return path + 'index.html';
  if (!/\.[A-Za-z0-9]+$/.test(path)) return path + '.html';
  return path;
}

function nextRequestId_() {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const date = Utilities.formatDate(new Date(), 'America/Chicago', 'yyyyMMdd');
    const property = 'REQUEST_SEQUENCE_' + date;
    const properties = PropertiesService.getScriptProperties();
    const sequence = Number(properties.getProperty(property) || 0) + 1;
    properties.setProperty(property, String(sequence));
    return 'WEB-' + date + '-' + String(sequence).padStart(3, '0');
  } finally {
    lock.releaseLock();
  }
}

function copyAttachments_(fileIds, requestId, requestFolderId) {
  if (!fileIds.length) {
    return {links: [], errors: [], status: 'NONE'};
  }

  const links = [];
  const errors = [];
  let destination;
  try {
    destination = findOrCreateFolder_(requestFolderId, requestId);
  } catch (error) {
    fileIds.forEach(function(fileId) {
      links.push('Original upload: https://drive.google.com/open?id=' + fileId);
    });
    return {
      links: links,
      errors: ['Could not create the Shared Drive request folder: ' + error.message],
      status: 'ORIGINALS ONLY'
    };
  }

  fileIds.forEach(function(fileId) {
    try {
      const original = Drive.Files.get(fileId, {
        fields: 'id,name,webViewLink',
        supportsAllDrives: true
      });
      const copy = Drive.Files.copy(
        {name: original.name, parents: [destination.id]},
        fileId,
        {fields: 'id,name,webViewLink', supportsAllDrives: true}
      );
      links.push(copy.name + ': ' + (copy.webViewLink ||
        'https://drive.google.com/open?id=' + copy.id));
    } catch (error) {
      links.push('Original upload: https://drive.google.com/open?id=' + fileId);
      errors.push('Attachment ' + fileId + ': ' + error.message);
    }
  });

  return {
    links: links,
    errors: errors,
    status: errors.length ? 'PARTIAL' : 'COPIED'
  };
}

function findOrCreateFolder_(parentId, name) {
  const escapedName = name.replace(/'/g, "\\'");
  const result = Drive.Files.list({
    q: "'" + parentId + "' in parents and trashed = false and " +
      "mimeType = 'application/vnd.google-apps.folder' and name = '" +
      escapedName + "'",
    fields: 'files(id,name,webViewLink)',
    includeItemsFromAllDrives: true,
    supportsAllDrives: true
  });
  if (result.files && result.files.length > 1) {
    throw new Error('More than one request folder is named ' + name + '.');
  }
  if (result.files && result.files.length === 1) return result.files[0];

  return Drive.Files.create(
    {
      name: name,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parentId]
    },
    null,
    {fields: 'id,name,webViewLink', supportsAllDrives: true}
  );
}

function appendRequest_(sheet, request) {
  const row = requestToLogRow_(request);
  sheet.appendRow(row);
  SpreadsheetApp.flush();
  return sheet.getLastRow();
}

function sendAndRecord_(sheet, rowNumber, request, settings) {
  const attempts = Number(request.attempts || 0) + 1;
  try {
    if (MailApp.getRemainingDailyQuota() < 2) {
      throw new Error('Google Mail daily quota is too low to send notifications.');
    }
    sendAdministratorEmail_(request, settings);
    updateLogCells_(sheet, rowNumber, {
      email_status: 'SENT',
      attempts: attempts,
      last_error: request.lastError || '',
      updated_at: new Date()
    });

    if (request.email && request.confirmationStatus !== 'SENT') {
      try {
        sendConfirmationEmail_(request);
        updateLogCells_(sheet, rowNumber, {
          confirmation_status: 'SENT',
          updated_at: new Date()
        });
      } catch (confirmationError) {
        updateLogCells_(sheet, rowNumber, {
          confirmation_status: 'FAILED',
          last_error: joinErrors_(request.lastError, confirmationError.message),
          updated_at: new Date()
        });
      }
    }
  } catch (error) {
    updateLogCells_(sheet, rowNumber, {
      email_status: 'FAILED',
      attempts: attempts,
      last_error: joinErrors_(request.lastError, error.message),
      updated_at: new Date()
    });
  }
}

function sendAdministratorEmail_(request, settings) {
  const code = requestRCode_(request, settings);
  const fields = [
    ['Submitted by', request.name],
    ['Email', request.email],
    ['Role', request.role],
    ['Page', request.pageUrl],
    ['Update type', request.updateType],
    ['Requested change', request.changeDetails],
    ['Suggested wording', request.replacementText],
    ['Supporting link', request.supportingLink],
    ['Needed by', request.neededBy],
    ['Shared Drive access', request.driveAccess],
    ['Additional notes', request.additionalNotes],
    ['Attachments', request.attachmentLinks],
    ['Attachment status', request.attachmentStatus],
    ['Review document', request.reviewDocumentUrl],
    ['Review document status', request.reviewDocumentStatus]
  ];
  const text = fields.map(function(field) {
    return field[0] + ': ' + (field[1] || '—');
  }).join('\n\n') + '\n\nR code\n\n' + code;
  const html = fields.map(function(field) {
    return '<p><strong>' + escapeHtml_(field[0]) + ':</strong> ' +
      linkify_(field[1] || '—') + '</p>';
  }).join('') + '<h2>R code</h2><pre><code>' + escapeHtml_(code) + '</code></pre>';

  MailApp.sendEmail({
    to: settings.administratorEmail,
    subject: '[' + request.requestId + '] Website update request: ' + request.pageUrl,
    body: text,
    htmlBody: html,
    name: 'AP-LS Website Requests'
  });
}

function sendConfirmationEmail_(request) {
  const lines = [
    'Thank you. Your AP-LS website update request has been received.',
    '',
    'Request number: ' + request.requestId,
    'Page: ' + request.pageUrl
  ];
  if (
    isInternalReviewerRole_(request.role) &&
    request.reviewDocumentUrl &&
    reviewDocumentAccessReady_(request)
  ) {
    lines.push(
      '',
      'Use this Google Doc to suggest edits or leave comments:',
      request.reviewDocumentUrl,
      '',
      'Please use Suggesting mode for wording changes. You can also add comments for larger requests.'
    );
  } else if (isInternalReviewerRole_(request.role)) {
    lines.push(
      '',
      'We could not automatically provide access to the Google Doc for this page. The website editor has been notified and will follow up.'
    );
  } else {
    lines.push(
      '',
      'The website editor will review the information you submitted and follow up if anything else is needed.'
    );
  }
  const body = lines.join('\n');
  MailApp.sendEmail({
    to: request.email,
    subject: 'AP-LS website request received: ' + request.requestId,
    body: body,
    name: 'AP-LS Website Requests'
  });
}

function requestRCode_(request, settings) {
  return [
    'devtools::load_all("apls-r")',
    '',
    'publish_review_request(',
    '  page_url = ' + rString_(request.pageUrl) + ',',
    '  request_id = ' + rString_(request.requestId) + ',',
    '  project_root = ".",',
    '  drive_path = "Website Reviews/Requests",',
    '  shared_drive = ' + rString_(settings.sharedDriveName) + ',',
    '  open = TRUE',
    ')'
  ].join('\n');
}

function rString_(value) {
  return '"' + String(value)
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\r/g, '\\r')
    .replace(/\n/g, '\\n') + '"';
}

function getSettings_() {
  const properties = PropertiesService.getScriptProperties();
  const names = AP_LS_CONFIG.propertyNames;
  const settings = {
    formId: properties.getProperty(names.formId),
    administratorEmail: properties.getProperty(names.administratorEmail),
    requestFolderId: properties.getProperty(names.requestFolderId),
    siteIndexSpreadsheetId: properties.getProperty(names.siteIndexSpreadsheetId),
    sharedDriveName: properties.getProperty(names.sharedDriveName) || 'ap-ls.org',
    siteBaseUrl: properties.getProperty(names.siteBaseUrl) || 'https://ap-ls.org'
  };
  const missing = [
    ['FORM_ID', settings.formId],
    ['ADMIN_EMAIL', settings.administratorEmail],
    ['REQUEST_FOLDER_ID', settings.requestFolderId],
    ['SITE_INDEX_SPREADSHEET_ID', settings.siteIndexSpreadsheetId]
  ].filter(function(entry) { return !entry[1]; }).map(function(entry) {
    return entry[0];
  });
  if (missing.length) {
    throw new Error('Missing Script Properties: ' + missing.join(', '));
  }
  return settings;
}

function validateFormQuestions_(form) {
  const titles = form.getItems().map(function(item) { return item.getTitle(); });
  const requiredGroups = [
    AP_LS_CONFIG.questions.name,
    AP_LS_CONFIG.questions.pageUrl,
    AP_LS_CONFIG.questions.changeDetails,
    AP_LS_CONFIG.questions.attachments
  ];
  const missing = requiredGroups.filter(function(aliases) {
    return !aliases.some(function(alias) { return titles.includes(alias); });
  }).map(function(aliases) { return aliases[0]; });
  if (missing.length) {
    throw new Error('The Form is missing required questions: ' + missing.join(', '));
  }
}

function validateReviewIndex_(settings) {
  const spreadsheet = SpreadsheetApp.openById(settings.siteIndexSpreadsheetId);
  const sheets = spreadsheet.getSheets();
  if (!sheets.length) {
    throw new Error('The website review index has no sheets.');
  }
  const values = sheets[0].getDataRange().getValues();
  if (!values.length) {
    throw new Error('The website review index is empty.');
  }
  const headers = headerMap_(values[0]);
  const missing = ['live_url', 'document_url', 'status'].filter(function(header) {
    return !Object.prototype.hasOwnProperty.call(headers, header);
  });
  if (missing.length) {
    throw new Error(
      'The website review index is missing columns: ' + missing.join(', ')
    );
  }
}

function ensureTrigger_(handlerName, form) {
  const exists = ScriptApp.getProjectTriggers().some(function(trigger) {
    return trigger.getHandlerFunction() === handlerName;
  });
  if (!exists) {
    ScriptApp.newTrigger(handlerName).forForm(form).onFormSubmit().create();
  }
}

function ensureRetryTrigger_() {
  const exists = ScriptApp.getProjectTriggers().some(function(trigger) {
    return trigger.getHandlerFunction() === AP_LS_CONFIG.retryHandlerName;
  });
  if (!exists) {
    ScriptApp.newTrigger(AP_LS_CONFIG.retryHandlerName)
      .timeBased()
      .everyHours(1)
      .create();
  }
}

function ensureWorkflowEditTrigger_(spreadsheet) {
  const exists = ScriptApp.getProjectTriggers().some(function(trigger) {
    return trigger.getHandlerFunction() === AP_LS_CONFIG.workflowEditHandlerName &&
      trigger.getTriggerSourceId() === spreadsheet.getId();
  });
  if (!exists) {
    ScriptApp.newTrigger(AP_LS_CONFIG.workflowEditHandlerName)
      .forSpreadsheet(spreadsheet)
      .onEdit()
      .create();
  }
}

function ensureLogSheet_(spreadsheet) {
  let sheet = spreadsheet.getSheetByName(AP_LS_CONFIG.logSheetName);
  if (!sheet) sheet = spreadsheet.insertSheet(AP_LS_CONFIG.logSheetName);
  const current = sheet.getRange(1, 1, 1, AP_LS_LOG_HEADERS.length).getValues()[0];
  if (current.every(function(value) { return value === ''; })) {
    sheet.getRange(1, 1, 1, AP_LS_LOG_HEADERS.length).setValues([AP_LS_LOG_HEADERS]);
    sheet.setFrozenRows(1);
  } else if (current.join('|') !== AP_LS_LOG_HEADERS.join('|')) {
    throw new Error('The Automation Log headers do not match the expected schema.');
  }
  return sheet;
}

function ensureWorkflowSheets_(spreadsheet) {
  return {
    active: ensureTrackerSheet_(
      spreadsheet,
      AP_LS_CONFIG.activeSheetName,
      AP_LS_ACTIVE_STATUSES
    ),
    archived: ensureTrackerSheet_(
      spreadsheet,
      AP_LS_CONFIG.archivedSheetName,
      AP_LS_ARCHIVED_STATUSES
    )
  };
}

function ensureTrackerSheet_(spreadsheet, name, statuses) {
  let sheet = spreadsheet.getSheetByName(name);
  if (!sheet) sheet = spreadsheet.insertSheet(name);
  if (sheet.getMaxRows() < 2) sheet.insertRowAfter(1);

  const headerRange = sheet.getRange(1, 1, 1, AP_LS_TRACKER_HEADERS.length);
  const current = headerRange.getValues()[0];
  if (current.every(function(value) { return value === ''; })) {
    headerRange.setValues([AP_LS_TRACKER_HEADERS]);
    headerRange
      .setBackground('#263238')
      .setFontColor('#ffffff')
      .setFontWeight('bold');
    sheet.setFrozenRows(1);
    sheet.setColumnWidth(1, 150);
    sheet.setColumnWidth(2, 145);
    sheet.setColumnWidth(3, 150);
    sheet.setColumnWidth(4, 190);
    sheet.setColumnWidth(5, 190);
    sheet.setColumnWidth(6, 260);
    sheet.setColumnWidth(7, 170);
    for (let column = 8; column <= 14; column += 1) {
      sheet.setColumnWidth(column, 260);
    }
    for (let column = 15; column <= AP_LS_TRACKER_HEADERS.length; column += 1) {
      sheet.setColumnWidth(column, 155);
    }
  } else if (current.join('|') !== AP_LS_TRACKER_HEADERS.join('|')) {
    throw new Error(name + ' headers do not match the expected schema.');
  }

  const statusColumn = AP_LS_TRACKER_HEADERS.indexOf('workflow_status') + 1;
  const validation = SpreadsheetApp.newDataValidation()
    .requireValueInList(statuses, true)
    .setAllowInvalid(false)
    .setHelpText('Choose a request status from the list.')
    .build();
  sheet.getRange(2, statusColumn, sheet.getMaxRows() - 1, 1)
    .setDataValidation(validation);
  sheet.getRange(2, 1, sheet.getMaxRows() - 1, AP_LS_TRACKER_HEADERS.length)
    .setWrap(true)
    .setVerticalAlignment('top');
  return sheet;
}

function appendActiveRequest_(spreadsheet, request) {
  const sheets = ensureWorkflowSheets_(spreadsheet);
  if (
    findTrackerRow_(sheets.active, request.requestId) ||
    findTrackerRow_(sheets.archived, request.requestId)
  ) {
    return;
  }
  sheets.active.appendRow(requestToTrackerRow_(request));
}

function syncRequestTrackers_(spreadsheet, logSheet) {
  const sheets = ensureWorkflowSheets_(spreadsheet);
  const knownIds = new Set(
    trackerRequestIds_(sheets.active).concat(trackerRequestIds_(sheets.archived))
  );
  const values = logSheet.getDataRange().getValues();
  if (values.length < 2) return;

  const headers = headerMap_(values[0]);
  for (let index = 1; index < values.length; index += 1) {
    const request = requestFromLogRow_(values[index], headers);
    if (!request.requestId || knownIds.has(String(request.requestId))) continue;
    sheets.active.appendRow(requestToTrackerRow_(request));
    knownIds.add(String(request.requestId));
  }
}

function requestToTrackerRow_(request) {
  const values = {
    request_id: request.requestId,
    submitted_at: request.submittedAt,
    name: request.name,
    email: request.email,
    role: request.role,
    page_url: request.pageUrl,
    update_type: request.updateType,
    change_details: request.changeDetails,
    replacement_text: request.replacementText,
    supporting_link: request.supportingLink,
    needed_by: request.neededBy,
    additional_notes: request.additionalNotes,
    attachment_links: request.attachmentLinks,
    review_document_url: request.reviewDocumentUrl || '',
    workflow_status: 'New',
    completed_at: '',
    archived_at: '',
    workflow_updated_at: new Date()
  };
  return AP_LS_TRACKER_HEADERS.map(function(header) { return values[header] || ''; });
}

function trackerRequestIds_(sheet) {
  if (sheet.getLastRow() < 2) return [];
  return sheet.getRange(2, 1, sheet.getLastRow() - 1, 1)
    .getValues()
    .map(function(row) { return String(row[0]); })
    .filter(function(value) { return value; });
}

function findTrackerRow_(sheet, requestId) {
  if (!requestId || sheet.getLastRow() < 2) return 0;
  const ids = sheet.getRange(2, 1, sheet.getLastRow() - 1, 1).getValues();
  for (let index = 0; index < ids.length; index += 1) {
    if (String(ids[index][0]) === String(requestId)) return index + 2;
  }
  return 0;
}

function updateTrackerReviewDocument_(spreadsheet, requestId, documentUrl) {
  const sheets = ensureWorkflowSheets_(spreadsheet);
  const documentColumn =
    AP_LS_TRACKER_HEADERS.indexOf('review_document_url') + 1;
  const updatedColumn =
    AP_LS_TRACKER_HEADERS.indexOf('workflow_updated_at') + 1;
  [sheets.active, sheets.archived].some(function(sheet) {
    const rowNumber = findTrackerRow_(sheet, requestId);
    if (!rowNumber) return false;
    sheet.getRange(rowNumber, documentColumn).setValue(documentUrl || '');
    sheet.getRange(rowNumber, updatedColumn).setValue(new Date());
    return true;
  });
}

function archiveTrackerRow_(spreadsheet, rowNumber) {
  const sheets = ensureWorkflowSheets_(spreadsheet);
  moveTrackerRow_(
    sheets.active,
    sheets.archived,
    rowNumber,
    'Completed',
    true
  );
}

function restoreTrackerRow_(spreadsheet, rowNumber) {
  const sheets = ensureWorkflowSheets_(spreadsheet);
  moveTrackerRow_(
    sheets.archived,
    sheets.active,
    rowNumber,
    'In progress',
    false
  );
}

function moveTrackerRow_(source, destination, rowNumber, status, archive) {
  if (rowNumber < 2 || rowNumber > source.getLastRow()) return;
  const row = source.getRange(
    rowNumber,
    1,
    1,
    AP_LS_TRACKER_HEADERS.length
  ).getValues()[0];
  const requestId = String(row[AP_LS_TRACKER_HEADERS.indexOf('request_id')] || '');
  if (!requestId) return;
  if (findTrackerRow_(destination, requestId)) {
    throw new Error(
      'Request ' + requestId + ' already exists in ' + destination.getName() + '.'
    );
  }

  const now = new Date();
  row[AP_LS_TRACKER_HEADERS.indexOf('workflow_status')] = status;
  row[AP_LS_TRACKER_HEADERS.indexOf('completed_at')] = archive ? now : '';
  row[AP_LS_TRACKER_HEADERS.indexOf('archived_at')] = archive ? now : '';
  row[AP_LS_TRACKER_HEADERS.indexOf('workflow_updated_at')] = now;

  destination.appendRow(row);
  SpreadsheetApp.flush();
  source.deleteRow(rowNumber);
}

function archiveCompletedRequests_(spreadsheet) {
  const active = ensureWorkflowSheets_(spreadsheet).active;
  const statusColumn = AP_LS_TRACKER_HEADERS.indexOf('workflow_status') + 1;
  for (let row = active.getLastRow(); row >= 2; row -= 1) {
    if (String(active.getRange(row, statusColumn).getValue()).trim() === 'Completed') {
      archiveTrackerRow_(spreadsheet, row);
    }
  }
}

function restoreArchivedRequests_(spreadsheet) {
  const archived = ensureWorkflowSheets_(spreadsheet).archived;
  const statusColumn = AP_LS_TRACKER_HEADERS.indexOf('workflow_status') + 1;
  for (let row = archived.getLastRow(); row >= 2; row -= 1) {
    if (String(archived.getRange(row, statusColumn).getValue()).trim() === 'Restore') {
      restoreTrackerRow_(spreadsheet, row);
    }
  }
}

function repairRequestTracker_(spreadsheet, logSheet) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    ensureWorkflowSheets_(spreadsheet);
    syncRequestTrackers_(spreadsheet, logSheet);
    archiveCompletedRequests_(spreadsheet);
    restoreArchivedRequests_(spreadsheet);
  } finally {
    lock.releaseLock();
  }
}

function findLogRow_(sheet, header, value) {
  const values = sheet.getDataRange().getValues();
  if (!values.length) return 0;
  const headers = headerMap_(values[0]);
  for (let index = 1; index < values.length; index += 1) {
    if (String(values[index][headers[header]]) === String(value)) return index + 1;
  }
  return 0;
}

function updateLogCells_(sheet, rowNumber, updates) {
  const headers = headerMap_(sheet.getRange(1, 1, 1, AP_LS_LOG_HEADERS.length).getValues()[0]);
  Object.keys(updates).forEach(function(name) {
    sheet.getRange(rowNumber, headers[name] + 1).setValue(updates[name]);
  });
}

function headerMap_(headers) {
  return headers.reduce(function(result, header, index) {
    result[String(header)] = index;
    return result;
  }, {});
}

function requestToLogRow_(request) {
  const values = {
    response_id: request.responseId,
    request_id: request.requestId,
    submitted_at: request.submittedAt,
    name: request.name,
    email: request.email,
    role: request.role,
    page_url: request.pageUrl,
    update_type: request.updateType,
    change_details: request.changeDetails,
    replacement_text: request.replacementText,
    supporting_link: request.supportingLink,
    needed_by: request.neededBy,
    drive_access: request.driveAccess,
    additional_notes: request.additionalNotes,
    attachment_links: request.attachmentLinks,
    attachment_status: request.attachmentStatus,
    review_document_url: request.reviewDocumentUrl,
    review_document_status: request.reviewDocumentStatus,
    email_status: request.emailStatus,
    confirmation_status: request.confirmationStatus,
    attempts: request.attempts,
    last_error: request.lastError,
    updated_at: new Date()
  };
  return AP_LS_LOG_HEADERS.map(function(header) { return values[header] || ''; });
}

function requestFromLogRow_(row, headers) {
  const value = function(name) { return row[headers[name]] || ''; };
  return {
    responseId: value('response_id'),
    requestId: value('request_id'),
    submittedAt: value('submitted_at'),
    name: value('name'),
    email: value('email'),
    role: value('role'),
    pageUrl: value('page_url'),
    updateType: value('update_type'),
    changeDetails: value('change_details'),
    replacementText: value('replacement_text'),
    supportingLink: value('supporting_link'),
    neededBy: value('needed_by'),
    driveAccess: value('drive_access'),
    additionalNotes: value('additional_notes'),
    attachmentLinks: value('attachment_links'),
    attachmentStatus: value('attachment_status'),
    reviewDocumentUrl: value('review_document_url'),
    reviewDocumentStatus: value('review_document_status'),
    emailStatus: value('email_status'),
    confirmationStatus: value('confirmation_status'),
    attempts: Number(value('attempts') || 0),
    lastError: value('last_error')
  };
}

function joinErrors_(first, second) {
  return [first, second].filter(function(value) { return value; }).join(' | ');
}

function escapeHtml_(value) {
  return String(value).replace(/[&<>'"]/g, function(character) {
    return {'&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'}[character];
  });
}

function linkify_(value) {
  return escapeHtml_(value).replace(
    /(https?:\/\/[^\s<]+)/g,
    '<a href="$1">$1</a>'
  ).replace(/\n/g, '<br>');
}
