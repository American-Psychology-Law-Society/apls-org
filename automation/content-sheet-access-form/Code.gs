/**
 * AP-LS website-content Sheet access automation.
 *
 * This project is installed on the response spreadsheet for a separate,
 * verified-email Google Form. It grants Editor access only after an exact
 * roster and hard-coded allowlist match. It never runs R or publishes the site.
 */

const ACCESS_CONFIG = Object.freeze({
  logSheetName: 'Automation Log',
  activeSheetName: 'Active Requests',
  archivedSheetName: 'Archived Requests',
  rosterSheetName: 'Authorized Requesters',
  submitHandlerName: 'onContentAccessRequest',
  editHandlerName: 'onAccessTrackerEdit',
  retryHandlerName: 'retryFailedOperations',
  maximumAttempts: 5,
  headshotMaximumBytes: 10 * 1024 * 1024,
  headshotMimeTypes: Object.freeze([
    'image/jpeg',
    'image/png',
    'image/webp'
  ]),
  eligibleRoles: Object.freeze([
    'AP-LS staff',
    'Executive Committee member',
    'Committee chair/co-chair'
  ]),
  allRoleChoices: Object.freeze([
    'AP-LS staff',
    'Executive Committee member',
    'Committee chair/co-chair',
    'General AP-LS member',
    'Member of the public',
    'Other'
  ]),
  acknowledgementChoices: Object.freeze([
    'I am signed in with the Google Account that should receive access.',
    'I understand access applies to the whole spreadsheet file, not only the linked tab.',
    'I will edit only the content area assigned to me.',
    'I understand my edits are reviewed before website publication.'
  ]),
  properties: Object.freeze({
    formId: 'FORM_ID',
    administratorEmail: 'ADMIN_EMAIL',
    headshotFolderId: 'HEADSHOT_FOLDER_ID'
  }),
  questions: Object.freeze({
    name: 'Your name',
    role: 'Your AP-LS role',
    contentArea: 'Which website content area do you need to edit?',
    purpose: 'Why do you need access?',
    requestedEnd: 'When should this access end?',
    existingAccess: 'Do you believe you already have access?',
    acknowledgements: 'Acknowledgements',
    headshot: 'Upload a leadership headshot (optional)'
  })
});

/*
 * The Form supplies only a friendly label. IDs, links, commands, paths, and
 * instructions always come from this immutable registry. Replace the three
 * REPLACE_WITH_* leadership tab values before setupAutomation() can succeed.
 * Add one separate, hard-coded entry per committee tab if direct tab links are
 * desired for individual committees.
 */
const CONTENT_AREAS = Object.freeze({
  leadership_ec: contentArea_({
    label: 'Executive Committee roster',
    spreadsheetId: '16RGHgDI7snPwaHfvF1gxTLAMet1V5_kM_4iHog2h7m8',
    tabName: 'EC',
    tabGid: 'REPLACE_WITH_EC_GID',
    updateCommand: 'source("about/_update-ec.R")',
    generatedFiles: ['about/executive-committee.yml', 'about/conf-chairs.yml'],
    validationInstructions: [
      'git diff --check',
      'git diff -- about/executive-committee.yml about/conf-chairs.yml'
    ],
    renderTargets: ['about/leadership.qmd', 'about/committees.qmd'],
    headshotEligible: true
  }),
  leadership_conference_chairs: contentArea_({
    label: 'Conference chairs roster',
    spreadsheetId: '16RGHgDI7snPwaHfvF1gxTLAMet1V5_kM_4iHog2h7m8',
    tabName: 'Conf_Chairs',
    tabGid: 'REPLACE_WITH_CONF_CHAIRS_GID',
    updateCommand: 'source("about/_update-ec.R")',
    generatedFiles: ['about/executive-committee.yml', 'about/conf-chairs.yml'],
    validationInstructions: [
      'git diff --check',
      'git diff -- about/executive-committee.yml about/conf-chairs.yml'
    ],
    renderTargets: ['about/leadership.qmd', 'about/committees.qmd'],
    headshotEligible: true
  }),
  leadership_committee_membership: contentArea_({
    label: 'Committee membership roster',
    spreadsheetId: '16RGHgDI7snPwaHfvF1gxTLAMet1V5_kM_4iHog2h7m8',
    tabName: 'REPLACE_WITH_APPROVED_COMMITTEE_TAB',
    tabGid: 'REPLACE_WITH_COMMITTEE_TAB_GID',
    updateCommand: 'source("about/_update-committees.R")',
    generatedFiles: [
      'about/data/committee-descriptions.csv',
      'about/data/committee-members.csv'
    ],
    validationInstructions: [
      'git diff --check',
      'git diff -- about/data/committee-descriptions.csv about/data/committee-members.csv'
    ],
    renderTargets: ['about/committees.qmd'],
    headshotEligible: true
  }),
  committee_descriptions: contentArea_({
    label: 'Committee descriptions',
    spreadsheetId: '17aXj7E4OE-vIgnRkNVZyw8BBjJ1MoXuroS71IqJ9rsI',
    tabName: 'committees',
    tabGid: '693851064',
    updateCommand: 'source("about/_update-committees.R")',
    generatedFiles: [
      'about/data/committee-descriptions.csv',
      'about/data/committee-members.csv'
    ],
    validationInstructions: [
      'git diff --check',
      'git diff -- about/data/committee-descriptions.csv about/data/committee-members.csv'
    ],
    renderTargets: ['about/committees.qmd'],
    headshotEligible: false
  }),
  awards_saleem_shah: awardArea_(
    'Saleem Shah Award winners', 'saleem-shah', '1132095481'
  ),
  awards_teaching: awardArea_(
    'Outstanding Teaching and Mentoring Award winners', 'teaching', '1619616463'
  ),
  awards_book: awardArea_(
    'Book Award winners', 'book', '1978764564'
  ),
  awards_undergrad_paper: awardArea_(
    'Undergraduate Paper Award winners', 'undergrad-paper', '1607457972'
  ),
  awards_dissertation: awardArea_(
    'Dissertation Award winners', 'dissertation', '1272861333'
  ),
  awards_distinguished: awardArea_(
    'Distinguished Contribution Award winners', 'distinguished', '1051535274'
  ),
  awards_reid: awardArea_(
    'REID Award and Grant recipients', 'REID', '461364966'
  )
});

function contentArea_(value) {
  value.enabled = true;
  value.allowedRoles = Object.freeze(ACCESS_CONFIG.eligibleRoles.slice());
  value.generatedFiles = Object.freeze(value.generatedFiles.slice());
  value.validationInstructions = Object.freeze(value.validationInstructions.slice());
  value.renderTargets = Object.freeze(value.renderTargets.slice());
  return Object.freeze(value);
}

function awardArea_(label, tabName, tabGid) {
  return contentArea_({
    label: label,
    spreadsheetId: '1iePnIxlQRviQ5Hf7Vayzgh59UzidN_pS72wUUHnSTbA',
    tabName: tabName,
    tabGid: tabGid,
    updateCommand: 'source("awards/_update-awards.R")',
    generatedFiles: [
      'awards/data/saleem-shah.csv',
      'awards/data/teaching.csv',
      'awards/data/book_awards.csv',
      'awards/data/undergrad-paper.csv',
      'awards/data/dissertation.csv',
      'awards/data/distinguished.csv',
      'awards/data/reid.csv'
    ],
    validationInstructions: [
      'git diff --check',
      'git diff -- awards/data/'
    ],
    renderTargets: [
      'awards/awards/saleemshah.qmd',
      'awards/awards/teachingaward.qmd',
      'awards/awards/bookaward.qmd',
      'awards/awards/undergradpaper.qmd',
      'awards/awards/dissertation.qmd',
      'awards/awards/distinguished.qmd',
      'awards/grants/impactgrant.qmd'
    ],
    headshotEligible: false
  });
}

const ROSTER_HEADERS = Object.freeze([
  'email', 'role', 'content_area_key', 'active', 'service_end_date'
]);

const LOG_HEADERS = Object.freeze([
  'response_id', 'request_id', 'active_grant_request_id', 'submitted_at',
  'name', 'verified_email', 'role', 'content_area_key', 'content_area_label',
  'purpose', 'requested_end_date', 'existing_access', 'acknowledgements',
  'authorization_status', 'authorization_service_end',
  'spreadsheet_id', 'tab_name', 'tab_gid',
  'access_status', 'access_attempts', 'access_last_error',
  'permission_id', 'permission_role', 'permission_provenance',
  'permission_created_by_automation',
  'headshot_original_id', 'headshot_stored_name', 'headshot_stored_file_id',
  'headshot_stored_url', 'headshot_status', 'headshot_attempts',
  'headshot_last_error',
  'admin_email_status', 'admin_email_attempts', 'admin_email_last_error',
  'requester_email_status', 'requester_email_attempts',
  'requester_email_last_error', 'updated_at'
]);

