(() => {
  const cfg = window.DUEL_CONFIG;
  const colors = { b: '#3d8cff', g: '#39ff67', y: '#ffd629', r: '#ff3434' };
  class DuelCombat {
    constructor(scene) {
      this.scene = scene;
      this.room = null;
      this.key = '';
      this.current = null;
      this.activeShots = new Map();
      this.running = false;
      this.timer = null;
      this.frame = null;
      this.token = 0;
      this.pending = null;
      this.effectTimers = new Set();
      this.root = document.createElement('div');
      this.root.className = 'duel-combat';
      this.root.hidden = true;
      this.root.innerHTML = `<div class="duel-hp">${[1, 2].map(player => `<div class="duel-hp-row" data-player="${player}"><span>${player}P</span><div class="duel-hp-track" role="progressbar" aria-label="${player}P HP" aria-valuemin="0" aria-valuemax="${cfg.initialHp}"><div class="duel-hp-well"><div class="duel-hp-fill"></div></div></div><strong class="duel-hp-value">${cfg.initialHp}</strong></div>`).join('')}</div>
        <section class="duel-pattern"><div class="duel-count"></div>
          <div class="duel-table-scroll"><table><thead></thead><tbody></tbody></table></div><button class="duel-ok" type="button">OK</button></section>
        <div class="duel-cue" role="status"></div>
        <div class="duel-target-layer"></div>
        <div class="duel-evade" hidden><div class="duel-evade-fixed"></div></div>`;
      scene.root.append(this.root);
      this.pad = document.getElementById('pad');
      this.resizeObserver = new ResizeObserver(() => {
        this.positionTarget();
      });
      this.resizeObserver.observe(scene.root);
      this.root.querySelector('.duel-ok').addEventListener('click', () => this.lock());
      this.roulette = new Audio('sound/roulette.mp3');
      this.roulette.loop = true; this.roulette.volume = .6;
      this.confirm = new Audio('sound/confirm.mp3'); this.confirm.volume = .8;
      this.preloads = [];
      [this.roulette, this.confirm].forEach(audio => { audio.preload = 'none'; });
    }

    prepare() {
      if (!this.preloads.length) {
        this.preloads = cfg.colors.flatMap(color => ['perfect_target', 'circle', 'target'].map(name => {
          const image = new Image(); image.src = `sprites/${name}_${color}.png`; return image;
        }));
      }
      if (!this.effectPreloads) {
        this.effectPreloads = [1, 2, 3].map(frame => {
          const image = new Image(); image.src = `sprites/effects/bullet_effect_${frame}.png`; return image;
        });
      }
      return Promise.all([...this.preloads, ...this.effectPreloads].map(image => image.decode()));
    }

    cue(text) { this.root.querySelector('.duel-cue').textContent = text; }

    update(room) {
      if (this.key === `${room.turn}:${room.phase}` && this.roundResults?.length) {
        const defense = room.phase === 'defense';
        const activePlayer = defense ? 3 - room.attacker : room.attacker;
        if (['attack', 'defense'].includes(room.phase) && this.scene.player === activePlayer) {
          // Polls cannot erase results being collected locally during a round.
          for (const result of this.roundResults) {
            const shot = room.shots[result.index];
            shot[defense ? 'defense' : 'attack'] = cfg.grade(result.delta, result.color === shot.color, defense, shot.speed);
          }
        }
      }
      this.room = room;
      this.root.hidden = !room.started || this.scene.introActive;
      if (this.root.hidden) return;
      this.root.querySelectorAll('.duel-hp-row').forEach((row, index) => {
        const hp = Math.max(0, Math.min(cfg.initialHp, room.hp[index]));
        const percent = hp / cfg.initialHp * 100;
        const fill = row.querySelector('.duel-hp-fill');
        fill.style.width = `${percent}%`;
        fill.style.backgroundColor = percent <= 20 ? '#ff3434' : percent <= 50 ? '#ff922b' : '#ffd629';
        row.querySelector('.duel-hp-track').setAttribute('aria-valuenow', hp);
        row.querySelector('.duel-hp-value').textContent = hp;
      });
      const key = `${room.turn}:${room.phase}`;
      if (key !== this.key) {
        this.cancel();
        this.key = key;
        this.root.hidden = false;
        if (room.phase === 'roulette') this.startRoulette();
        if (['attack', 'defense'].includes(room.phase)) this.countdown();
        if (room.phase === 'result') this.cue('TURN RESULT');
        if (room.phase === 'over') this.cue(room.winner === 0 ? 'DRAW' : room.winner === this.scene.player ? 'YOU WIN' : 'YOU LOSE');
      }
      if (room.phase !== 'roulette' || this.scene.player !== room.attacker) this.renderTable(room.shots);
      if (this.pending) this.retryPending();
    }

    bullets(count) {
      return Array.from({ length: count }, () => '<img src="sprites/UI/dodge_bullet_gold_v2.png" alt="">').join('');
    }

    speedOrbs(speed) {
      const patterns = { 1: ['y', 'y', 'g', 'g', 'r'], 2: ['y', 'y', 'g', 'g'],
        3: ['y', 'y', 'g'], 4: ['y', 'y'], 5: ['y'] };
      const seconds = cfg.durationBySpeed[speed] / 1000;
      return `<span class="duel-speed" role="img" aria-label="${seconds}초" title="${seconds}초">${patterns[speed].map(color => `<img src="sprites/target_${color}.png" alt="">`).join('')}</span>`;
    }

    renderTable(shots) {
      const attacker = this.scene.player === this.room.attacker;
      this.root.querySelector('.duel-count').innerHTML = `<span>공격 횟수</span><div>${this.bullets(shots.length)}</div>`;
      this.root.querySelector('thead').innerHTML = attacker
        ? '<tr><th>탄환</th><th>스피드</th><th>공격판정</th></tr>'
        : '<tr><th>탄환</th><th>회피판정</th></tr>';
      this.root.querySelector('tbody').innerHTML = shots.map((shot, index) => {
        const grade = attacker ? shot.attack : shot.defense;
        return `<tr class="${this.activeShots.has(index) ? 'current' : ''}"><td>${this.bullets(1)}${index + 1}</td>${attacker ? `<td>${this.speedOrbs(shot.speed)}</td>` : ''}<td style="color:${grade ? this.gradeColor(grade) : '#fff'}">${grade ? grade[0].toUpperCase() + grade.slice(1) : '—'}${!attacker && shot.damage != null ? ` (-${shot.damage})` : ''}</td></tr>`;
      }).join('');
      this.root.querySelector('.duel-ok').hidden = this.room.phase !== 'roulette' || !attacker;
    }

    startRoulette() {
      if (this.scene.player !== this.room.attacker) { this.cue('상대방의 공격 준비 중'); return; }
      this.cue('');
      this.stopRoulette();
      this.rouletteAudio = this.scene.onRouletteAudio?.();
      if (!this.rouletteAudio) {
        this.roulette.currentTime = 0;
        this.roulette.play().catch(() => {});
      }
      const roll = () => {
        const count = cfg.shotCount.min + Math.floor(Math.random() * (cfg.shotCount.max - cfg.shotCount.min + 1));
        this.draft = Array.from({ length: count }, () => ({ speed: 1 + Math.floor(Math.random() * 5) }));
        this.renderTable(this.draft);
        this.timer = setTimeout(roll, 85);
      };
      roll();
    }

    async lock() {
      if (this.room?.phase !== 'roulette' || this.scene.player !== this.room.attacker || !this.draft || this.locking) return;
      this.locking = true;
      clearTimeout(this.timer); this.stopRoulette();
      this.confirm.currentTime = 0;
      this.confirm.play().catch(() => {});
      const button = this.root.querySelector('.duel-ok'); button.disabled = true;
      try {
        await this.scene.command('plan', { speeds: this.draft.map(shot => shot.speed) });
      } finally {
        this.locking = false; button.disabled = false;
        if (this.room?.phase === 'roulette' && this.scene.active) this.startRoulette();
      }
    }

    countdown() {
      this.roundResults = [];
      const token = this.token;
      const remaining = Math.max(0, this.room.phaseAt - this.room.serverNow);
      this.cue(this.room.phase === 'attack' ? 'GET READY' : 'DEFENSE READY');
      this.timer = setTimeout(() => {
        if (token !== this.token) return;
        const activePlayer = this.room.phase === 'attack' ? this.room.attacker : 3 - this.room.attacker;
        this.cue(this.room.phase === 'attack' ? 'ATTACK START' : 'DEFENSE START');
        this.timer = setTimeout(() => {
          if (token !== this.token) return;
          if (this.scene.player === activePlayer) this.beginShot();
          else this.cue(this.room.phase === 'attack' ? '상대방 공격 중' : '상대방 회피 중');
        }, 450);
      }, remaining);
    }

    beginShot() {
      if (this.running || !this.scene.active || !['attack', 'defense'].includes(this.room.phase)) return;
      this.running = true;
      this.roundResults = [];
      this.nextShotIndex = 0;
      this.nextLaunchAt = performance.now();
      this.cue('');
      this.root.querySelector('.duel-evade').hidden = this.room.phase !== 'defense';
      const frame = () => {
        if (!this.running) return;
        const now = performance.now();
        this.spawnDueShot(now);
        for (const state of [...this.activeShots.values()]) {
          const remaining = state.perfectAt - now;
          const windows = cfg.timingWindows(state.shot.speed, state.defense);
          if (state.defense) {
            if (remaining <= 0 && !state.flashed) this.flashMuzzle(state);
            const inset = remaining >= 0 ? 8 + 80 * remaining / state.shot.duration : 8 * (1 + remaining / windows.bad);
            state.element.style.inset = `${Math.max(0, inset)}px`;
          } else {
            const scale = Math.max(.15, 52 / 120 + (1.75 - 52 / 120) * remaining / state.shot.duration);
            state.element.querySelector('.duel-ring').style.transform = `translate(-50%, -50%) scale(${scale})`;
          }
          if (remaining < -windows.bad) this.resolveShot(state, null, now);
        }
        this.refreshCurrent();
        if (this.running) this.frame = requestAnimationFrame(frame);
      };
      frame();
    }

    spawnDueShot(now) {
      if (!this.running || this.pending || this.activeShots.size >= cfg.maxActiveShots
        || this.nextShotIndex >= this.room.shots.length || now < this.nextLaunchAt) return;
      const defense = this.room.phase === 'defense';
      const index = this.nextShotIndex++;
      const shot = this.room.shots[index];
      const lanes = new Set([...this.activeShots.values()].map(state => state.lane));
      const lane = lanes.has(0) ? 1 : 0;
      const element = document.createElement('div');
      element.dataset.index = index;
      element.dataset.lane = lane;
      element.style.setProperty('--shot-color', colors[shot.color]);
      if (defense) {
        element.className = 'duel-evade-moving';
        this.root.querySelector('.duel-evade').append(element);
      } else {
        element.className = 'duel-shot-target';
        element.setAttribute('role', 'img');
        element.setAttribute('aria-label', `${index + 1}번 탄환 ${lane === 0 ? '상체' : '하체'}`);
        element.innerHTML = `<img class="duel-perfect" src="sprites/perfect_target_${shot.color}.png" alt=""><img class="duel-ring" src="sprites/circle_${shot.color}.png" alt=""><img class="duel-center" src="sprites/target_${shot.color}.png" alt="">`;
        this.root.querySelector('.duel-target-layer').append(element);
      }
      const state = { index, shot, defense, lane, element, startedAt: now, perfectAt: now + shot.duration, flashed: false };
      this.activeShots.set(index, state);
      this.nextLaunchAt = now + cfg.shotSpawnIntervalMs;
      this.positionTarget();
      this.pad.inert = false;
      this.renderTable(this.room.shots);
    }

    positionTarget() {
      for (const state of this.activeShots.values()) {
        if (state.defense) continue;
        const { x, y } = this.scene.player === 2
          ? this.scene.policeTargetPosition(state.lane) : this.scene.mafiaTargetPosition(state.lane);
        state.element.style.left = `${x}px`; state.element.style.top = `${y}px`;
      }
    }

    refreshCurrent() {
      this.current = [...this.activeShots.values()].sort((a, b) => a.perfectAt - b.perfectAt || a.index - b.index)[0] || null;
      this.pad.inert = !this.activeShots.size || Boolean(this.pending);
    }

    press(color) {
      if (!this.activeShots.size || this.pending) return;
      const now = performance.now();
      const active = [...this.activeShots.values()];
      const matching = active.filter(state => state.shot.color === color);
      const candidates = matching.length ? matching : active;
      const current = candidates.sort((a, b) => Math.abs(now - a.perfectAt) - Math.abs(now - b.perfectAt) || a.index - b.index)[0];
      this.resolveShot(current, color, now);
    }

    flashMuzzle(state) {
      state.flashed = true;
      this.showShotEffect(this.scene.muzzlePosition(), true);
    }

    resolveShot(current, color, now = performance.now()) {
      if (!this.activeShots.has(current.index) || this.pending) return;
      const delta = Math.round(now - current.perfectAt);
      const grade = cfg.grade(delta, color === current.shot.color, current.defense, current.shot.speed);
      if (current.defense && grade !== 'miss') this.showDodgeFlash(current.shot.color);
      if (current.defense && !current.flashed) {
        this.flashMuzzle(current);
      } else if (!current.defense && grade !== 'miss') {
        const bounds = current.element.getBoundingClientRect();
        const rootBounds = this.root.getBoundingClientRect();
        this.showShotEffect({ x: bounds.left + bounds.width / 2 - rootBounds.left,
          y: bounds.top + bounds.height / 2 - rootBounds.top }, false);
      }
      current.element.remove();
      this.activeShots.delete(current.index);
      this.cue(grade[0].toUpperCase() + grade.slice(1));
      this.scene.onCombatSound?.(grade, current.defense);
      if (current.defense && ['perfect', 'great', 'good'].includes(grade)) {
        const images = this.scene.root.querySelector('.duel-images');
        images.classList.remove('evading'); void images.offsetWidth; images.classList.add('evading');
      }
      this.roundResults.push({ index: current.index, delta, color });
      this.room.shots[current.index][current.defense ? 'defense' : 'attack'] = grade;
      if (this.roundResults.length < this.room.shots.length) {
        this.spawnDueShot(now);
        this.refreshCurrent();
        this.renderTable(this.room.shots);
        return;
      }
      this.running = false;
      cancelAnimationFrame(this.frame);
      this.current = null;
      this.pad.inert = true;
      this.root.querySelector('.duel-evade').hidden = true;
      this.renderTable(this.room.shots);
      // Results are keyed by bullet number, not by the order the player resolved them.
      this.pending = { turn: this.room.turn, results: this.roundResults.slice().sort((a, b) => a.index - b.index), requestId: crypto.randomUUID() };
      this.cue('결과 전송 중');
      this.retryPending();
    }

    async retryPending() {
      if (!this.pending || this.submitting) return;
      const pending = this.pending;
      const token = this.token;
      this.submitting = true;
      try {
        const data = await this.scene.request('round', this.scene.session.code, this.scene.session.token, pending.turn, pending);
        if (!this.scene.active || token !== this.token) return;
        this.pending = null;
        this.scene.applyRoom(data.room);
      } catch (error) {
        if (token === this.token) this.cue('연결 재시도 중');
      } finally { this.submitting = false; }
    }

    gradeColor(grade) { return { perfect: '#ffd629', great: '#39ff67', good: '#3d8cff', bad: '#c192ff', miss: '#ff3434' }[grade]; }

    effectLater(callback, delay) {
      const timer = setTimeout(() => { this.effectTimers.delete(timer); callback(); }, delay);
      this.effectTimers.add(timer);
    }

    showDodgeFlash(color) {
      const flash = document.createElement('div');
      flash.className = 'duel-dodge-flash';
      flash.setAttribute('aria-hidden', 'true');
      flash.style.setProperty('--dodge-color', colors[color]);
      // Keep each result independent, including the last bullet and overlapping hits.
      this.root.append(flash);
      this.effectLater(() => flash.remove(), 280);
    }

    showShotEffect(position, muzzle) {
      const effect = document.createElement('img');
      effect.className = `duel-shot-effect ${muzzle ? 'duel-muzzle-effect' : 'duel-hit-effect'}`;
      effect.alt = '';
      effect.src = 'sprites/effects/bullet_effect_1.png';
      effect.style.left = `${position.x}px`; effect.style.top = `${position.y}px`;
      (muzzle ? this.scene.root.querySelector('.duel-images') : this.root).append(effect);
      this.effectLater(() => { effect.src = 'sprites/effects/bullet_effect_2.png'; }, 55);
      this.effectLater(() => { effect.src = 'sprites/effects/bullet_effect_3.png'; }, 110);
      this.effectLater(() => effect.remove(), muzzle ? 170 : 230);
    }

    stopRoulette() {
      this.roulette.pause();
      this.rouletteAudio?.stop();
      this.rouletteAudio = null;
    }

    cancel(clearEffects = false) {
      this.token++;
      this.running = false;
      for (const state of this.activeShots.values()) state.element.remove();
      this.activeShots.clear();
      if (clearEffects) {
        this.effectTimers.forEach(timer => clearTimeout(timer)); this.effectTimers.clear();
        this.scene.root.querySelectorAll('.duel-shot-effect, .duel-dodge-flash').forEach(effect => effect.remove());
      }
      clearTimeout(this.timer); cancelAnimationFrame(this.frame);
      this.stopRoulette(); this.current = null; this.pending = null;
      this.pad.inert = true;
      this.root.querySelector('.duel-evade').hidden = true;
    }

    stop() {
      this.cancel(true); this.key = ''; this.root.hidden = true; this.pad.inert = false;
      this.confirm.pause(); this.confirm.currentTime = 0;
    }
  }
  window.DuelCombat = DuelCombat;
})();
