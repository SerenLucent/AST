// Timing Shooter Multi Play. Separate from the public ranking project.
var MP = {
  ttl: 30000, roomLimit: 30,
  durations: { 1: 600, 2: 700, 3: 800, 4: 900, 5: 1000 },
  reference: { 1: 650, 2: 800, 3: 950, 4: 1100, 5: 1250 },
  attackWindows: { perfect: 80, great: 180, good: 300, bad: 440 },
  dodgeWindows: { perfect: 80, great: 160, good: 260, bad: 380 },
  damage: { perfect: 10, great: 7, good: 4, bad: 1, miss: 0 },
  dodge: { perfect: 0, great: 0, good: .2, bad: .5, miss: 1 },
  colors: ['b', 'g', 'y', 'r']
};

function mpError(message, code) {
  var error = new Error(message); error.code = code || 'INVALID_REQUEST'; throw error;
}
function mpId() { return Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, ''); }
function mpGrade(delta, correct, defense, speed) {
  if (!correct || !Number.isFinite(delta)) return 'miss';
  var base = defense ? MP.dodgeWindows : MP.attackWindows;
  var ratio = MP.durations[speed] / MP.reference[speed];
  return Object.keys(base).find(function (grade) { return Math.abs(delta) <= Math.round(base[grade] * ratio); }) || 'miss';
}
function mpDefense(room, shot, grade) {
  shot.defense = grade;
  shot.damage = Math.ceil(MP.damage[shot.attack] * MP.dodge[grade]);
  var defender = 2 - room.attacker;
  room.hp[defender] = Math.max(0, room.hp[defender] - shot.damage);
}
function mpAdvance(room, now) {
  var before = room.phase;
  if (room.phase === 'intro' && now >= room.phaseAt) room.phase = 'roulette';
  if (room.phase === 'result' && now >= room.phaseAt) {
    if (room.hp.includes(0) || (!room.settings.deathmatch && room.turn >= room.settings.turnLimit * 2)) {
      room.phase = 'over';
      room.winner = room.hp[0] === room.hp[1] ? 0 : room.hp[0] > room.hp[1] ? 1 : 2;
    } else { room.attacker = 3 - room.attacker; room.turn++; room.shots = []; room.phase = 'roulette'; }
  }
  if (['attack', 'defense'].includes(room.phase) && now >= room.deadline) {
    var attack = room.phase === 'attack';
    room.shots.forEach(function (shot) {
      if (attack && !shot.attack) shot.attack = 'miss';
      if (!attack && !shot.defense) mpDefense(room, shot, 'miss');
    });
    room.phase = attack ? 'defense' : 'result'; room.phaseAt = now + (attack ? 2000 : 3000);
    room.deadline = room.phaseAt + 120000;
  }
  if (before !== room.phase) room.revision++;
}
function mpSnapshot(room, player) {
  return { code: room.code, mode: room.mode, started: room.started, attacker: room.attacker,
    turn: room.turn, revision: room.revision, phase: room.phase, phaseAt: room.phaseAt,
    hp: room.hp.slice(), settings: room.settings, winner: room.winner, serverNow: Date.now(), departure: room.departure || null,
    shots: room.shots.map(function (shot) {
      return Object.assign({}, shot, { attack: player === room.attacker || ['result', 'over'].includes(room.phase) ? shot.attack : null });
    }),
    coop: room.coop || null,
    players: room.players.map(function (entry, index) { return { player: index + 1, connected: Boolean(entry) }; }) };
}
function mpSave(store, room) {
  var data = JSON.stringify(room);
  if (Utilities.newBlob(data).getBytes().length > 8500) mpError('방 데이터가 너무 큽니다.');
  store.setProperty('room:' + room.code, data);
}
function mpCleanup(store, now) {
  var all = store.getProperties();
  Object.keys(all).filter(function (key) { return key.indexOf('room:') === 0; }).forEach(function (key) {
    var room = JSON.parse(all[key]);
    if (now - room.players[0].seen > MP.ttl) store.deleteProperty(key);
  });
}
function mpHandle(input) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) mpError('서버가 바쁩니다. 잠시 후 다시 시도해 주세요.', 'SERVER_BUSY');
  try {
    var store = PropertiesService.getScriptProperties();
    var now = Date.now();
    var room, token, player;
    if (input.action === 'create') {
      mpCleanup(store, now);
      var rooms = Object.keys(store.getProperties()).filter(function (key) { return key.indexOf('room:') === 0; });
      // Persistent creation IDs keep a retry from opening a second room.
      for (var key of rooms) {
        var existing = JSON.parse(store.getProperty(key));
        if (existing.createId === input.requestId) return { token: existing.players[0].token, player: 1, room: mpSnapshot(existing, 1) };
      }
      if (rooms.length >= MP.roomLimit) mpError('방이 가득 찼습니다. 잠시 후 다시 시도해 주세요.', 'SERVER_BUSY');
      if (!['vs', 'coop'].includes(input.mode || 'vs')) mpError('잘못된 게임 모드입니다.');
      var code;
      do { code = Utilities.getUuid().slice(0, 6).toUpperCase(); } while (store.getProperty('room:' + code));
      token = mpId();
      room = { code: code, mode: input.mode || 'vs', createId: input.requestId,
        players: [{ token: token, seen: now }, null], started: false, attacker: 1, turn: 1,
        hp: [100, 100], shots: [], phase: 'lobby', phaseAt: 0, revision: 0,
        settings: { turnLimit: 10, deathmatch: false }, winner: null, receipts: [],
        coop: { battle: 1, results: [null, null] } };
      mpSave(store, room);
      return { token: token, player: 1, room: mpSnapshot(room, 1) };
    }
    var code = String(input.code || '').toUpperCase();
    if (!/^[A-F0-9]{6}$/.test(code)) mpError('방 ID를 확인해 주세요.', 'ROOM_CLOSED');
    var raw = store.getProperty('room:' + code);
    if (!raw) mpError('방이 없거나 종료되었습니다.', 'ROOM_CLOSED');
    room = JSON.parse(raw);
    if (now - room.players[0].seen > MP.ttl) {
      store.deleteProperty('room:' + code); mpError('방장의 연결이 끊어졌습니다.', 'ROOM_CLOSED');
    }
    if (room.players[1] && now - room.players[1].seen > MP.ttl) {
      room.players[1] = null; room.started = false; room.departure = 'timeout'; room.revision++;
    }
    if (input.action === 'join') {
      if (room.players[1] && room.players[1].joinId === input.requestId) {
        return { token: room.players[1].token, player: 2, room: mpSnapshot(room, 2) };
      }
      if (room.mode !== (input.mode || 'vs')) mpError('다른 모드의 방입니다.');
      if (room.started || room.players[1]) mpError('이미 두 명이 참가한 방입니다.');
      token = mpId(); room.players[1] = { token: token, seen: now, joinId: input.requestId };
      room.departure = null;
      room.revision++; mpSave(store, room);
      return { token: token, player: 2, room: mpSnapshot(room, 2) };
    }
    var index = room.players.findIndex(function (entry) { return entry && entry.token === input.token; });
    if (index < 0) mpError('참가 정보가 유효하지 않습니다.', 'INVALID_SESSION');
    player = index + 1;
    var previous = raw;
    if (now - room.players[index].seen >= 15000 || input.action !== 'poll') room.players[index].seen = now;
    mpAdvance(room, now);
    if (input.requestId && room.receipts.some(function (receipt) { return receipt.id === input.requestId && receipt.player === player; })) {
      return { room: mpSnapshot(room, player) };
    }
    switch (input.action) {
      case 'poll':
      case 'heartbeat': break;
      case 'settings':
        if (index !== 0 || room.started || room.mode !== 'vs') mpError('대기 중인 방장만 설정을 바꿀 수 있습니다.');
        if (!Number.isInteger(input.turnLimit) || input.turnLimit < 1 || input.turnLimit > 100 || typeof input.deathmatch !== 'boolean') mpError('잘못된 결투 설정입니다.');
        room.settings = { turnLimit: input.turnLimit, deathmatch: input.deathmatch }; break;
      case 'start':
        if (index !== 0 || !room.players[1]) mpError('두 명이 참가한 뒤 방장이 시작할 수 있습니다.');
        if (!room.started) {
          room.started = true; room.attacker = 1; room.turn = 1; room.hp = [100, 100]; room.shots = []; room.winner = null;
          room.phase = room.mode === 'vs' ? 'intro' : 'coop'; room.phaseAt = now + 2150;
          room.coop = { battle: 1, results: [null, null] };
        }
        break;
      case 'plan':
        if (room.mode !== 'vs' || !room.started || player !== room.attacker || room.phase !== 'roulette' || input.turn !== room.turn) mpError('패턴을 정할 수 없는 턴입니다.');
        if (!Array.isArray(input.speeds) || input.speeds.length < 3 || input.speeds.length > 6 || input.speeds.some(function (speed) { return !Number.isInteger(speed) || !MP.durations[speed]; })) mpError('잘못된 공격 패턴입니다.');
        room.shots = input.speeds.map(function (speed) { return { speed: speed, duration: MP.durations[speed], color: MP.colors[Math.floor(Math.random() * 4)], attack: null, defense: null, damage: null }; });
        room.phase = 'attack'; room.phaseAt = now + 2000; room.deadline = room.phaseAt + 120000; break;
      case 'round': {
        if (room.mode !== 'vs' || !room.started || input.turn !== room.turn) mpError('이미 끝난 턴입니다.');
        var defense = player !== room.attacker;
        var field = defense ? 'defense' : 'attack';
        if (room.shots.length && room.shots.every(function (shot) { return Boolean(shot[field]); })) break;
        if (room.phase !== (defense ? 'defense' : 'attack') || now < room.phaseAt) mpError('결과를 보낼 수 없는 단계입니다.');
        if (!Array.isArray(input.results) || input.results.length !== room.shots.length) mpError('탄환 결과가 부족합니다.');
        input.results.forEach(function (result, i) {
          if (!result || result.index !== i || !Number.isFinite(result.delta) || (result.color !== null && !MP.colors.includes(result.color))) mpError('잘못된 탄환 결과입니다.');
        });
        input.results.forEach(function (result, i) {
          var shot = room.shots[i];
          var grade = mpGrade(result.delta, result.color === shot.color, defense, shot.speed);
          if (defense) mpDefense(room, shot, grade); else shot.attack = grade;
        });
        room.phase = defense ? 'result' : 'defense'; room.phaseAt = now + (defense ? 3000 : 2000);
        room.deadline = room.phaseAt + 120000; break;
      }
      case 'coopResult':
        if (room.mode !== 'coop' || !room.started || input.battle !== room.coop.battle) mpError('결과를 공유할 수 없는 전투입니다.');
        var result = input.result;
        if (!result || !Number.isInteger(result.score) || result.score < 0 || result.score > 100000000 || !Number.isInteger(result.hp) || result.hp < 0 || result.hp > 100 || !Number.isInteger(result.defeated) || result.defeated < 0 || result.defeated > 1000) mpError('잘못된 전투 결과입니다.');
        if (room.coop.results[index]) break;
        room.coop.results[index] = { score: result.score, hp: result.hp, defeated: result.defeated };
        break;
      case 'coopNext':
        if (room.mode !== 'coop' || index !== 0 || !room.started || !room.coop.results.every(Boolean) || input.battle !== room.coop.battle) mpError('두 사람의 결과가 모인 뒤 방장이 진행할 수 있습니다.');
        room.coop = { battle: room.coop.battle + 1, results: [null, null] }; break;
      case 'leave':
        if (index === 0) { store.deleteProperty('room:' + code); return { left: true }; }
        room.players[1] = null; room.started = false; room.departure = 'leave'; break;
      default: mpError('지원하지 않는 요청입니다.');
    }
    if (!['poll', 'heartbeat'].includes(input.action)) {
      room.revision++;
      room.receipts.push({ id: input.requestId, player: player }); room.receipts = room.receipts.slice(-12);
    }
    if (previous !== JSON.stringify(room)) mpSave(store, room);
    return { room: mpSnapshot(room, player) };
  } finally { lock.releaseLock(); }
}
function mpOutput(data, callback) {
  var json = JSON.stringify(data).replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
  if (callback && /^__tsmp_[0-9]+_[0-9]+$/.test(callback)) {
    return ContentService.createTextOutput(callback + '(' + json + ');').setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(json).setMimeType(ContentService.MimeType.JSON);
}
function doGet(e) {
  var input = e && e.parameter || {};
  try {
    if (input.action === 'receipt') {
      if (!/^[a-f0-9-]{36}$/.test(input.requestId || '')) mpError('잘못된 요청 ID입니다.');
      var receipt = CacheService.getScriptCache().get('receipt:' + input.requestId);
      return mpOutput(receipt ? JSON.parse(receipt) : { pending: true }, input.callback);
    }
    if (input.action === 'poll') return mpOutput(mpHandle(input), input.callback);
    return mpOutput({ service: 'Timing Shooter Multi Play', version: 2, modes: ['vs', 'coop'], heartbeatMs: 10000, disconnectMs: MP.ttl }, input.callback);
  } catch (error) { return mpOutput({ error: error.message, code: error.code || 'SERVER_ERROR' }, input.callback); }
}
function doPost(e) {
  var input;
  try {
    var body = e && e.postData && e.postData.contents || '';
    if (body.length > 4096) mpError('요청이 너무 큽니다.');
    input = JSON.parse(body);
    if (!/^[a-f0-9-]{36}$/.test(input.requestId || '')) mpError('잘못된 요청 ID입니다.');
    var result = mpHandle(input);
  } catch (error) { var result = { error: error.message, code: error.code || 'SERVER_ERROR' }; }
  if (input && /^[a-f0-9-]{36}$/.test(input.requestId || '')) CacheService.getScriptCache().put('receipt:' + input.requestId, JSON.stringify(result), 300);
  return mpOutput(result);
}