const TRACKER_HEADERS = Object.freeze([
  'request_id', 'submitted_at', 'name', 'verified_email', 'role',
  'content_area_key', 'content_area_label', 'spreadsheet_id', 'tab_name',
  'access_status', 'permission_id', 'permission_provenance',
  'permission_created_by_automation', 'authorization_service_end',
  'requested_end_date', 'headshot_status', 'headshot_stored_url',
  'workflow_status', 'access_review_status', 'completed_at', 'archived_at',
  'workflow_updated_at'
]);

const ACTIVE_STATUSES = Object.freeze([
  'Pending', 'Access active', 'Review due', 'Revocation approved',
  'Closed (access retained)'
]);

const ARCHIVED_STATUSES = Object.freeze([
  'Revoked', 'Denied', 'Closed (access retained)', 'Restore'
]);

/** Validate configuration, initialize protected sheets, and install triggers. */
function setupAutomation() {
  const settings = getSettings_();
  validateRegistry_();
  const form = FormApp.openById(settings.formId);
  if (!form.collectsEmail()) {
    throw new Error('The Form must collect verified respondent email addresses.');
  }
  if (!form.getDestinationId()) {
    throw new Error('Link the Form to a response spreadsheet before setup.');
  }
  validateFormQuestions_(form);
  validateHeadshotFolder_(settings.headshotFolderId);

  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  ensureLogSheet_(spreadsheet);
  ensureTrackerSheets_(spreadsheet);
  ensureRosterSheet_(spreadsheet);
  validateRosterRows_(spreadsheet.getSheetByName(ACCESS_CONFIG.rosterSheetName));
  ensureFormTrigger_(form);
  ensureEditTrigger_(spreadsheet);
  ensureRetryTrigger_();
  repairRequestTracker();
}

/** Installable Google Form submit trigger. */
function onContentAccessRequest(event) {
  if (!event || !event.response) {
    throw new Error('This function requires an installable Form submit trigger.');
  }
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const logSheet = ensureLogSheet_(spreadsheet);
  const responseId = event.response.getId();
  let rowNumber;
  let request;

  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    if (findRow_(logSheet, 'response_id', responseId)) return;
    request = requestFromResponse_(event.response);
    request.responseId = responseId;
    request.requestId = nextRequestIdWithoutLock_();
    initializeRequest_(request);
    authorizeRequest_(request, spreadsheet);
    rowNumber = appendLogRequest_(logSheet, request);
    createInitialTrackerRow_(spreadsheet, request);
  } finally {
    lock.releaseLock();
  }

  processAndNotify_(spreadsheet, logSheet, rowNumber, request, settings);
}

function initializeRequest_(request) {
  request.activeGrantRequestId = request.requestId;
  request.authorizationStatus = 'PENDING';
  request.authorizationServiceEnd = '';
  request.accessStatus = 'PENDING';
  request.accessAttempts = 0;
  request.accessLastError = '';
  request.permissionId = '';
  request.permissionRole = '';
  request.permissionProvenance = '';
  request.permissionCreatedByAutomation = false;
  request.headshotStoredName = '';
  request.headshotStoredFileId = '';
  request.headshotStoredUrl = '';
  request.headshotStatus = request.headshotIds.length ? 'PENDING' : 'NONE';
  request.headshotAttempts = 0;
  request.headshotLastError = '';
  request.adminEmailStatus = 'PENDING';
  request.adminEmailAttempts = 0;
  request.adminEmailLastError = '';
  request.requesterEmailStatus = 'PENDING';
  request.requesterEmailAttempts = 0;
  request.requesterEmailLastError = '';
}

function processAndNotify_(spreadsheet, logSheet, rowNumber, request, settings) {
  if (request.authorizationStatus === 'AUTHORIZED') {
    processAccessOperation_(spreadsheet, logSheet, rowNumber, request);
    applyHeadshotResult_(request, copyHeadshot_(request, settings.headshotFolderId));
  } else {
    request.accessStatus = 'DENIED';
    request.accessLastError = request.authorizationStatus;
    request.headshotStatus = request.headshotIds.length
      ? 'NOT PROCESSED - UNAUTHORIZED' : 'NONE';
  }

  updateLogFromRequest_(logSheet, rowNumber, request);
  updateTrackerFromRequest_(spreadsheet, request);
  sendNotifications_(logSheet, rowNumber, request, settings);
}

/**
 * Serializes the Drive permission operation together with its log/tracker
 * result. This prevents a concurrent duplicate request from seeing a newly
 * created permission before its automation-owned provenance is recorded.
 */
function processAccessOperation_(spreadsheet, logSheet, rowNumber, request) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const prior = findActiveGrant_(
      spreadsheet,
      request.verifiedEmail,
      request.area.spreadsheetId,
      request.requestId
    );
    if (prior) {
      request.activeGrantRequestId = prior.requestId;
      request.permissionId = prior.permissionId;
      request.permissionProvenance = prior.permissionProvenance;
      request.permissionCreatedByAutomation = prior.permissionCreatedByAutomation;
    }
    applyAccessResult_(request, grantEditorAccess_(request, prior));
    updateLogFromRequest_(logSheet, rowNumber, request);
    updateTrackerFromRequest_(spreadsheet, request);
  } finally {
    lock.releaseLock();
  }
}

function requestFromResponse_(response) {
  const answers = {};
  const uploads = [];
  response.getItemResponses().forEach(function(itemResponse) {
    const item = itemResponse.getItem();
    const title = String(item.getTitle() || '').trim();
    const answer = itemResponse.getResponse();
    if (Object.prototype.hasOwnProperty.call(answers, title)) {
      throw new Error('The Form contains duplicate question title: ' + title);
    }
    answers[title] = Array.isArray(answer) ? answer.join('\n') : String(answer || '');
    if (title === ACCESS_CONFIG.questions.headshot &&
        item.getType() === FormApp.ItemType.FILE_UPLOAD && Array.isArray(answer)) {
      answer.forEach(function(id) { uploads.push(String(id)); });
    }
  });

  const verifiedEmail = normalizeEmail_(response.getRespondentEmail());
  const role = answer_(answers, ACCESS_CONFIG.questions.role);
  const label = answer_(answers, ACCESS_CONFIG.questions.contentArea);
  const areaEntry = contentAreaByLabel_(label);
  return {
    submittedAt: response.getTimestamp(),
    name: answer_(answers, ACCESS_CONFIG.questions.name),
    verifiedEmail: verifiedEmail,
    role: role,
    contentAreaKey: areaEntry ? areaEntry.key : '',
    contentAreaLabel: label,
    area: areaEntry ? areaEntry.area : null,
    purpose: answer_(answers, ACCESS_CONFIG.questions.purpose),
    requestedEndDate: answer_(answers, ACCESS_CONFIG.questions.requestedEnd),
    existingAccess: answer_(answers, ACCESS_CONFIG.questions.existingAccess),
    acknowledgements: answer_(answers, ACCESS_CONFIG.questions.acknowledgements),
    headshotIds: uploads,
    headshotOriginalId: uploads.length === 1 ? uploads[0] : uploads.join('\n')
  };
}

