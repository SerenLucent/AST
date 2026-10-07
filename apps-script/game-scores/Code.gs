const OWNER = 'SerenLucent';
const REPO = 'AST';
const BRANCH = 'main';
const SCORE_PATH = 'remote-data/games/timing-shooter/scores.json';

function doGet() { return respond({ ok: true, service: 'AST game scores' }); }

function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    const props = PropertiesService.getScriptProperties();
    const key = props.getProperty('APP_KEY');
    const token = props.getProperty('GITHUB_TOKEN');
    if (!key || !token) throw new Error('Score server is not configured');
    const request = JSON.parse(e.postData.contents || '{}');
    if (request.appKey !== key) throw new Error('Unauthorized');
    const result = validateResult(request.result);
    const loginId = String(request.loginId || '').trim().toLowerCase();
    if (!loginId || loginId.length > 100) throw new Error('Invalid player');
    lock.waitLock(30000);
    const users = readFile(token, 'remote-data/users.json').data.users || [];
    const user = users.find(function (entry) { return String(entry.loginId).toLowerCase() === loginId; });
    if (!user) throw new Error('Player is not registered');
    // Store an opaque ID instead of exposing the app login ID in the leaderboard.
    const playerKey = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, loginId)
      .map(function (value) { return ('0' + ((value + 256) % 256).toString(16)).slice(-2); }).join('');
    for (let attempt = 0; attempt < 3; attempt++) {
      const current = readFile(token, SCORE_PATH);
      const data = current.data;
      validateScoreFile(data);
      rollWeek(data, new Date());
      let player = data.players.find(function (entry) { return entry.playerKey === playerKey; });
      if (player && (player.recentRunIds || []).includes(result.runId)) return respond({ ok: true, duplicate: true });
      const now = new Date().toISOString();
      if (!player) {
        player = { playerKey: playerKey, bestScore: 0, clears: 0, recentRunIds: [] };
        data.players.push(player);
      }
      player.nickname = String(user.nickname || 'Player').slice(0, 40);
      player.bestScore = Math.max(player.bestScore || 0, result.totalScore);
      player.lastResult = Object.assign({}, result, { savedAt: now });
      player.clears = (player.clears || 0) + 1;
      player.recentRunIds = [result.runId].concat(player.recentRunIds || []).slice(0, 50);
      data.updatedAt = now;
      data.players.sort(function (a, b) { return b.bestScore - a.bestScore; });
      const status = writeScores(token, current, 'Update timing shooter weekly score');
      if (status === 200 || status === 201) return respond({ ok: true, bestScore: player.bestScore });
      if (status !== 409 && status !== 422) throw new Error('GitHub score update failed (' + status + ')');
    }
    throw new Error('Score update conflict; retry');
  } catch (error) {
    return respond({ ok: false, error: String(error.message || error) });
  } finally { if (lock.hasLock()) lock.releaseLock(); }
}

// KST has no daylight-saving changes; derive Monday 00:00 without host timezone dependence.
function weekStart(date) {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const monday = Date.UTC(kst.getUTCFullYear(), kst.getUTCMonth(), kst.getUTCDate() - (kst.getUTCDay() + 6) % 7);
  return new Date(monday - 9 * 60 * 60 * 1000).toISOString();
}

function validateScoreFile(data) {
  if (data.schemaVersion !== 1 || data.game !== 'timing-shooter' || !Array.isArray(data.players)) throw new Error('Invalid score file');
}

function rollWeek(data, date) {
  const start = weekStart(date);
  if (data.weekStart === start) return false;
  data.weekStart = start;
  data.timeZone = 'Asia/Seoul';
  data.players = [];
  data.updatedAt = date.toISOString();
  return true;
}

function writeScores(token, current, message) {
  const response = UrlFetchApp.fetch(fileUrl(SCORE_PATH), {
    method: 'put', headers: headers(token), contentType: 'application/json', muteHttpExceptions: true,
    payload: JSON.stringify({ branch: BRANCH, sha: current.sha, message: message,
      content: Utilities.base64Encode(JSON.stringify(current.data, null, 2), Utilities.Charset.UTF_8) })
  });
  return response.getResponseCode();
}

function resetWeeklyScores() {
  const lock = LockService.getScriptLock();
  try {
    const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
    if (!token) throw new Error('Score server is not configured');
    lock.waitLock(30000);
    for (let attempt = 0; attempt < 3; attempt++) {
      const current = readFile(token, SCORE_PATH);
      validateScoreFile(current.data);
      if (!rollWeek(current.data, new Date())) return;
      const status = writeScores(token, current, 'Reset timing shooter weekly ranking');
      if (status === 200 || status === 201) return;
      if (status !== 409 && status !== 422) throw new Error('Weekly reset failed (' + status + ')');
    }
    throw new Error('Weekly reset conflict; retry');
  } finally { if (lock.hasLock()) lock.releaseLock(); }
}

// Run once after configuring properties. Only this project's reset trigger is replaced.
function installWeeklyResetTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (trigger) {
    if (trigger.getHandlerFunction() === 'resetWeeklyScores') ScriptApp.deleteTrigger(trigger);
  });
  ScriptApp.newTrigger('resetWeeklyScores').timeBased().everyWeeks(1)
    .onWeekDay(ScriptApp.WeekDay.MONDAY).atHour(0).nearMinute(15).inTimezone('Asia/Seoul').create();
}

function validateResult(value) {
  if (!value || value.type !== 'stageClear' || value.game !== 'timing-shooter' || value.stageId !== 'stage1' || value.revision !== 1) throw new Error('Invalid game result');
  if (typeof value.runId !== 'string' || !/^[A-Za-z0-9-]{10,80}$/.test(value.runId)) throw new Error('Invalid run ID');
  for (const field of ['shootScore', 'remainingHp', 'hpScore', 'totalScore']) {
    if (!Number.isSafeInteger(value[field]) || value[field] < 0 || value[field] > 10000000) throw new Error('Invalid score');
  }
  if (value.remainingHp > 100 || value.hpScore !== value.remainingHp * 100 || value.totalScore !== value.shootScore + value.hpScore) throw new Error('Score does not match');
  return { runId: value.runId, stageId: value.stageId, revision: value.revision,
    shootScore: value.shootScore, remainingHp: value.remainingHp, hpScore: value.hpScore, totalScore: value.totalScore };
}
function fileUrl(path) { return 'https://api.github.com/repos/' + OWNER + '/' + REPO + '/contents/' + path; }
function headers(token) { return { Authorization: 'Bearer ' + token, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' }; }
function readFile(token, path) {
  const response = UrlFetchApp.fetch(fileUrl(path) + '?ref=' + BRANCH, { headers: headers(token), muteHttpExceptions: true });
  if (response.getResponseCode() !== 200) throw new Error('Cannot read game data');
  const body = JSON.parse(response.getContentText());
  return { sha: body.sha, data: JSON.parse(Utilities.newBlob(Utilities.base64Decode(body.content.replace(/\s/g, ''))).getDataAsString('UTF-8')) };
}
function respond(body) { return ContentService.createTextOutput(JSON.stringify(body)).setMimeType(ContentService.MimeType.JSON); }
