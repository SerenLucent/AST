function emptyRankings() {
  return { schemaVersion: 2, game: 'timing-shooter', timeZone: 'Asia/Seoul', updatedAt: null,
    stages: { stage1: emptyStage('stage1'), stage2: emptyStage('stage2') } };
}

function rankingStage(value) {
  const id = value == null || value === '' ? 'stage1' : String(value);
  if (id !== 'stage1' && id !== 'stage2') throw new Error('Invalid stage');
  return id;
}

function emptyStage(stageId) {
  return { stageId: stageId, weekStart: weekStart(new Date()), updatedAt: null, allTime: [], weekly: [], receipts: [] };
}

function normalizeRankings(data) {
  if (!data || data.game !== 'timing-shooter') throw new Error('Invalid ranking file');
  if (data.schemaVersion === 1) {
    if (!Array.isArray(data.allTime) || !Array.isArray(data.weekly) || !Array.isArray(data.receipts)) throw new Error('Invalid ranking file');
    const migrated = emptyRankings();
    migrated.updatedAt = data.updatedAt;
    const board = migrated.stages.stage1;
    board.weekStart = data.weekStart;
    board.updatedAt = data.updatedAt;
    ['allTime', 'weekly', 'receipts'].forEach(key => {
      board[key] = data[key].map(entry => Object.assign({}, entry, { stageId: 'stage1' }));
    });
    return migrated;
  }
  if (data.schemaVersion !== 2 || !data.stages || typeof data.stages !== 'object' || Array.isArray(data.stages)) throw new Error('Invalid ranking file');
  ['stage1', 'stage2'].forEach(id => {
    const board = data.stages[id];
    if (!board || board.stageId !== id || !Array.isArray(board.allTime) || !Array.isArray(board.weekly)
        || !Array.isArray(board.receipts)) throw new Error('Invalid stage ranking');
  });
  return data;
}

function weekStart(date) {
  const kst = new Date(date.getTime() + 9 * 3600000);
  return new Date(Date.UTC(kst.getUTCFullYear(), kst.getUTCMonth(), kst.getUTCDate() - (kst.getUTCDay() + 6) % 7) - 9 * 3600000).toISOString();
}

function rollWeek(data, date) {
  const start = weekStart(date);
  let changed = false;
  Object.keys(data.stages).forEach(id => {
    const board = data.stages[id];
    if (board.weekStart !== start) {
      board.weekStart = start;
      board.weekly = [];
      changed = true;
    }
  });
  return changed;
}

function qualifies(entries, score) {
  return entries.length < 10 || score > entries[entries.length - 1].score;
}

function publicData(data, score, stageId) {
  const board = data.stages[stageId];
  return { ok: true, schemaVersion: 2, stageId: stageId, weekStart: board.weekStart, allTime: board.allTime, weekly: board.weekly,
    qualifies: { allTime: qualifies(board.allTime, score), weekly: qualifies(board.weekly, score) } };
}

function receiptFor(data, runId) {
  const receipt = data.receipts.find(entry => entry.runId === runId);
  if (receipt) return receipt;
  if (data.allTime.concat(data.weekly).some(entry => entry.runId === runId)) return { runId: runId, stageId: data.stageId, accepted: true };
  return null;
}

function doGet(e) {
  const parameters = e && e.parameter || {};
  try {
    const settings = getSettings();
    const stageId = rankingStage(parameters.stageId);
    const current = readRankings(settings);
    rollWeek(current.data, new Date());
    const action = parameters.action || 'leaderboard';
    if (action !== 'leaderboard' && action !== 'status') throw new Error('Invalid action');
    const value = publicData(current.data, Number(parameters.score) || 0, stageId);
    if (action === 'status') value.receipt = receiptFor(current.data.stages[stageId], String(parameters.runId || ''));
    return respond(value, parameters.callback);
  } catch (error) { return respond({ ok: false, error: String(error.message || error) }, parameters.callback); }
}

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    const raw = e && e.postData && e.postData.contents || '';
    if (raw.length > 4096) throw new Error('Request too large');
    const request = JSON.parse(raw);
    if (request.action !== 'submit') throw new Error('Invalid action');
    const result = validateResult(request.result);
    const name = String(request.name || '').trim().replace(/\s+/g, ' ');
    if (!name || Array.from(name).length > 20 || /[<>\u0000-\u001f\u007f]/.test(name)) throw new Error('Invalid name');
    const settings = getSettings();
    lock.waitLock(30000);
    for (let attempt = 0; attempt < 3; attempt++) {
      const current = readRankings(settings);
      const data = current.data;
      rollWeek(data, new Date());
      const board = data.stages[result.stageId];
      const existing = receiptFor(board, result.runId);
      if (existing) return respond({ ok: true, duplicate: true, receipt: existing });
      const now = new Date().toISOString();
      const entry = { runId: result.runId, stageId: result.stageId, name: name, score: result.totalScore, savedAt: now };
      const allTime = qualifies(board.allTime, entry.score);
      const weekly = qualifies(board.weekly, entry.score);
      if (allTime) board.allTime = insertEntry(board.allTime, entry);
      if (weekly) board.weekly = insertEntry(board.weekly, entry);
      const receipt = { runId: entry.runId, stageId: result.stageId, accepted: allTime || weekly, allTime: allTime, weekly: weekly };
      board.receipts = [receipt].concat(board.receipts).slice(0, 200);
      board.updatedAt = now;
      data.updatedAt = now;
      const status = writeRankings(settings, current, 'Update timing shooter ' + result.stageId + ' TOP 10');
      if (status === 200 || status === 201) return respond({ ok: true, receipt: receipt });
      if (status !== 409 && status !== 422) throw new Error('Ranking storage failed (' + status + ')');
    }
    throw new Error('Ranking changed; please retry');
  } catch (error) { return respond({ ok: false, error: String(error.message || error) }); }
  finally { if (lock.hasLock()) lock.releaseLock(); }
}