function authorizeRequest_(request, spreadsheet) {
  if (!request.verifiedEmail || !isValidEmail_(request.verifiedEmail)) {
    request.authorizationStatus = 'DENIED - VERIFIED EMAIL MISSING OR INVALID';
    return;
  }
  if (!ACCESS_CONFIG.eligibleRoles.includes(request.role)) {
    request.authorizationStatus = 'DENIED - INELIGIBLE OR UNRECOGNIZED ROLE';
    return;
  }
  if (!request.area || !request.contentAreaKey) {
    request.authorizationStatus = 'DENIED - CONTENT AREA IS NOT ALLOWLISTED';
    return;
  }
  if (!/^\d+$/.test(String(request.area.tabGid)) ||
      /REPLACE_WITH_/.test(String(request.area.tabName))) {
    request.authorizationStatus = 'DENIED - CONTENT AREA CONFIGURATION IS INCOMPLETE';
    return;
  }
  const accepted = String(request.acknowledgements || '').split('\n');
  if (!ACCESS_CONFIG.acknowledgementChoices.every(function(choice) {
    return accepted.includes(choice);
  })) {
    request.authorizationStatus = 'DENIED - REQUIRED ACKNOWLEDGEMENTS MISSING';
    return;
  }
  if (!request.area.allowedRoles.includes(request.role)) {
    request.authorizationStatus = 'DENIED - ROLE IS NOT ALLOWED FOR CONTENT AREA';
    return;
  }

  const sheet = ensureRosterSheet_(spreadsheet);
  const values = sheet.getDataRange().getValues();
  const headers = headerMap_(values[0]);
  const matches = [];
  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    if (normalizeEmail_(row[headers.email]) !== request.verifiedEmail) continue;
    if (String(row[headers.role] || '').trim() !== request.role) continue;
    if (String(row[headers.content_area_key] || '').trim() !== request.contentAreaKey) continue;
    matches.push(row);
  }
  if (matches.length !== 1) {
    request.authorizationStatus = matches.length
      ? 'DENIED - DUPLICATE AUTHORIZATION ROWS' : 'DENIED - NOT ON AUTHORIZATION ROSTER';
    return;
  }
  const row = matches[0];
  if (!isRosterActive_(row[headers.active])) {
    request.authorizationStatus = 'DENIED - ROSTER ENTRY IS INACTIVE';
    return;
  }
  const serviceEnd = validServiceEnd_(row[headers.service_end_date]);
  if (!serviceEnd) {
    request.authorizationStatus = 'DENIED - SERVICE END DATE IS MISSING OR EXPIRED';
    return;
  }
  request.authorizationStatus = 'AUTHORIZED';
  request.authorizationServiceEnd = serviceEnd;
}

function grantEditorAccess_(request, prior) {
  const result = {
    status: 'FAILED', attempts: Number(request.accessAttempts || 0) + 1,
    error: '', permissionId: '', permissionRole: '', provenance: '', created: false
  };
  const fileId = request.area.spreadsheetId;
  try {
    const listed = Drive.Permissions.list(fileId, {
      fields: 'permissions(id,emailAddress,role,type,expirationTime,' +
        'permissionDetails(inherited,inheritedFrom))',
      supportsAllDrives: true
    });
    const permissions = (listed.permissions || []).filter(function(permission) {
      return permission.type === 'user' &&
        normalizeEmail_(permission.emailAddress) === request.verifiedEmail;
    });
    const adequate = permissions.find(function(permission) {
      return ['writer', 'fileOrganizer', 'organizer', 'owner'].includes(permission.role);
    });
    if (adequate) {
      const inherited = isInheritedPermission_(adequate);
      const automated = Boolean(prior && prior.permissionId === adequate.id &&
        prior.permissionCreatedByAutomation);
      result.status = 'ALREADY ADEQUATE';
      result.permissionId = adequate.id;
      result.permissionRole = adequate.role;
      result.provenance = inherited ? 'INHERITED' :
        (automated ? 'AUTOMATION_CREATED_DIRECT' : 'PREEXISTING_DIRECT');
      result.created = automated;
      return result;
    }

    const directLimited = permissions.find(function(permission) {
      return !isInheritedPermission_(permission) &&
        ['reader', 'commenter'].includes(permission.role);
    });
    if (directLimited) {
      const updated = Drive.Permissions.update(
        {role: 'writer'}, fileId, directLimited.id,
        {supportsAllDrives: true, fields: 'id,role'}
      );
      result.status = 'UPGRADED TO EDITOR';
      result.permissionId = updated.id || directLimited.id;
      result.permissionRole = updated.role || 'writer';
      result.provenance = 'PREEXISTING_DIRECT_UPGRADED';
      return result;
    }

    const created = Drive.Permissions.create(
      {type: 'user', role: 'writer', emailAddress: request.verifiedEmail},
      fileId,
      {sendNotificationEmail: false, supportsAllDrives: true, fields: 'id,role'}
    );
    result.status = 'GRANTED';
    result.permissionId = created.id;
    result.permissionRole = created.role || 'writer';
    result.provenance = 'AUTOMATION_CREATED_DIRECT';
    result.created = true;
    return result;
  } catch (error) {
    result.error = 'Could not grant Editor access: ' + error.message;
    return result;
  }
}

function isInheritedPermission_(permission) {
  return (permission.permissionDetails || []).some(function(detail) {
    return detail.inherited === true;
  });
}

function applyAccessResult_(request, result) {
  request.accessStatus = result.status;
  request.accessAttempts = result.attempts;
  request.accessLastError = result.error;
  request.permissionId = result.permissionId;
  request.permissionRole = result.permissionRole;
  request.permissionProvenance = result.provenance;
  request.permissionCreatedByAutomation = result.created;
}

function accessReady_(request) {
  return ['GRANTED', 'UPGRADED TO EDITOR', 'ALREADY ADEQUATE']
    .includes(String(request.accessStatus || ''));
}

function copyHeadshot_(request, destinationFolderId) {
  const result = {
    status: request.headshotIds.length ? 'FAILED' : 'NONE',
    attempts: Number(request.headshotAttempts || 0), error: '', storedName: '',
    storedFileId: '', storedUrl: ''
  };
  if (!request.headshotIds.length) return result;
  if (!request.area.headshotEligible) {
    result.status = 'NOT PROCESSED - NOT A LEADERSHIP REQUEST';
    return result;
  }
  if (request.headshotIds.length !== 1) {
    result.status = 'REJECTED';
    result.error = 'Exactly zero or one headshot may be uploaded.';
    return result;
  }
  result.attempts += 1;
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    if (request.headshotStoredFileId) {
      const existingById = Drive.Files.get(request.headshotStoredFileId, {
        fields: 'id,name,webViewLink,trashed', supportsAllDrives: true
      });
      if (!existingById.trashed) {
        result.status = 'ALREADY COPIED';
        result.storedName = existingById.name;
        result.storedFileId = existingById.id;
        result.storedUrl = existingById.webViewLink || driveOpenUrl_(existingById.id);
        return result;
      }
    }

    const original = Drive.Files.get(request.headshotIds[0], {
      fields: 'id,name,mimeType,size,trashed', supportsAllDrives: true
    });
    if (original.trashed) throw new Error('The original upload is in Trash.');
    if (!ACCESS_CONFIG.headshotMimeTypes.includes(original.mimeType)) {
      result.status = 'REJECTED';
      result.error = 'Headshots must be JPEG, PNG, or WebP images.';
      return result;
    }
    if (!original.size || Number(original.size) > ACCESS_CONFIG.headshotMaximumBytes) {
      result.status = 'REJECTED';
      result.error = 'The headshot is missing a valid size or exceeds 10 MB.';
      return result;
    }
    const storedName = request.headshotStoredName ||
      request.requestId + '__' + sanitizeFilename_(original.name);
    const found = findFileByName_(destinationFolderId, storedName);
    if (found) {
      result.status = 'ALREADY COPIED';
      result.storedName = found.name;
      result.storedFileId = found.id;
      result.storedUrl = found.webViewLink || driveOpenUrl_(found.id);
      return result;
    }
    const copy = Drive.Files.copy(
      {name: storedName, parents: [destinationFolderId]}, original.id,
      {fields: 'id,name,webViewLink', supportsAllDrives: true}
    );
    result.status = 'COPIED';
    result.storedName = copy.name;
    result.storedFileId = copy.id;
    result.storedUrl = copy.webViewLink || driveOpenUrl_(copy.id);
    return result;
  } catch (error) {
    result.error = 'Could not copy headshot: ' + error.message;
    return result;
  } finally {
    lock.releaseLock();
  }
}

function findFileByName_(folderId, name) {
  const escaped = String(name).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
  const listed = Drive.Files.list({
    q: "'" + folderId + "' in parents and trashed = false and name = '" +
      escaped + "'",
    fields: 'files(id,name,webViewLink)',
    includeItemsFromAllDrives: true,
    supportsAllDrives: true
  });
  if ((listed.files || []).length > 1) {
    throw new Error('Multiple destination files have the safe name ' + name + '.');
  }
  return (listed.files || [])[0] || null;
}

function applyHeadshotResult_(request, result) {
  request.headshotStatus = result.status;
  request.headshotAttempts = result.attempts;
  request.headshotLastError = result.error;
  request.headshotStoredName = result.storedName;
  request.headshotStoredFileId = result.storedFileId;
  request.headshotStoredUrl = result.storedUrl;
}

