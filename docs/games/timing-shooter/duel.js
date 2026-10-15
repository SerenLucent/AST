(() => {
  const scenes = {
    police: {
      aim: 'backgrounds/duel_2p_vs_police_aim_v3.png',
      cover: 'backgrounds/duel_2p_vs_police_cover_v3.png'
    },
    mafia: {
      aim: 'backgrounds/duel_1p_vs_mafia_aim_v2.png',
      cover: 'backgrounds/duel_1p_vs_mafia_cover_v2.png'
    }
  };

  class DuelScene {
    constructor(stage, { onExit, onMatchStart, onMatchStop, onCombatSound, onRouletteAudio } = {}) {
      this.onExit = onExit;
      this.onMatchStart = onMatchStart;
      this.onMatchStop = onMatchStop;
      this.onCombatSound = onCombatSound;
      this.onRouletteAudio = onRouletteAudio;
      this.active = false;
      this.player = 1;
      this.attacker = 1;
      this.turn = 1;
      this.preparation = null;
      this.session = null;
      this.draftSettings = null;
      this.pollTimer = null;
      this.busy = false;
      this.generation = 0;
      this.matchStarted = false;
      this.introActive = false;
      this.introTimer = null;
      this.root = document.createElement('section');
      this.root.id = 'duelScene';
      this.root.hidden = true;
      this.root.setAttribute('aria-label', 'VS Mode');
      this.root.innerHTML = `
        <div class="duel-images"></div>
        <header class="duel-header">
          <strong class="duel-player">VS MODE</strong>
          <button class="duel-exit" type="button" aria-label="Exit VS Mode">나가기</button>
        </header>
        <div class="duel-status" role="status" aria-live="polite">
          <strong class="duel-role"></strong><span class="duel-turn"></span>
        </div>
        <footer class="duel-footer">
          <button class="duel-next" type="button">다음 턴</button>
        </footer>
        <div class="duel-intro" role="status" aria-label="MATCH START" hidden>
          <div class="duel-intro-letters" aria-hidden="true"></div>
        </div>
        <div class="duel-turn-banner" role="status" hidden></div>
        <section class="duel-lobby" aria-label="VS room lobby">
          <h1>VS MODE</h1>
          <div class="duel-room-entry">
            <div class="duel-create-pane">
              <h2>방 만들기</h2>
              <button class="duel-create" type="button" aria-label="방 만들기" title="방 만들기"><span aria-hidden="true">+</span></button>
            </div>
            <form class="duel-join-form">
              <h2>참가하기</h2>
              <label for="duelRoomCode">방 ID 입력</label>
              <input id="duelRoomCode" maxlength="6" pattern="[a-fA-F0-9]{6}" autocomplete="off" required>
              <button type="submit">참가</button>
            </form>
          </div>
          <div class="duel-room-wait" hidden>
            <div class="duel-room-id">Room ID : <strong class="duel-code"></strong></div>
            <div class="duel-seats">
              <div class="duel-seat police" aria-label="1P 경찰">
                <div class="duel-seat-media"><img data-src="sprites/duel/police_card_v1.png" alt="Police"></div>
                <span class="duel-seat-player">1P</span><strong class="duel-seat-name">POLICE</strong>
              </div>
              <strong class="duel-seat-vs">VS</strong>
              <div class="duel-seat mafia empty" aria-label="2P 대기 중">
                <div class="duel-seat-media" hidden><img data-src="sprites/duel/mafia_card_v1.png" alt="Mafia"></div>
                <span class="duel-seat-player">2P</span><strong class="duel-seat-name">WAITING</strong>
              </div>
            </div>
            <div class="duel-settings">
              <label>결투 턴</label>
              <div class="duel-turn-control">
                <button class="duel-turn-down" type="button" aria-label="턴 수 줄이기">&#9661;</button>
                <output class="duel-turn-limit" role="spinbutton" aria-label="결투 턴" aria-valuemin="1" aria-valuemax="100" aria-valuenow="10">10</output>
                <button class="duel-turn-up" type="button" aria-label="턴 수 늘리기">&#9651;</button>
              </div>
              <button class="duel-deathmatch" type="button" role="switch" aria-checked="false">데스매치</button>
            </div>
            <button class="duel-start" type="button" disabled>결투 시작</button>
          </div>
          <p class="duel-message" role="status" aria-live="polite"></p>
        </section>
        <div class="duel-host-left" role="dialog" aria-modal="true" aria-labelledby="duelHostLeftMessage" hidden>
          <div class="duel-host-dialog"><p id="duelHostLeftMessage">방장이 나갔습니다.</p><button class="duel-host-confirm" type="button">확인</button></div>
        </div>`;
      this.images = new Map();
      let letterIndex = 0;
      for (const letter of 'MATCH START') {
        const span = document.createElement('span');
        span.textContent = letter;
        if (letter === ' ') span.className = 'duel-intro-space';
        else span.style.setProperty('--i', letterIndex++);
        this.root.querySelector('.duel-intro-letters').appendChild(span);
      }
      for (const src of Object.values(scenes).flatMap(pair => Object.values(pair))) {
        const image = new Image();
        image.alt = '';
        image.hidden = true;
        image.draggable = false;
        this.images.set(src, image);
        this.root.querySelector('.duel-images').appendChild(image);
      }
      this.root.querySelector('.duel-next').addEventListener('click', () => this.nextTurn());
      this.root.querySelector('.duel-exit').addEventListener('click', () => this.stop());
      this.root.querySelector('.duel-create').addEventListener('click', () => this.enterRoom('create'));
      this.root.querySelector('.duel-join-form').addEventListener('submit', event => {
        event.preventDefault();
        this.enterRoom('join', this.root.querySelector('#duelRoomCode').value.trim().toUpperCase());
      });
      this.root.querySelector('.duel-start').addEventListener('click', () => this.command('start'));
      this.root.querySelector('.duel-turn-up').addEventListener('click', () => this.changeSettings(1));
      this.root.querySelector('.duel-turn-down').addEventListener('click', () => this.changeSettings(-1));
      this.root.querySelector('.duel-deathmatch').addEventListener('click', () => this.changeSettings(0, true));
      this.root.querySelector('.duel-host-confirm').addEventListener('click', () => {
        this.root.querySelector('.duel-host-left').hidden = true;
        this.showLobby();
        this.root.querySelector('.duel-create').focus();
      });
      stage.appendChild(this.root);
      this.combat = new DuelCombat(this);
    }

    prepare() {
      if (!this.preparation) {
        this.images.forEach((image, src) => { image.src = src; });
        const cards = [...this.root.querySelectorAll('.duel-seat-media img')];
        cards.forEach(image => { image.src = image.dataset.src; });
        this.preparation = Promise.all([...this.images.values(), ...cards].map(image => image.decode()).concat(this.combat.prepare()))
          .catch(error => {
            this.preparation = null;
            throw error;
          });
      }
      return this.preparation;
    }

    start() {
      this.draftSettings = null;
      this.player = 1;
      this.attacker = 1;
      this.turn = 1;
      this.active = true;
      this.generation += 1;
      this.root.hidden = false;
      this.revision = -1;
      this.guestPresent = null;
      this.roomNotice = '';
      this.root.querySelector('.duel-host-left').hidden = true;
      this.showLobby();
    }

    showLobby(message = '') {
      this.root.dataset.view = 'lobby';
      this.root.parentElement.classList.remove('duel-running');
      if (this.matchStarted) this.onMatchStop?.();
      this.matchStarted = false;
      this.cancelIntro();
      this.combat.stop();
      this.root.querySelector('.duel-lobby').hidden = false;
      this.root.querySelector('.duel-status').hidden = true;
      this.root.querySelector('.duel-footer').hidden = true;
      this.root.querySelector('.duel-player').textContent = this.session ? `${this.player}P` : 'VS MODE';
      this.root.querySelector('.duel-room-entry').hidden = Boolean(this.session);
      this.root.querySelector('.duel-room-wait').hidden = !this.session;
      this.root.querySelector('.duel-message').textContent = message;
    }

    async request(action, code, token, turn, extra = {}) {
      return TimingShooterMultiplayer.request({ ...extra, action, code, token, turn, mode: 'vs' });
    }

    async enterRoom(action, code) {
      if (!this.active || this.busy || this.session) return;
      this.busy = true;
      const generation = this.generation;
      this.root.querySelector('.duel-create').disabled = true;
      this.root.querySelector('.duel-join-form button').disabled = true;
      this.root.querySelector('.duel-message').textContent = '연결 중…';
      try {
        const data = await this.request(action, code);
        if (!this.active || generation !== this.generation) {
          this.request('leave', data.room.code, data.token).catch(() => {});
          return;
        }
        this.session = { code: data.room.code, token: data.token };
        this.draftSettings = null;
        this.player = data.player;
        this.revision = -1;
        this.guestPresent = null;
        this.roomNotice = '';
        this.applyRoom(data.room);
        this.poll();
      } catch (error) {
        if (generation === this.generation) this.showLobby(error.message);
      } finally {
        this.busy = false;
        this.root.querySelector('.duel-create').disabled = false;
        this.root.querySelector('.duel-join-form button').disabled = false;
        if (this.active && generation === this.generation && this.session && !this.matchStarted) {
          this.renderSettings(this.player === 1 ? this.draftSettings : this.roomSettings);
          this.root.querySelector('.duel-start').disabled = !this.guestPresent;
        }
      }
    }

    async poll() {
      const generation = this.generation;
      try {
        const data = await this.request('poll', this.session.code, this.session.token);
        if (this.active && generation === this.generation) this.applyRoom(data.room);
      } catch (error) {
        if (this.active && generation === this.generation) {
          if (['ROOM_CLOSED', 'INVALID_SESSION'].includes(error.code)) {
            this.session = null;
            if (this.player === 2 && error.code === 'ROOM_CLOSED') this.showHostLeft();
            else this.showLobby(error.message);
          } else if (this.matchStarted) this.combat.cue(error.message);
          else this.root.querySelector('.duel-message').textContent = error.message;
        }
      }
      if (this.active && this.session && generation === this.generation) {
        this.pollTimer = setTimeout(() => this.poll(), TimingShooterMultiplayer.pollMs);
      }
    }

    async command(action, extra = {}) {
      if (!this.active || !this.session || this.busy) return;
      this.busy = true;
      const generation = this.generation;
      const settings = action === 'start' && this.player === 1 && this.draftSettings ? { ...this.draftSettings } : null;
      if (settings) {
        this.renderSettings(settings);
        this.root.querySelector('.duel-start').disabled = true;
      }
      try {
        if (settings && (settings.turnLimit !== this.roomSettings.turnLimit || settings.deathmatch !== this.roomSettings.deathmatch)) {
          const saved = await this.request('settings', this.session.code, this.session.token, this.turn, settings);
          if (!this.active || generation !== this.generation || !this.session) return;
          this.applyRoom(saved.room);
        }
        const data = await this.request(action, this.session.code, this.session.token, this.turn, extra);
        if (this.active && generation === this.generation) this.applyRoom(data.room);
      } catch (error) {
        if (this.active && generation === this.generation) {
          if (this.matchStarted) this.combat.cue(error.message);
          else this.showLobby(error.message);
        }
      } finally {
        this.busy = false;
        if (this.active && generation === this.generation && this.session && !this.matchStarted) {
          this.renderSettings(this.player === 1 ? this.draftSettings : this.roomSettings);
          this.root.querySelector('.duel-start').disabled = !this.guestPresent;
        }
      }
    }

    applyRoom(room) {
      if (room.revision < this.revision) return;
      const changedTurn = this.turn !== room.turn;
      this.revision = room.revision;
      this.attacker = room.attacker;
      this.turn = room.turn;
      this.roomSettings = room.settings;
      const present = room.players[1].connected;
      if (present && this.guestPresent !== true) this.roomNotice = 'MAFIA가 참가했습니다.';
      else if (!present && this.guestPresent === true) this.roomNotice = 'MAFIA가 나갔습니다. 상대방을 기다리는 중입니다.';
      this.guestPresent = present;
      if (!room.started) {
        this.showLobby();
        this.root.querySelector('.duel-message').textContent = this.player === 2
          ? '방장이 시작하기를 기다리는 중입니다.' : this.roomNotice || '상대방을 기다리는 중입니다.';
        this.root.querySelector('.duel-code').textContent = room.code;
        const seat = this.root.querySelector('.duel-seat.mafia');
        seat.classList.toggle('empty', !present);
        seat.setAttribute('aria-label', present ? '2P 마피아' : '2P 대기 중');
        seat.querySelector('.duel-seat-media').hidden = !present;
        seat.querySelector('.duel-seat-name').textContent = present ? 'MAFIA' : 'WAITING';
        if (this.player === 1 && !this.draftSettings) this.draftSettings = { ...room.settings };
        this.renderSettings(this.player === 1 ? this.draftSettings : room.settings);
        const start = this.root.querySelector('.duel-start');
        start.hidden = this.player !== 1;
        start.disabled = this.busy || !room.players[1].connected;
        return;
      }
      this.root.querySelector('.duel-lobby').hidden = true;
      this.draftSettings = null;
      this.root.dataset.view = 'battle';
      this.root.parentElement.classList.add('duel-running');
      this.root.querySelector('.duel-status').hidden = false;
      this.root.querySelector('.duel-footer').hidden = true;
      this.root.querySelector('.duel-player').textContent = `${this.player}P`;
      this.render();
      if (!this.matchStarted) {
        this.matchStarted = true;
        this.playIntro();
      } else if (changedTurn && !this.introActive) this.showRoleBanner();
      this.root.querySelector('.duel-status').hidden = this.introActive;
      this.combat.update(room);
    }

    renderSettings(settings) {
      const output = this.root.querySelector('.duel-turn-limit');
      output.textContent = settings.turnLimit;
      output.setAttribute('aria-valuenow', settings.turnLimit);
      output.setAttribute('aria-disabled', String(settings.deathmatch || this.player !== 1));
      this.root.querySelector('.duel-turn-control').classList.toggle('disabled', settings.deathmatch);
      this.root.querySelector('.duel-turn-up').disabled = this.busy || this.player !== 1 || settings.deathmatch || settings.turnLimit >= 100;
      this.root.querySelector('.duel-turn-down').disabled = this.busy || this.player !== 1 || settings.deathmatch || settings.turnLimit <= 1;
      const toggle = this.root.querySelector('.duel-deathmatch');
      toggle.disabled = this.busy || this.player !== 1;
      toggle.setAttribute('aria-checked', String(settings.deathmatch));
    }

    changeSettings(delta, toggle = false) {
      if (!this.session || this.player !== 1 || this.matchStarted || this.busy) return;
      const settings = this.draftSettings || this.roomSettings;
      if (!toggle && settings.deathmatch) return;
      this.draftSettings = { turnLimit: Math.max(1, Math.min(100, settings.turnLimit + delta)),
        deathmatch: toggle ? !settings.deathmatch : settings.deathmatch };
      this.renderSettings(this.draftSettings);
    }

    showHostLeft() {
      this.root.parentElement.classList.remove('duel-running');
      this.root.dataset.view = 'lobby';
      this.onMatchStop?.();
      this.matchStarted = false;
      this.cancelIntro(); this.combat.stop();
      this.root.querySelector('.duel-lobby').hidden = false;
      this.root.querySelector('.duel-status').hidden = true;
      this.root.querySelector('.duel-host-left').hidden = false;
      this.root.querySelector('.duel-host-confirm').focus();
    }

    playIntro() {
      this.cancelIntro();
      this.introActive = true;
      this.introMusicStarted = false;
      const intro = this.root.querySelector('.duel-intro');
      intro.hidden = false;
      void intro.offsetWidth;
      intro.classList.add('playing');
      const startMusic = () => {
        if (!this.active || !this.matchStarted || this.introMusicStarted) return;
        this.introMusicStarted = true;
        this.onMatchStart?.();
      };
      // The tenth letter finishes entering at 9 * 70 + 370 = 1000 ms.
      this.introMusicTimer = setTimeout(startMusic,
        window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 1000);
      this.root.querySelector('.duel-next').disabled = true;
      this.introTimer = setTimeout(() => {
        this.cancelIntro();
        if (this.active && this.matchStarted) {
          this.showRoleBanner();
          if (this.combat.room) this.combat.update(this.combat.room);
        }
      }, 2150);
    }

    cancelIntro() {
      clearTimeout(this.introTimer);
      clearTimeout(this.introMusicTimer);
      clearTimeout(this.roleBannerTimer);
      this.root.querySelector('.duel-turn-banner').hidden = true;
      this.introTimer = null;
      this.introActive = false;
      const intro = this.root.querySelector('.duel-intro');
      intro.hidden = true;
      intro.classList.remove('playing');
      this.root.querySelector('.duel-next').disabled = false;
      if (this.matchStarted && this.active) this.root.querySelector('.duel-status').hidden = false;
    }

    showRoleBanner() {
      clearTimeout(this.roleBannerTimer);
      const banner = this.root.querySelector('.duel-turn-banner');
      const attacking = this.player === this.attacker;
      banner.textContent = `${this.player}P ${attacking ? 'ATTACK' : 'DEFENSE'}`;
      banner.dataset.role = attacking ? 'attack' : 'defense';
      banner.hidden = false;
      this.roleBannerTimer = setTimeout(() => { banner.hidden = true; }, 1200);
    }

    nextTurn() {
      if (!this.active || this.introActive) return;
      this.command('next');
    }

    render() {
      const attacking = this.player === this.attacker;
      // The viewer sees the opponent: an attacker sees cover, a defender sees aim.
      const opponent = this.player === 1 ? 'mafia' : 'police';
      const pose = attacking ? 'cover' : 'aim';
      const src = scenes[opponent][pose];
      this.images.forEach((image, path) => { image.hidden = path !== src; });
      this.root.dataset.player = String(this.player);
      this.root.dataset.attacker = String(this.attacker);
      this.root.dataset.pose = pose;
      this.root.querySelector('.duel-turn').textContent = `TURN ${this.turn} / ${this.roomSettings?.deathmatch ? '∞' : this.roomSettings?.turnLimit ?? 10}`;
      this.root.querySelector('.duel-role').textContent = attacking ? 'ATTACK' : 'DEFENSE';
      this.root.querySelector('.duel-role').dataset.role = attacking ? 'attack' : 'defense';
      this.root.dispatchEvent(new CustomEvent('duelturnchange', {
        detail: { player: this.player, attacker: this.attacker, turn: this.turn, opponent, pose, src }
      }));
    }

    policeTargetPosition(lane = 0) {
      const image = this.images.get(scenes.police.cover);
      return this.imagePosition(image, .32, lane === 0 ? .33 : .48);
    }

    muzzlePosition() {
      const police = this.player === 2;
      const image = this.images.get(scenes[police ? 'police' : 'mafia'].aim);
      return this.imagePosition(image, police ? .365 : .259, police ? .247 : .257);
    }

    imagePosition(image, anchorX, anchorY) {
      const width = this.root.clientWidth;
      const height = this.root.clientHeight;
      const scale = Math.max(width / image.naturalWidth, height / image.naturalHeight);
      const drawnWidth = image.naturalWidth * scale;
      const drawnHeight = image.naturalHeight * scale;
      // Anchor on the exposed torso; account for the background's cover crop.
      return { x: drawnWidth * anchorX + (width - drawnWidth) * .35,
        y: drawnHeight * anchorY + (height - drawnHeight) * .5 };
    }

    stop() {
      if (!this.active) return;
      this.active = false;
      this.onMatchStop?.();
      this.root.parentElement.classList.remove('duel-running');
      this.cancelIntro();
      this.combat.stop();
      this.generation += 1;
      clearTimeout(this.pollTimer);
      if (this.session) this.request('leave', this.session.code, this.session.token).catch(() => {});
      this.session = null;
      this.root.hidden = true;
      this.onExit?.();
    }
  }

  window.DuelScene = DuelScene;
})();