function insertEntry(entries, entry) {
  // Append before stable sort: equal scores keep the earlier registered record first.
  return entries.concat([entry]).sort((a, b) => b.score - a.score).slice(0, 10);
}

function validateResult(value) {
  if (!value || typeof value.runId !== 'string' || !/^[A-Za-z0-9-]{10,80}$/.test(value.runId)) throw new Error('Invalid run');
  for (const field of ['shootScore', 'remainingHp', 'hpScore', 'totalScore']) {
    if (!Number.isSafeInteger(value[field]) || value[field] < 0 || value[field] > 1000000) throw new Error('Invalid score');
  }
  if (value.remainingHp > 100 || value.hpScore !== value.remainingHp * 100 || value.totalScore !== value.shootScore + value.hpScore) throw new Error('Score does not match');
  return Object.assign({}, value, { stageId: rankingStage(value.stageId) });
}

function getSettings() {
  const props = PropertiesService.getScriptProperties();
  const settings = { token: props.getProperty('GITHUB_TOKEN'), owner: props.getProperty('GITHUB_OWNER') || 'SerenLucent',
    repo: props.getProperty('GITHUB_REPO') || 'Games', branch: props.getProperty('GITHUB_BRANCH') || 'main',
    path: props.getProperty('SCORE_PATH') || 'timing-shooter/rankings.json' };
  if (!settings.token) throw new Error('Ranking server is not configured');
  return settings;
}

function fileUrl(settings) {
  return 'https://api.github.com/repos/' + encodeURIComponent(settings.owner) + '/' + encodeURIComponent(settings.repo)
    + '/contents/' + settings.path.split('/').map(encodeURIComponent).join('/');
}

function headers(settings) {
  return { Authorization: 'Bearer ' + settings.token, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' };
}

function readRankings(settings) {
  const response = UrlFetchApp.fetch(fileUrl(settings) + '?ref=' + encodeURIComponent(settings.branch),
    { headers: headers(settings), muteHttpExceptions: true });
  if (response.getResponseCode() === 404) return { sha: null, data: emptyRankings() };
  if (response.getResponseCode() !== 200) throw new Error('Cannot read rankings');
  const body = JSON.parse(response.getContentText());
  const data = JSON.parse(Utilities.newBlob(Utilities.base64Decode(body.content.replace(/\s/g, ''))).getDataAsString('UTF-8'));
  const migrated = data.schemaVersion === 1;
  return { sha: body.sha, data: normalizeRankings(data), migrated: migrated };
}

function writeRankings(settings, current, message) {
  const payload = { branch: settings.branch, message: message,
    content: Utilities.base64Encode(JSON.stringify(current.data, null, 2), Utilities.Charset.UTF_8) };
  if (current.sha) payload.sha = current.sha;
  const response = UrlFetchApp.fetch(fileUrl(settings), { method: 'put', headers: headers(settings),
    contentType: 'application/json', muteHttpExceptions: true, payload: JSON.stringify(payload) });
  return response.getResponseCode();
}

function resetWeeklyRankings() {
  const settings = getSettings(), lock = LockService.getScriptLock();
  try {
    lock.waitLock(30000);
    for (let attempt = 0; attempt < 3; attempt++) {
      const current = readRankings(settings);
      if (!rollWeek(current.data, new Date()) && current.sha && !current.migrated) return;
      current.data.updatedAt = new Date().toISOString();
      const status = writeRankings(settings, current, 'Initialize or reset public weekly TOP 10');
      if (status === 200 || status === 201) return;
      if (status !== 409 && status !== 422) throw new Error('Weekly reset failed');
    }
    throw new Error('Weekly reset conflict');
  } finally { if (lock.hasLock()) lock.releaseLock(); }
}

// Run once after deploying v2. Read the latest GitHub revision under lock; never upload an old snapshot.
function migrateStageRankings() {
  const settings = getSettings(), lock = LockService.getScriptLock();
  try {
    lock.waitLock(30000);
    for (let attempt = 0; attempt < 3; attempt++) {
      const current = readRankings(settings);
      if (!current.migrated && current.sha) return;
      const status = writeRankings(settings, current, 'Migrate existing rankings to stage1; initialize stage2');
      if (status === 200 || status === 201) return;
      if (status !== 409 && status !== 422) throw new Error('Stage ranking migration failed');
    }
    throw new Error('Stage ranking migration conflict');
  } finally { if (lock.hasLock()) lock.releaseLock(); }
}

function installWeeklyResetTrigger() {
  ScriptApp.getProjectTriggers().forEach(trigger => {
    if (trigger.getHandlerFunction() === 'resetWeeklyRankings') ScriptApp.deleteTrigger(trigger);
  });
  ScriptApp.newTrigger('resetWeeklyRankings').timeBased().everyWeeks(1)
    .onWeekDay(ScriptApp.WeekDay.MONDAY).atHour(0).nearMinute(15).inTimezone('Asia/Seoul').create();
}

function respond(value, callback) {
  const json = JSON.stringify(value).replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
  if (callback && /^publicRanking_[a-f0-9]{32}$/.test(callback)) {
    return ContentService.createTextOutput(callback + '(' + json + ');').setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(json).setMimeType(ContentService.MimeType.JSON);
}