function sendNotifications_(logSheet, rowNumber, request, settings) {
  if (request.adminEmailStatus !== 'SENT' &&
      request.adminEmailAttempts < ACCESS_CONFIG.maximumAttempts) {
    request.adminEmailAttempts += 1;
    try {
      sendAdministratorEmail_(request, settings.administratorEmail);
      request.adminEmailStatus = 'SENT';
      request.adminEmailLastError = '';
    } catch (error) {
      request.adminEmailStatus = 'FAILED';
      request.adminEmailLastError = error.message;
    }
  }

  const canNotifyRequester = accessReady_(request) ||
    String(request.accessStatus) === 'DENIED';
  if (canNotifyRequester && request.verifiedEmail &&
      request.requesterEmailStatus !== 'SENT' &&
      request.requesterEmailAttempts < ACCESS_CONFIG.maximumAttempts) {
    request.requesterEmailAttempts += 1;
    try {
      sendRequesterEmail_(request);
      request.requesterEmailStatus = 'SENT';
      request.requesterEmailLastError = '';
    } catch (error) {
      request.requesterEmailStatus = 'FAILED';
      request.requesterEmailLastError = error.message;
    }
  } else if (!canNotifyRequester && request.requesterEmailStatus !== 'SENT') {
    request.requesterEmailStatus = 'WAITING FOR ACCESS';
  }
  updateLogFromRequest_(logSheet, rowNumber, request);
}

function sendAdministratorEmail_(request, administratorEmail) {
  if (MailApp.getRemainingDailyQuota() < 1) {
    throw new Error('Google Mail daily quota is exhausted.');
  }
  const area = request.area;
  const fields = [
    ['Request', request.requestId],
    ['Active grant request', request.activeGrantRequestId],
    ['Submitted by', request.name],
    ['Verified email', request.verifiedEmail],
    ['Claimed role', request.role],
    ['Authorization', request.authorizationStatus],
    ['Content area', request.contentAreaLabel],
    ['Purpose', request.purpose],
    ['Requested end date', request.requestedEndDate],
    ['Roster service end', request.authorizationServiceEnd],
    ['Access status', request.accessStatus],
    ['Access error', request.accessLastError],
    ['Permission provenance', request.permissionProvenance],
    ['Headshot status', request.headshotStatus],
    ['Stored headshot', request.headshotStoredUrl],
    ['Headshot error', request.headshotLastError]
  ];
  const text = fields.map(function(field) {
    return field[0] + ': ' + displayValue_(field[1]);
  });
  const html = fields.map(function(field) {
    return '<p><strong>' + escapeHtml_(field[0]) + ':</strong> ' +
      linkify_(displayValue_(field[1])) + '</p>';
  });

  if (area) {
    text.push('', 'Approved Sheet/tab:', administratorSheetUrl_(area));
    html.push('<p><strong>Approved Sheet/tab:</strong> ' +
      linkify_(administratorSheetUrl_(area)) + '</p>');
    text.push('', 'Manual website update command:', area.updateCommand,
      '', 'Inspect generated files:', area.generatedFiles.join('\n'),
      '', 'Validation:', area.validationInstructions.join('\n'),
      '', 'Render:', area.renderTargets.map(function(path) {
        return 'quarto render ' + path;
      }).join('\n'));
    html.push('<h2>Manual website update</h2><p>Run locally:</p><pre><code>' +
      escapeHtml_(area.updateCommand) + '</code></pre><p>Inspect generated files:</p><pre>' +
      escapeHtml_(area.generatedFiles.join('\n')) + '</pre><p>Validate:</p><pre><code>' +
      escapeHtml_(area.validationInstructions.join('\n')) +
      '</code></pre><p>Render:</p><pre><code>' + escapeHtml_(area.renderTargets.map(
        function(path) { return 'quarto render ' + path; }
      ).join('\n')) + '</code></pre>');
  }
  const warning = 'Editing a Google Sheet does not publish the website. Review the ' +
    'generated diff and rendered pages, then use the normal approval and deployment process.';
  text.push('', warning);
  html.push('<p><strong>' + escapeHtml_(warning) + '</strong></p>');

  MailApp.sendEmail({
    to: administratorEmail,
    subject: '[' + request.requestId + '] Website content Sheet access: ' +
      (request.contentAreaLabel || 'rejected selection'),
    body: text.join('\n'),
    htmlBody: html.join(''),
    name: 'AP-LS Website Content Access'
  });
}

function sendRequesterEmail_(request) {
  const lines = ['AP-LS website content access request', '',
    'Request number: ' + request.requestId];
  if (accessReady_(request)) {
    lines.push('', 'Your Editor access is ready:', requesterSheetUrl_(request.area), '',
      'Google Drive access applies to the whole spreadsheet file, not only the linked tab.',
      'Please edit only the content area assigned to you. Protected sheets or ranges may prevent changes elsewhere.',
      'Your Sheet edits do not publish the website. A website administrator will review and import them first.');
    if (request.headshotIds.length) {
      lines.push('', request.headshotStatus === 'COPIED' ||
        request.headshotStatus === 'ALREADY COPIED'
        ? 'Your optional headshot was copied to the approved AP-LS folder.'
        : 'Your optional headshot could not be copied automatically. The administrator has been notified.');
    }
  } else {
    lines.push('', 'This request was not approved. No spreadsheet access was granted.',
      'If you believe this is an error, contact the AP-LS website administrator.');
  }
  MailApp.sendEmail({
    to: request.verifiedEmail,
    subject: 'AP-LS content access request: ' + request.requestId,
    body: lines.join('\n'),
    name: 'AP-LS Website Content Access'
  });
}

/** Hourly retry: re-reads the original Form response and current roster. */
function retryFailedOperations() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const logSheet = ensureLogSheet_(spreadsheet);
  const values = logSheet.getDataRange().getValues();
  if (values.length < 2) return;
  const headers = headerMap_(values[0]);
  for (let index = 1; index < values.length; index += 1) {
    const logged = requestFromLogRow_(values[index], headers);
    if (!requestNeedsRetry_(logged)) continue;
    retryOne_(form, spreadsheet, logSheet, index + 1, logged, settings);
  }
  repairRequestTracker();
}

function requestNeedsRetry_(request) {
  return (request.accessStatus === 'FAILED' &&
      request.accessAttempts < ACCESS_CONFIG.maximumAttempts) ||
    (request.headshotStatus === 'FAILED' &&
      request.headshotAttempts < ACCESS_CONFIG.maximumAttempts) ||
    (request.adminEmailStatus !== 'SENT' &&
      request.adminEmailAttempts < ACCESS_CONFIG.maximumAttempts) ||
    (request.requesterEmailStatus !== 'SENT' &&
      request.requesterEmailAttempts < ACCESS_CONFIG.maximumAttempts &&
      (accessReady_(request) || request.accessStatus === 'DENIED'));
}

function retryOne_(form, spreadsheet, logSheet, rowNumber, logged, settings) {
  const response = form.getResponse(logged.responseId);
  if (!response) {
    updateLogCells_(logSheet, rowNumber, {
      access_last_error: 'Original Form response was not found; retry stopped.',
      updated_at: new Date()
    });
    return;
  }
  const request = requestFromResponse_(response);
  restoreOperationalState_(request, logged);
  authorizeRequest_(request, spreadsheet);
  if (request.authorizationStatus !== 'AUTHORIZED') {
    request.accessStatus = 'DENIED';
    request.accessLastError = request.authorizationStatus;
    request.headshotStatus = request.headshotIds.length
      ? 'NOT PROCESSED - UNAUTHORIZED' : 'NONE';
  } else {
    const oldReady = accessReady_(request);
    if (['PENDING', 'FAILED'].includes(request.accessStatus) &&
        request.accessAttempts < ACCESS_CONFIG.maximumAttempts) {
      processAccessOperation_(spreadsheet, logSheet, rowNumber, request);
      if (!oldReady && accessReady_(request) && request.adminEmailStatus === 'SENT') {
        request.adminEmailStatus = 'PENDING';
      }
    }
    if (request.headshotStatus === 'FAILED' &&
        request.headshotAttempts < ACCESS_CONFIG.maximumAttempts) {
      const oldHeadshotStatus = request.headshotStatus;
      applyHeadshotResult_(request, copyHeadshot_(request, settings.headshotFolderId));
      if (oldHeadshotStatus === 'FAILED' &&
          ['COPIED', 'ALREADY COPIED'].includes(request.headshotStatus) &&
          request.adminEmailStatus === 'SENT') {
        request.adminEmailStatus = 'PENDING';
      }
    }
  }
  updateLogFromRequest_(logSheet, rowNumber, request);
  updateTrackerFromRequest_(spreadsheet, request);
  sendNotifications_(logSheet, rowNumber, request, settings);
}

