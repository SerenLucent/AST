const crypto = require('node:crypto');
const config = require('./duel_config');

// Local prototype rooms live only for this server process, never in ranking JSON.
module.exports = function createDuelRooms() {
  const rooms = new Map();
  const ttl = 30000;
  function cleanup() {
    const now = Date.now();
    for (const [code, room] of rooms) {
      if (now - room.players[0].seen > ttl) rooms.delete(code);
      else if (room.players[1] && now - room.players[1].seen > ttl) {
        room.players[1] = null;
        room.departure = 'timeout';
        room.started = false;
        room.revision++;
      }
    }
  }
  function finishDefense(room, shot, grade) {
    shot.defense = grade;
    shot.damage = Math.ceil(config.attackDamage[shot.attack] * config.dodgeMultiplier[grade]);
    const defender = 2 - room.attacker;
    room.hp[defender] = Math.max(0, room.hp[defender] - shot.damage);
  }
  function advance(room) {
    const phaseBefore = room.phase;
    const now = Date.now();
    if (room.phase === 'intro' && now >= room.phaseAt) room.phase = 'roulette';
    if (room.phase === 'result' && now >= room.phaseAt) {
      if (room.hp.includes(0) || (!room.settings.deathmatch && room.turn >= room.settings.turnLimit * 2)) {
        room.phase = 'over';
        room.winner = room.hp[0] === room.hp[1] ? 0 : room.hp[0] > room.hp[1] ? 1 : 2;
      }
      else { room.attacker = 3 - room.attacker; room.turn++; room.shots = []; room.phase = 'roulette'; }
    }
    if (['attack', 'defense'].includes(room.phase) && now >= room.deadline) {
      for (const shot of room.shots) {
        if (room.phase === 'attack' && !shot.attack) shot.attack = 'miss';
        if (room.phase === 'defense' && !shot.defense) finishDefense(room, shot, 'miss');
      }
      if (room.phase === 'attack') beginDefense(room);
      else { room.phase = 'result'; room.phaseAt = now + config.resultMs; }
    }
    if (room.phase !== phaseBefore) room.revision++;
  }
  function beginDefense(room) {
    room.phase = 'defense';
    room.phaseAt = Date.now() + config.countdownMs;
    room.deadline = room.phaseAt + 25000;
  }
  function snapshot(room, player = 1) {
    advance(room);
    return { code: room.code, started: room.started, attacker: room.attacker, turn: room.turn,
      revision: room.revision, phase: room.phase, phaseAt: room.phaseAt, hp: room.hp,
      settings: room.settings, winner: room.winner, serverNow: Date.now(), departure: room.departure || null,
      shots: room.shots.map(shot => ({ ...shot,
        attack: player === room.attacker || ['result', 'over'].includes(room.phase) ? shot.attack : null })),
      players: room.players.map((entry, index) => ({ player: index + 1, connected: Boolean(entry) })) };
  }
  return async function handle(req, res) {
    if (req.url.split('?')[0] !== '/api/duel') return false;
    const respond = (status, value) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify(value));
    };
    if (req.method !== 'POST') { respond(405, { error: 'POST required' }); return true; }
    try {
      let body = '';
      for await (const chunk of req) {
        body += chunk;
        if (body.length > 4096) { respond(413, { error: 'Request too large' }); return true; }
      }
      const input = JSON.parse(body);
      cleanup();
      if (input.action === 'create') {
        if (rooms.size >= 100) throw new Error('방이 가득 찼습니다. 잠시 후 다시 시도해 주세요.');
        let code;
        do { code = crypto.randomBytes(3).toString('hex').toUpperCase(); } while (rooms.has(code));
        const token = crypto.randomBytes(24).toString('hex');
        const room = { code, players: [{ token, seen: Date.now() }, null], started: false, attacker: 1, turn: 1,
          hp: [config.initialHp, config.initialHp], shots: [], phase: 'lobby', phaseAt: 0, revision: 0,
          settings: { turnLimit: 10, deathmatch: false }, winner: null };
        rooms.set(code, room);
        respond(200, { token, player: 1, room: snapshot(room) });
        return true;
      }
      const room = rooms.get(String(input.code || '').toUpperCase());
      if (!room) {
        const error = new Error('방이 없거나 종료되었습니다.');
        error.code = 'ROOM_CLOSED';
        throw error;
      }
      if (input.action === 'join') {
        if (room.started || room.players[1]) throw new Error('이미 두 명이 참가한 방입니다.');
        const token = crypto.randomBytes(24).toString('hex');
        room.players[1] = { token, seen: Date.now() };
        room.departure = null;
        room.revision++;
        respond(200, { token, player: 2, room: snapshot(room, 2) });
        return true;
      }
      const index = room.players.findIndex(entry => entry && entry.token === input.token);
      if (index === -1) throw new Error('참가 정보가 유효하지 않습니다.');
      room.players[index].seen = Date.now();
      advance(room);
      switch (input.action) {
        case 'poll':
        case 'heartbeat': break;
        case 'settings':
          if (index !== 0 || room.started) throw new Error('대기 중인 방장만 결투 설정을 바꿀 수 있습니다.');
          if (!Number.isInteger(input.turnLimit) || input.turnLimit < 1 || input.turnLimit > 100 || typeof input.deathmatch !== 'boolean') throw new Error('잘못된 결투 설정입니다.');
          room.settings = { turnLimit: input.turnLimit, deathmatch: input.deathmatch };
          break;
        case 'start':
          if (index !== 0 || !room.players[1]) throw new Error('두 명이 참가한 뒤 방장이 시작할 수 있습니다.');
          if (!room.started) {
            room.started = true; room.attacker = 1; room.turn = 1;
            room.hp = [config.initialHp, config.initialHp]; room.shots = [];
            room.winner = null;
            room.phase = 'intro'; room.phaseAt = Date.now() + 2150;
          }
          break;
        case 'plan':
          if (!room.started || index + 1 !== room.attacker || room.phase !== 'roulette' || input.turn !== room.turn) throw new Error('공격 패턴을 정할 수 없는 턴입니다.');
          if (!Array.isArray(input.speeds) || input.speeds.length < config.shotCount.min || input.speeds.length > config.shotCount.max || input.speeds.some(speed => !Number.isInteger(speed) || !config.durationBySpeed[speed])) throw new Error('잘못된 공격 패턴입니다.');
          room.shots = input.speeds.map(speed => ({ speed, duration: config.durationBySpeed[speed],
            color: config.colors[crypto.randomInt(4)], attack: null, defense: null, damage: null }));
          room.phase = 'attack'; room.phaseAt = Date.now() + config.countdownMs;
          room.deadline = room.phaseAt + 25000;
          break;
        case 'round': {
          if (!room.started || input.turn !== room.turn) throw new Error('이미 끝난 턴입니다.');
          const defense = index + 1 !== room.attacker;
          const field = defense ? 'defense' : 'attack';
          if (room.shots.length && room.shots.every(shot => shot[field])) break;
          if (room.phase !== (defense ? 'defense' : 'attack') || Date.now() < room.phaseAt) throw new Error('결과를 보낼 수 없는 단계입니다.');
          if (!Array.isArray(input.results) || input.results.length !== room.shots.length) throw new Error('탄환 결과가 부족합니다.');
          input.results.forEach((result, shotIndex) => {
            if (!result || result.index !== shotIndex || !Number.isFinite(result.delta)
              || (result.color !== null && !config.colors.includes(result.color))) throw new Error('잘못된 탄환 결과입니다.');
          });
          input.results.forEach((result, shotIndex) => {
            const shot = room.shots[shotIndex];
            const grade = config.grade(result.delta, result.color === shot.color, defense, shot.speed);
            if (defense) finishDefense(room, shot, grade); else shot.attack = grade;
          });
          if (defense) { room.phase = 'result'; room.phaseAt = Date.now() + config.resultMs; }
          else beginDefense(room);
          break;
        }
        case 'shot': {
          if (!room.started || input.turn !== room.turn) throw new Error('이미 끝난 턴입니다.');
          const shot = room.shots[input.index];
          const defense = index + 1 !== room.attacker;
          const field = defense ? 'defense' : 'attack';
          if (!shot) throw new Error('잘못된 탄환입니다.');
          if (shot[field]) break;
          if (room.phase !== (defense ? 'defense' : 'attack') || Date.now() < room.phaseAt) throw new Error('입력할 수 없는 단계입니다.');
          if (input.index !== room.shots.findIndex(entry => !entry[field])) throw new Error('탄환 순서가 맞지 않습니다.');
          const grade = config.grade(input.delta, input.color === shot.color, defense, shot.speed);
          if (defense) finishDefense(room, shot, grade);
          else shot.attack = grade;
          if (room.shots.every(entry => entry[field])) {
            if (defense) { room.phase = 'result'; room.phaseAt = Date.now() + config.resultMs; }
            else beginDefense(room);
          }
          break;
        }
        case 'leave':
          if (index === 0) rooms.delete(room.code);
          else { room.players[1] = null; room.started = false; room.departure = 'leave'; }
          break;
        default: throw new Error('지원하지 않는 요청입니다.');
      }
      if (input.action !== 'poll') room.revision++;
      respond(200, { room: snapshot(room, index + 1) });
    } catch (error) {
      respond(400, { error: error instanceof SyntaxError ? '잘못된 요청입니다.' : error.message, code: error.code });
    }
    return true;
  };
};