/** Reprocess only the newest response. Safe because response IDs are unique. */
function reprocessLatestFormResponse() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const responses = form.getResponses();
  if (!responses.length) throw new Error('The Form has no responses.');
  const response = responses[responses.length - 1];
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const logSheet = ensureLogSheet_(spreadsheet);
  const rowNumber = findRow_(logSheet, 'response_id', response.getId());
  if (!rowNumber) {
    onContentAccessRequest({response: response});
    return;
  }
  const headers = headerMap_(logSheet.getRange(1, 1, 1, LOG_HEADERS.length).getValues()[0]);
  const logged = requestFromLogRow_(
    logSheet.getRange(rowNumber, 1, 1, LOG_HEADERS.length).getValues()[0], headers
  );
  // A manual recovery is allowed one fresh bounded attempt after the
  // administrator has corrected the underlying configuration or policy.
  if (logged.accessStatus === 'FAILED') logged.accessAttempts = 0;
  if (logged.headshotStatus === 'FAILED') logged.headshotAttempts = 0;
  if (logged.adminEmailStatus !== 'SENT') logged.adminEmailAttempts = 0;
  if (logged.requesterEmailStatus !== 'SENT') logged.requesterEmailAttempts = 0;
  retryOne_(form, spreadsheet, logSheet, rowNumber, logged, settings);
}

/** Repairs missing Active/Archived working rows; raw responses are untouched. */
function repairRequestTracker() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const logSheet = ensureLogSheet_(spreadsheet);
  ensureTrackerSheets_(spreadsheet);
  const values = logSheet.getDataRange().getValues();
  if (values.length < 2) return;
  const headers = headerMap_(values[0]);
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    for (let index = 1; index < values.length; index += 1) {
      const request = requestFromLogRow_(values[index], headers);
      createInitialTrackerRow_(spreadsheet, request);
      updateTrackerFromRequest_(spreadsheet, request);
    }
  } finally {
    lock.releaseLock();
  }
}

/** Marks grants whose roster service end is within 14 days or has passed. */
function reviewExpiringAccess() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const active = ensureTrackerSheets_(spreadsheet).active;
  const values = active.getDataRange().getValues();
  if (values.length < 2) return 'No active access records.';
  const headers = headerMap_(values[0]);
  const now = new Date();
  const cutoff = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
  const due = [];
  for (let index = 1; index < values.length; index += 1) {
    const end = parseDate_(values[index][headers.authorization_service_end]);
    if (!end || end > cutoff) continue;
    const status = String(values[index][headers.workflow_status] || '');
    if (status !== 'Revocation approved') {
      active.getRange(index + 1, headers.workflow_status + 1).setValue('Review due');
    }
    const review = end < now ? 'OVERDUE' : 'DUE WITHIN 14 DAYS';
    active.getRange(index + 1, headers.access_review_status + 1).setValue(review);
    due.push(String(values[index][headers.request_id]));
  }
  const message = due.length ? 'Review: ' + due.join(', ') : 'No access is due within 14 days.';
  console.log(message);
  return message;
}

/**
 * Removes only a direct permission created by this automation.
 * Select its Active Requests row, set status to Revocation approved, then run.
 */
function revokeSelectedActiveAccess() {
  const settings = getSettings_();
  const form = FormApp.openById(settings.formId);
  const spreadsheet = SpreadsheetApp.openById(form.getDestinationId());
  const active = ensureTrackerSheets_(spreadsheet).active;
  const selected = spreadsheet.getActiveRange();
  if (!selected || selected.getSheet().getName() !== ACCESS_CONFIG.activeSheetName ||
      selected.getRow() < 2) {
    throw new Error('Select one data row in Active Requests first.');
  }
  const rowNumber = selected.getRow();
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
  const row = active.getRange(rowNumber, 1, 1, TRACKER_HEADERS.length).getValues()[0];
  const headers = headerMap_(TRACKER_HEADERS);
  if (String(row[headers.workflow_status]) !== 'Revocation approved') {
    throw new Error('Set workflow_status to Revocation approved before running this function.');
  }
  if (row[headers.permission_created_by_automation] !== true ||
      String(row[headers.permission_provenance]) !== 'AUTOMATION_CREATED_DIRECT') {
    active.getRange(rowNumber, headers.access_review_status + 1)
      .setValue('ADMIN ACTION REQUIRED - PREEXISTING OR INHERITED ACCESS');
    throw new Error('This permission was not created by the automation and was not deleted.');
  }
  const fileId = String(row[headers.spreadsheet_id]);
  const permissionId = String(row[headers.permission_id]);
  if (!fileId || !permissionId) throw new Error('Permission identifiers are missing.');
  const email = normalizeEmail_(row[headers.verified_email]);
  const allRows = active.getDataRange().getValues();
  for (let index = 1; index < allRows.length; index += 1) {
    if (index + 1 === rowNumber) continue;
    if (normalizeEmail_(allRows[index][headers.verified_email]) === email &&
        String(allRows[index][headers.spreadsheet_id]) === fileId) {
      throw new Error('Another active entitlement still requires this workbook; no permission was removed.');
    }
  }
  if (hasCurrentRosterEntitlement_(spreadsheet, email, fileId)) {
    throw new Error(
      'A current authorization-roster entry still requires this workbook. ' +
      'Deactivate every applicable roster row before revoking access.'
    );
  }
  const permission = Drive.Permissions.get(fileId, permissionId, {
    fields: 'id,emailAddress,type,role,permissionDetails(inherited,inheritedFrom)',
    supportsAllDrives: true
  });
  if (permission.type !== 'user' || normalizeEmail_(permission.emailAddress) !== email ||
      isInheritedPermission_(permission)) {
    throw new Error('The live permission no longer matches the recorded direct user permission; no permission was removed.');
  }
  Drive.Permissions.remove(fileId, permissionId, {supportsAllDrives: true});
  row[headers.access_status] = 'REVOKED';
  row[headers.workflow_status] = 'Revoked';
  row[headers.completed_at] = new Date();
  row[headers.archived_at] = new Date();
  row[headers.workflow_updated_at] = new Date();
  const archived = ensureTrackerSheets_(spreadsheet).archived;
  archived.appendRow(row);
  SpreadsheetApp.flush();
  active.deleteRow(rowNumber);
  const log = ensureLogSheet_(spreadsheet);
  const logValues = log.getDataRange().getValues();
  const logHeaders = headerMap_(logValues[0]);
  for (let index = 1; index < logValues.length; index += 1) {
    if (String(logValues[index][logHeaders.active_grant_request_id]) ===
        String(row[headers.request_id])) {
      updateLogCells_(log, index + 1, {
        access_status: 'REVOKED',
        updated_at: new Date()
      });
    }
  }
  } finally {
    lock.releaseLock();
  }
}

/** Archive Closed rows and restore rows explicitly marked Restore. */
function onAccessTrackerEdit(event) {
  if (!event || !event.range) throw new Error('This requires an edit trigger.');
  const sheet = event.range.getSheet();
  const name = sheet.getName();
  if (![ACCESS_CONFIG.activeSheetName, ACCESS_CONFIG.archivedSheetName].includes(name)) return;
  const statusColumn = TRACKER_HEADERS.indexOf('workflow_status') + 1;
  if (statusColumn < event.range.getColumn() ||
      statusColumn > event.range.getLastColumn()) return;
  const spreadsheet = sheet.getParent();
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    for (let row = event.range.getLastRow(); row >= Math.max(2, event.range.getRow()); row -= 1) {
      const status = String(sheet.getRange(row, statusColumn).getValue());
      if (name === ACCESS_CONFIG.activeSheetName && status === 'Closed (access retained)') {
        moveTrackerRow_(spreadsheet, sheet, row, 'Closed (access retained)');
      } else if (name === ACCESS_CONFIG.archivedSheetName && status === 'Restore') {
        moveTrackerRow_(spreadsheet, sheet, row, 'Pending');
      }
    }
  } finally {
    lock.releaseLock();
  }
}

function moveTrackerRow_(spreadsheet, source, rowNumber, status) {
  const sheets = ensureTrackerSheets_(spreadsheet);
  const destination = source.getName() === ACCESS_CONFIG.activeSheetName
    ? sheets.archived : sheets.active;
  const row = source.getRange(rowNumber, 1, 1, TRACKER_HEADERS.length).getValues()[0];
  const headers = headerMap_(TRACKER_HEADERS);
  const requestId = String(row[headers.request_id]);
  if (findTrackerByRequestId_(destination, requestId)) {
    throw new Error(requestId + ' already exists in ' + destination.getName() + '.');
  }
  if (destination === sheets.active) {
    const duplicateGrant = findActiveGrant_(
      spreadsheet,
      row[headers.verified_email],
      row[headers.spreadsheet_id],
      requestId
    );
    if (duplicateGrant) {
      throw new Error(
        'An Active Requests row already tracks this email and workbook (' +
        duplicateGrant.requestId + '); the archived row was not restored.'
      );
    }
  }
  row[headers.workflow_status] = status;
  row[headers.archived_at] = destination === sheets.archived ? new Date() : '';
  row[headers.completed_at] = destination === sheets.archived ? new Date() : '';
  row[headers.workflow_updated_at] = new Date();
  destination.appendRow(row);
  SpreadsheetApp.flush();
  source.deleteRow(rowNumber);
}

function createInitialTrackerRow_(spreadsheet, request) {
  const sheets = ensureTrackerSheets_(spreadsheet);
  if (request.authorizationStatus !== 'AUTHORIZED') {
    if (!findTrackerByRequestId_(sheets.archived, request.requestId)) {
      sheets.archived.appendRow(requestToTrackerRow_(request, 'Denied'));
    }
    return;
  }
  if (request.activeGrantRequestId &&
      findTrackerByRequestId_(sheets.archived, request.activeGrantRequestId)) {
    return;
  }
  const existing = findActiveGrant_(spreadsheet, request.verifiedEmail,
    request.area.spreadsheetId, request.requestId);
  if (existing) {
    request.activeGrantRequestId = existing.requestId;
    return;
  }
  if (!findTrackerByRequestId_(sheets.active, request.requestId) &&
      !findTrackerByRequestId_(sheets.archived, request.requestId)) {
    sheets.active.appendRow(requestToTrackerRow_(request, 'Pending'));
  }
}

function updateTrackerFromRequest_(spreadsheet, request) {
  const sheets = ensureTrackerSheets_(spreadsheet);
  const requestId = request.authorizationStatus === 'AUTHORIZED'
    ? request.activeGrantRequestId : request.requestId;
  const candidates = [sheets.active, sheets.archived];
  candidates.some(function(sheet) {
    const rowNumber = findTrackerByRequestId_(sheet, requestId);
    if (!rowNumber) return false;
    const headers = headerMap_(TRACKER_HEADERS);
    const updates = {
      access_status: request.accessStatus,
      permission_id: request.permissionId,
      permission_provenance: request.permissionProvenance,
      permission_created_by_automation: request.permissionCreatedByAutomation,
      authorization_service_end: request.authorizationServiceEnd,
      headshot_status: request.headshotStatus,
      headshot_stored_url: request.headshotStoredUrl,
      workflow_updated_at: new Date()
    };
    if (sheet === sheets.active && accessReady_(request)) updates.workflow_status = 'Access active';
    Object.keys(updates).forEach(function(key) {
      sheet.getRange(rowNumber, headers[key] + 1).setValue(updates[key]);
    });
    return true;
  });
}

function findActiveGrant_(spreadsheet, email, spreadsheetId, exceptRequestId) {
  const sheet = ensureTrackerSheets_(spreadsheet).active;
  if (sheet.getLastRow() < 2) return null;
  const values = sheet.getDataRange().getValues();
  const headers = headerMap_(values[0]);
  for (let index = 1; index < values.length; index += 1) {
    if (String(values[index][headers.request_id]) === String(exceptRequestId)) continue;
    if (normalizeEmail_(values[index][headers.verified_email]) !== normalizeEmail_(email)) continue;
    if (String(values[index][headers.spreadsheet_id]) !== String(spreadsheetId)) continue;
    return {
      requestId: String(values[index][headers.request_id]),
      permissionId: String(values[index][headers.permission_id] || ''),
      permissionProvenance: String(values[index][headers.permission_provenance] || ''),
      permissionCreatedByAutomation:
        values[index][headers.permission_created_by_automation] === true
    };
  }
  return null;
}

function hasCurrentRosterEntitlement_(spreadsheet, email, spreadsheetId) {
  const roster = ensureRosterSheet_(spreadsheet);
  validateRosterRows_(roster);
  const values = roster.getDataRange().getValues();
  if (values.length < 2) return false;
  const headers = headerMap_(values[0]);
  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    const key = String(row[headers.content_area_key] || '').trim();
    const area = Object.prototype.hasOwnProperty.call(CONTENT_AREAS, key)
      ? CONTENT_AREAS[key] : null;
    if (normalizeEmail_(row[headers.email]) === normalizeEmail_(email) &&
        area && String(area.spreadsheetId) === String(spreadsheetId) &&
        isRosterActive_(row[headers.active]) &&
        validServiceEnd_(row[headers.service_end_date])) {
      return true;
    }
  }
  return false;
}

function requestToTrackerRow_(request, workflowStatus) {
  const area = request.area || {};
  const values = {
    request_id: request.requestId,
    submitted_at: request.submittedAt,
    name: request.name,
    verified_email: request.verifiedEmail,
    role: request.role,
    content_area_key: request.contentAreaKey,
    content_area_label: request.contentAreaLabel,
    spreadsheet_id: area.spreadsheetId || '',
    tab_name: area.tabName || '',
    access_status: request.accessStatus,
    permission_id: request.permissionId,
    permission_provenance: request.permissionProvenance,
    permission_created_by_automation: request.permissionCreatedByAutomation,
    authorization_service_end: request.authorizationServiceEnd,
    requested_end_date: request.requestedEndDate,
    headshot_status: request.headshotStatus,
    headshot_stored_url: request.headshotStoredUrl,
    workflow_status: workflowStatus,
    access_review_status: '',
    completed_at: workflowStatus === 'Denied' ? new Date() : '',
    archived_at: workflowStatus === 'Denied' ? new Date() : '',
    workflow_updated_at: new Date()
  };
  return TRACKER_HEADERS.map(function(header) { return values[header] || ''; });
}

function appendLogRequest_(sheet, request) {
  sheet.appendRow(requestToLogRow_(request));
  SpreadsheetApp.flush();
  return sheet.getLastRow();
}

function updateLogFromRequest_(sheet, rowNumber, request) {
  const row = requestToLogRow_(request);
  sheet.getRange(rowNumber, 1, 1, LOG_HEADERS.length).setValues([row]);
}

function requestToLogRow_(request) {
  const area = request.area || {};
  const values = {
    response_id: request.responseId,
    request_id: request.requestId,
    active_grant_request_id: request.activeGrantRequestId,
    submitted_at: request.submittedAt,
    name: request.name,
    verified_email: request.verifiedEmail,
    role: request.role,
    content_area_key: request.contentAreaKey,
    content_area_label: request.contentAreaLabel,
    purpose: request.purpose,
    requested_end_date: request.requestedEndDate,
    existing_access: request.existingAccess,
    acknowledgements: request.acknowledgements,
    authorization_status: request.authorizationStatus,
    authorization_service_end: request.authorizationServiceEnd,
    spreadsheet_id: area.spreadsheetId || '',
    tab_name: area.tabName || '',
    tab_gid: area.tabGid || '',
    access_status: request.accessStatus,
    access_attempts: request.accessAttempts,
    access_last_error: request.accessLastError,
    permission_id: request.permissionId,
    permission_role: request.permissionRole,
    permission_provenance: request.permissionProvenance,
    permission_created_by_automation: request.permissionCreatedByAutomation,
    headshot_original_id: request.headshotOriginalId,
    headshot_stored_name: request.headshotStoredName,
    headshot_stored_file_id: request.headshotStoredFileId,
    headshot_stored_url: request.headshotStoredUrl,
    headshot_status: request.headshotStatus,
    headshot_attempts: request.headshotAttempts,
    headshot_last_error: request.headshotLastError,
    admin_email_status: request.adminEmailStatus,
    admin_email_attempts: request.adminEmailAttempts,
    admin_email_last_error: request.adminEmailLastError,
    requester_email_status: request.requesterEmailStatus,
    requester_email_attempts: request.requesterEmailAttempts,
    requester_email_last_error: request.requesterEmailLastError,
    updated_at: new Date()
  };
  return LOG_HEADERS.map(function(header) {
    return Object.prototype.hasOwnProperty.call(values, header) ? values[header] : '';
  });
}

function requestFromLogRow_(row, headers) {
  const value = function(name) { return row[headers[name]]; };
  const key = String(value('content_area_key') || '');
  return {
    responseId: String(value('response_id') || ''),
    requestId: String(value('request_id') || ''),
    activeGrantRequestId: String(value('active_grant_request_id') || ''),
    submittedAt: value('submitted_at'),
    name: String(value('name') || ''),
    verifiedEmail: normalizeEmail_(value('verified_email')),
    role: String(value('role') || ''),
    contentAreaKey: key,
    contentAreaLabel: String(value('content_area_label') || ''),
    area: Object.prototype.hasOwnProperty.call(CONTENT_AREAS, key) ? CONTENT_AREAS[key] : null,
    purpose: String(value('purpose') || ''),
    requestedEndDate: value('requested_end_date'),
    existingAccess: String(value('existing_access') || ''),
    acknowledgements: String(value('acknowledgements') || ''),
    authorizationStatus: String(value('authorization_status') || ''),
    authorizationServiceEnd: value('authorization_service_end'),
    accessStatus: String(value('access_status') || ''),
    accessAttempts: Number(value('access_attempts') || 0),
    accessLastError: String(value('access_last_error') || ''),
    permissionId: String(value('permission_id') || ''),
    permissionRole: String(value('permission_role') || ''),
    permissionProvenance: String(value('permission_provenance') || ''),
    permissionCreatedByAutomation: value('permission_created_by_automation') === true,
    headshotIds: String(value('headshot_original_id') || '').split('\n').filter(Boolean),
    headshotOriginalId: String(value('headshot_original_id') || ''),
    headshotStoredName: String(value('headshot_stored_name') || ''),
    headshotStoredFileId: String(value('headshot_stored_file_id') || ''),
    headshotStoredUrl: String(value('headshot_stored_url') || ''),
    headshotStatus: String(value('headshot_status') || ''),
    headshotAttempts: Number(value('headshot_attempts') || 0),
    headshotLastError: String(value('headshot_last_error') || ''),
    adminEmailStatus: String(value('admin_email_status') || ''),
    adminEmailAttempts: Number(value('admin_email_attempts') || 0),
    adminEmailLastError: String(value('admin_email_last_error') || ''),
    requesterEmailStatus: String(value('requester_email_status') || ''),
    requesterEmailAttempts: Number(value('requester_email_attempts') || 0),
    requesterEmailLastError: String(value('requester_email_last_error') || '')
  };
}

function restoreOperationalState_(request, logged) {
  Object.keys(logged).forEach(function(key) {
    if (!['verifiedEmail', 'role', 'contentAreaKey', 'contentAreaLabel', 'area',
      'purpose', 'requestedEndDate', 'existingAccess', 'acknowledgements',
      'headshotIds', 'headshotOriginalId', 'submittedAt', 'name'].includes(key)) {
      request[key] = logged[key];
    }
  });
  request.responseId = logged.responseId;
  request.requestId = logged.requestId;
  request.activeGrantRequestId = logged.activeGrantRequestId || logged.requestId;
}

function getSettings_() {
  const properties = PropertiesService.getScriptProperties();
  const settings = {
    formId: properties.getProperty(ACCESS_CONFIG.properties.formId),
    administratorEmail: normalizeEmail_(
      properties.getProperty(ACCESS_CONFIG.properties.administratorEmail)
    ),
    headshotFolderId: properties.getProperty(ACCESS_CONFIG.properties.headshotFolderId)
  };
  const missing = [];
  if (!settings.formId) missing.push('FORM_ID');
  if (!settings.administratorEmail) missing.push('ADMIN_EMAIL');
  if (!settings.headshotFolderId) missing.push('HEADSHOT_FOLDER_ID');
  if (missing.length) throw new Error('Missing Script Properties: ' + missing.join(', '));
  if (!isValidEmail_(settings.administratorEmail)) throw new Error('ADMIN_EMAIL is invalid.');
  return settings;
}

function validateRegistry_() {
  const labels = {};
  Object.keys(CONTENT_AREAS).forEach(function(key) {
    const area = CONTENT_AREAS[key];
    const required = ['label', 'spreadsheetId', 'tabName', 'tabGid', 'updateCommand'];
    required.forEach(function(field) {
      if (!area[field]) throw new Error(key + ' is missing ' + field + '.');
      if (/REPLACE_WITH_/.test(String(area[field]))) {
        throw new Error(key + ' still contains a required placeholder in ' + field + '.');
      }
    });
    if (!/^\d+$/.test(String(area.tabGid))) throw new Error(key + ' tabGid must be numeric.');
    if (labels[area.label]) throw new Error('Duplicate content-area label: ' + area.label);
    labels[area.label] = true;
    if (!area.generatedFiles.length || !area.validationInstructions.length ||
        !area.renderTargets.length) throw new Error(key + ' has incomplete local instructions.');
    area.allowedRoles.forEach(function(role) {
      if (!ACCESS_CONFIG.eligibleRoles.includes(role)) {
        throw new Error(key + ' allows an ineligible role: ' + role);
      }
    });
  });
}

function validateFormQuestions_(form) {
  const byTitle = {};
  form.getItems().forEach(function(item) {
    const title = String(item.getTitle() || '').trim();
    if (byTitle[title]) throw new Error('Duplicate Form question title: ' + title);
    byTitle[title] = item;
  });
  Object.keys(ACCESS_CONFIG.questions).forEach(function(key) {
    const title = ACCESS_CONFIG.questions[key];
    if (!byTitle[title]) throw new Error('The Form is missing: ' + title);
  });
  if (byTitle[ACCESS_CONFIG.questions.headshot].getType() !== FormApp.ItemType.FILE_UPLOAD) {
    throw new Error('The headshot question must be a file-upload item.');
  }
  validateChoiceItem_(byTitle[ACCESS_CONFIG.questions.role], ACCESS_CONFIG.allRoleChoices);
  validateChoiceItem_(byTitle[ACCESS_CONFIG.questions.contentArea], contentAreaLabels_());
  validateChoiceItem_(byTitle[ACCESS_CONFIG.questions.existingAccess], ['Yes', 'No', 'Not sure']);
  const acknowledgements = byTitle[ACCESS_CONFIG.questions.acknowledgements];
  if (acknowledgements.getType() !== FormApp.ItemType.CHECKBOX) {
    throw new Error('Acknowledgements must be a checkbox item.');
  }
  const actualAcknowledgements = acknowledgements.asCheckboxItem().getChoices()
    .map(function(choice) { return choice.getValue(); }).sort();
  if (actualAcknowledgements.join('|') !==
      ACCESS_CONFIG.acknowledgementChoices.slice().sort().join('|')) {
    throw new Error('Acknowledgement choices do not exactly match the documented list.');
  }
}

function validateChoiceItem_(item, expected) {
  let choices;
  if (item.getType() === FormApp.ItemType.MULTIPLE_CHOICE) {
    choices = item.asMultipleChoiceItem().getChoices();
  } else if (item.getType() === FormApp.ItemType.LIST) {
    choices = item.asListItem().getChoices();
  } else {
    throw new Error(item.getTitle() + ' must be multiple choice or dropdown.');
  }
  const actual = choices.map(function(choice) { return choice.getValue(); }).sort();
  const wanted = expected.slice().sort();
  if (actual.join('|') !== wanted.join('|')) {
    throw new Error(item.getTitle() + ' choices do not exactly match the documented list.');
  }
}

function validateHeadshotFolder_(folderId) {
  const file = Drive.Files.get(folderId, {
    fields: 'id,mimeType,trashed', supportsAllDrives: true
  });
  if (file.trashed || file.mimeType !== 'application/vnd.google-apps.folder') {
    throw new Error('HEADSHOT_FOLDER_ID must identify an accessible Google Drive folder.');
  }
}

function ensureRosterSheet_(spreadsheet) {
  let sheet = spreadsheet.getSheetByName(ACCESS_CONFIG.rosterSheetName);
  if (!sheet) sheet = spreadsheet.insertSheet(ACCESS_CONFIG.rosterSheetName);
  ensureExactHeaders_(sheet, ROSTER_HEADERS);
  if (sheet.getMaxRows() < 2) sheet.insertRowAfter(1);
  sheet.getRange(2, 4, sheet.getMaxRows() - 1, 1)
    .setDataValidation(SpreadsheetApp.newDataValidation().requireCheckbox().build());
  let protection = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET)[0];
  if (!protection) protection = sheet.protect();
  protection.setDescription('Administrator-only authorization roster');
  protection.setWarningOnly(false);
  if (protection.canDomainEdit()) protection.setDomainEdit(false);
  const effectiveEmail = normalizeEmail_(Session.getEffectiveUser().getEmail());
  const otherEditors = protection.getEditors().filter(function(user) {
    return normalizeEmail_(user.getEmail()) !== effectiveEmail;
  });
  if (otherEditors.length) protection.removeEditors(otherEditors);
  if (effectiveEmail) protection.addEditor(effectiveEmail);
  sheet.getRange(2, 2, sheet.getMaxRows() - 1, 1)
    .setDataValidation(SpreadsheetApp.newDataValidation()
      .requireValueInList(ACCESS_CONFIG.eligibleRoles, true)
      .setAllowInvalid(false).build());
  sheet.getRange(2, 3, sheet.getMaxRows() - 1, 1)
    .setDataValidation(SpreadsheetApp.newDataValidation()
      .requireValueInList(Object.keys(CONTENT_AREAS), true)
      .setAllowInvalid(false).build());
  sheet.getRange(2, 5, sheet.getMaxRows() - 1, 1)
    .setDataValidation(SpreadsheetApp.newDataValidation().requireDate()
      .setAllowInvalid(false).build());
  return sheet;
}

function validateRosterRows_(sheet) {
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return;
  const headers = headerMap_(values[0]);
  const seen = {};
  for (let index = 1; index < values.length; index += 1) {
    const row = values[index];
    if (row.every(function(value) { return value === ''; })) continue;
    const email = normalizeEmail_(row[headers.email]);
    const role = String(row[headers.role] || '').trim();
    const key = String(row[headers.content_area_key] || '').trim();
    if (!isValidEmail_(email)) throw new Error('Roster row ' + (index + 1) + ' has an invalid email.');
    if (!ACCESS_CONFIG.eligibleRoles.includes(role)) throw new Error('Roster row ' + (index + 1) + ' has an invalid role.');
    if (!Object.prototype.hasOwnProperty.call(CONTENT_AREAS, key)) throw new Error('Roster row ' + (index + 1) + ' has an invalid content_area_key.');
    if (isRosterActive_(row[headers.active]) && !validServiceEnd_(row[headers.service_end_date])) {
      throw new Error('Active roster row ' + (index + 1) + ' needs a current service_end_date.');
    }
    const identity = [email, role, key].join('|');
    if (seen[identity]) throw new Error('Duplicate roster scope at row ' + (index + 1) + '.');
    seen[identity] = true;
  }
}

function ensureLogSheet_(spreadsheet) {
  let sheet = spreadsheet.getSheetByName(ACCESS_CONFIG.logSheetName);
  if (!sheet) sheet = spreadsheet.insertSheet(ACCESS_CONFIG.logSheetName);
  ensureExactHeaders_(sheet, LOG_HEADERS);
  return sheet;
}

function ensureTrackerSheets_(spreadsheet) {
  return {
    active: ensureTrackerSheet_(spreadsheet, ACCESS_CONFIG.activeSheetName, ACTIVE_STATUSES),
    archived: ensureTrackerSheet_(spreadsheet, ACCESS_CONFIG.archivedSheetName, ARCHIVED_STATUSES)
  };
}

function ensureTrackerSheet_(spreadsheet, name, statuses) {
  let sheet = spreadsheet.getSheetByName(name);
  if (!sheet) sheet = spreadsheet.insertSheet(name);
  ensureExactHeaders_(sheet, TRACKER_HEADERS);
  if (sheet.getMaxRows() < 2) sheet.insertRowAfter(1);
  const statusColumn = TRACKER_HEADERS.indexOf('workflow_status') + 1;
  sheet.getRange(2, statusColumn, sheet.getMaxRows() - 1, 1).setDataValidation(
    SpreadsheetApp.newDataValidation().requireValueInList(statuses, true)
      .setAllowInvalid(false).build()
  );
  return sheet;
}

function ensureExactHeaders_(sheet, expected) {
  const range = sheet.getRange(1, 1, 1, expected.length);
  const current = range.getValues()[0];
  if (current.every(function(value) { return value === ''; })) {
    range.setValues([expected]);
    range.setBackground('#263238').setFontColor('#ffffff').setFontWeight('bold');
    sheet.setFrozenRows(1);
  } else if (current.join('|') !== expected.join('|')) {
    throw new Error(sheet.getName() + ' headers do not match the required schema.');
  }
  if (sheet.getLastColumn() > expected.length) {
    const extras = sheet.getRange(
      1, expected.length + 1, 1, sheet.getLastColumn() - expected.length
    ).getValues()[0].filter(function(value) { return String(value).trim() !== ''; });
    if (extras.length) {
      throw new Error(sheet.getName() + ' has unexpected header columns.');
    }
  }
}

function ensureFormTrigger_(form) {
  if (!ScriptApp.getProjectTriggers().some(function(trigger) {
    return trigger.getHandlerFunction() === ACCESS_CONFIG.submitHandlerName;
  })) ScriptApp.newTrigger(ACCESS_CONFIG.submitHandlerName).forForm(form).onFormSubmit().create();
}

function ensureEditTrigger_(spreadsheet) {
  if (!ScriptApp.getProjectTriggers().some(function(trigger) {
    return trigger.getHandlerFunction() === ACCESS_CONFIG.editHandlerName &&
      trigger.getTriggerSourceId() === spreadsheet.getId();
  })) ScriptApp.newTrigger(ACCESS_CONFIG.editHandlerName).forSpreadsheet(spreadsheet).onEdit().create();
}

function ensureRetryTrigger_() {
  if (!ScriptApp.getProjectTriggers().some(function(trigger) {
    return trigger.getHandlerFunction() === ACCESS_CONFIG.retryHandlerName;
  })) ScriptApp.newTrigger(ACCESS_CONFIG.retryHandlerName).timeBased().everyHours(1).create();
}

function nextRequestIdWithoutLock_() {
  const date = Utilities.formatDate(new Date(), 'America/Chicago', 'yyyyMMdd');
  const key = 'ACCESS_SEQUENCE_' + date;
  const properties = PropertiesService.getScriptProperties();
  const sequence = Number(properties.getProperty(key) || 0) + 1;
  properties.setProperty(key, String(sequence));
  return 'ACCESS-' + date + '-' + String(sequence).padStart(3, '0');
}

function findRow_(sheet, header, value) {
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return 0;
  const headers = headerMap_(values[0]);
  for (let index = 1; index < values.length; index += 1) {
    if (String(values[index][headers[header]]) === String(value)) return index + 1;
  }
  return 0;
}

function findTrackerByRequestId_(sheet, requestId) {
  return findRow_(sheet, 'request_id', requestId);
}

function updateLogCells_(sheet, rowNumber, updates) {
  const headers = headerMap_(LOG_HEADERS);
  Object.keys(updates).forEach(function(key) {
    sheet.getRange(rowNumber, headers[key] + 1).setValue(updates[key]);
  });
}

function headerMap_(headers) {
  return headers.reduce(function(result, header, index) {
    result[String(header)] = index;
    return result;
  }, {});
}

function contentAreaByLabel_(label) {
  const keys = Object.keys(CONTENT_AREAS);
  for (let index = 0; index < keys.length; index += 1) {
    const area = CONTENT_AREAS[keys[index]];
    if (area.enabled && area.label === String(label || '').trim()) {
      return {key: keys[index], area: area};
    }
  }
  return null;
}

function contentAreaLabels_() {
  return Object.keys(CONTENT_AREAS).filter(function(key) {
    return CONTENT_AREAS[key].enabled;
  }).map(function(key) { return CONTENT_AREAS[key].label; });
}

function validServiceEnd_(value) {
  const date = parseDate_(value);
  if (!date) return null;
  const end = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 999);
  return end >= new Date() ? end : null;
}

function parseDate_(value) {
  if (value instanceof Date && !isNaN(value.getTime())) return value;
  if (!value) return null;
  const text = String(value).trim();
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
  return isNaN(date.getTime()) ? null : date;
}

function isRosterActive_(value) {
  return value === true || String(value).trim().toUpperCase() === 'TRUE';
}

function answer_(answers, title) {
  return Object.prototype.hasOwnProperty.call(answers, title)
    ? String(answers[title] || '').trim() : '';
}

function normalizeEmail_(value) {
  return String(value || '').trim().toLowerCase();
}

function isValidEmail_(value) {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(value || ''));
}

function requesterSheetUrl_(area) {
  return 'https://docs.google.com/spreadsheets/d/' + area.spreadsheetId +
    '/edit#gid=' + area.tabGid;
}

function administratorSheetUrl_(area) {
  return requesterSheetUrl_(area) + ' (' + area.tabName + ')';
}

function driveOpenUrl_(fileId) {
  return 'https://drive.google.com/open?id=' + fileId;
}

function sanitizeFilename_(value) {
  const safe = String(value || 'headshot')
    .normalize('NFKD').replace(/[^A-Za-z0-9._-]+/g, '_')
    .replace(/^[_\.]+|[_\.]+$/g, '').slice(0, 100);
  return safe || 'headshot';
}

function displayValue_(value) {
  if (value instanceof Date) {
    return Utilities.formatDate(value, 'America/Chicago', 'yyyy-MM-dd');
  }
  return value === true ? 'Yes' : (value === false ? 'No' : String(value || '—'));
}

function escapeHtml_(value) {
  return String(value).replace(/[&<>'"]/g, function(character) {
    return {'&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'}[character];
  });
}

function linkify_(value) {
  return escapeHtml_(value).replace(
    /(https?:\/\/[^\s<]+)/g, '<a href="$1">$1</a>'
  ).replace(/\n/g, '<br>');
}
