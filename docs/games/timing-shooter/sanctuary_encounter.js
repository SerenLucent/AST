class SanctuaryEncounter {
  constructor(stage, hooks) {
    this.stage = stage;
    this.hooks = hooks;
    this.layer = document.createElement('div');
    this.layer.className = 'sanctuary-encounter';
    stage.append(this.layer);
    this.palette = { r: '#ff3434', b: '#3d8cff', g: '#39ff67', y: '#ffd629' };
    this.events = [];
  }

  start(config) {
    this.cancel();
    this.config = config;
    this.active = true;
    this.cycle = 0;
    this.round = 0;
    this.progress = 0;
    this.alive = new Set((config.actorSlots ?? []).map((_, index) => index));
    this.actors = [];
    if (config.special === 'balcony') {
      for (const slot of config.actorSlots) {
        const image = new Image();
        image.className = 'sanctuary-actor';
        image.src = this.hooks.sprite();
        image.alt = '난간 뒤의 마피아';
        image.style.left = `${slot.x * 100}%`;
        this.layer.append(image);
        this.actors.push(image);
      }
    }
    this.begin(config.special === 'trap' ? 'defense' : 'attack');
  }

  begin(phase) {
    this.phase = phase;
    this.startedAt = gameRuntime.now();
    this.nextIndex = 0;
    this.resolved = 0;
    this.shots = [];
    this.phaseIndices = [...this.alive];
    this.nextShotAt = this.startedAt + (phase === 'defense' && this.isBalcony ? 600 : 0);
    this.events.push({ phase, cycle: this.cycle, round: this.round, at: this.startedAt });
    if (phase === 'attack') this.fillAttackSlots(this.startedAt);
  }

  get isBalcony() { return this.config.special === 'balcony'; }

  fillAttackSlots(now) {
    if (!this.active || this.phase !== 'attack') return;
    const capacity = this.config.maxActiveTargets ?? 3;
    while (this.shots.filter(shot => !shot.done).length < capacity && this.nextIndex < this.phaseIndices.length) {
      this.spawn(this.phaseIndices[this.nextIndex++], now);
    }
  }

  spawn(index, at) {
    const attack = this.phase === 'attack';
    const slot = attack || this.config.special === 'balcony'
      ? this.config.actorSlots[index] : this.config.warning.targets[index];
    const color = this.hooks.color(attack);
    const duration = this.isBalcony ? this.hooks.duration(attack) : this.config.shotIntervalMs;
    const element = document.createElement('div');
    element.className = attack ? 'sanctuary-attack' : 'sanctuary-counter';
    element.style.setProperty('--shot-color', this.palette[color]);
    if (attack) {
      element.innerHTML = `<img src="sprites/target_${color}.png" alt=""><img class="sanctuary-ring" src="sprites/circle_${color}.png" alt="">`;
    } else {
      element.innerHTML = '<div class="sanctuary-counter-frame"></div><div class="sanctuary-counter-growing"></div>';
      const dodge = this.hooks.dodgeConfig();
      element.style.setProperty('--dodge-margin', `${dodge.marginPx}px`);
      element.querySelector('.sanctuary-counter-growing').style.inset = `${dodge.startMarginPx}px`;
    }
    this.layer.append(element);
    const shot = { index, color, slot, element, at, duration, perfectAt: at + duration, attack };
    this.shots.push(shot);
    this.events.push({ phase: this.phase, index, at });
  }

  update(now) {
    if (!this.active) return;
    if (this.isBalcony) this.actors.forEach((actor, index) => {
      actor.style.left = `${this.hooks.screenX(this.config.actorSlots[index].x)}px`;
    });
    if (this.isBalcony) {
      if (this.phase === 'attack') this.fillAttackSlots(now);
      else if (!this.shots.some(shot => !shot.done) && this.nextIndex < this.phaseIndices.length && now >= this.nextShotAt) {
        this.spawn(this.phaseIndices[this.nextIndex++], now);
      }
    } else while (this.nextIndex < 6 && now >= this.startedAt + this.nextIndex * this.config.shotIntervalMs) {
      this.spawn(this.nextIndex, this.startedAt + this.nextIndex * this.config.shotIntervalMs);
      this.nextIndex++;
    }
    for (const shot of [...this.shots]) {
      if (shot.done) continue;
      if (shot.attack) {
        shot.element.style.left = `${this.hooks.screenX(shot.slot.x)}px`;
        shot.element.style.top = `${shot.slot.y * this.stage.clientHeight}px`;
        const scale = 1 + 1.8 * Math.max(0, (shot.perfectAt - now) / shot.duration);
        shot.element.querySelector('.sanctuary-ring').style.transform = `translate(-50%, -50%) scale(${scale})`;
      } else {
        const inset = DodgeSequence.insetAt(this.hooks.dodgeConfig(), shot.perfectAt - now, shot.duration);
        shot.element.querySelector('.sanctuary-counter-growing').style.inset = `${inset}px`;
        if (!shot.flashed && now >= shot.perfectAt) this.flash(shot);
      }
      if (now > shot.perfectAt + this.window('bad', shot.attack)) this.resolve(shot, 'miss');
    }
    for (const flash of this.layer.querySelectorAll('.sanctuary-muzzle')) {
      flash.style.left = `${this.hooks.screenX(Number(flash.dataset.x))}px`;
    }
    this.advance();
  }

  window(grade, attack) {
    return this.hooks.window(grade, attack);
  }

  press(color) {
    if (!this.active) return false;
    const now = gameRuntime.now();
    const available = this.shots.filter(shot => !shot.done);
    const candidates = available.filter(shot => shot.color === color);
    const shot = (candidates.length ? candidates : available)
      .sort((a,b) => Math.abs(a.perfectAt - now) - Math.abs(b.perfectAt - now))[0];
    if (!shot) return true;
    const grade = shot.color !== color ? 'miss' : ['perfect','great','good','bad']
      .find(key => Math.abs(now - shot.perfectAt) <= this.window(key, shot.attack)) ?? 'miss';
    if (this.hooks.shotgun() && shot.attack && grade !== 'miss') {
      available.forEach((target, index) => this.resolve(target, grade, { silentSound: index > 0 }));
    } else this.resolve(shot, grade);
    this.advance();
    return true;
  }

  flash(shot) {
    shot.flashed = true;
    const image = new Image();
    image.src = 'sprites/effects/bullet_effect_1.png';
    image.className = 'sanctuary-muzzle';
    image.dataset.x = shot.slot.x;
    image.style.left = `${this.hooks.screenX(shot.slot.x)}px`;
    image.style.top = `${shot.slot.y * 100}%`;
    this.layer.append(image);
    gameRuntime.setTimeout(() => image.remove(), 130);
  }

  resolve(shot, grade, options = {}) {
    if (!this.active || shot.done) return;
    shot.done = true;
    shot.element.remove();
    this.resolved++;
    if (shot.attack) {
      if (grade !== 'miss') {
        this.alive.delete(shot.index);
        this.progress++;
        this.actors[shot.index].style.opacity = '0';
      }
      this.hooks.attack(grade, shot, options);
    } else {
      if (!shot.flashed) this.flash(shot);
      this.hooks.defend(grade);
      if (this.isBalcony) this.nextShotAt = gameRuntime.now() + this.hooks.defenseHoldMs();
      if (this.config.special === 'trap') this.progress++;
    }
    if (grade !== 'miss' && this.active) {
      const feedback = document.createElement('div');
      feedback.className = 'sanctuary-feedback';
      feedback.style.setProperty('--shot-color', this.palette[shot.color]);
      this.layer.append(feedback);
      gameRuntime.setTimeout(() => feedback.remove(), 220);
    }
    this.hooks.progress(this.progress);
  }

  advance() {
    if (!this.active) return;
    if (this.isBalcony) {
      if (this.phase === 'attack') this.fillAttackSlots(gameRuntime.now());
      if (this.nextIndex < this.phaseIndices.length || this.resolved < this.phaseIndices.length) return;
      if (!this.alive.size) {
        if (this.round + 1 < (this.config.rounds ?? 1)) {
          this.round++;
          this.alive = new Set(this.config.actorSlots.map((_, index) => index));
          this.actors.forEach(actor => { actor.style.opacity = '1'; });
          this.begin('attack');
        } else { this.cancel(); this.hooks.complete(); }
        return;
      }
      if (this.phase === 'attack' && this.alive.size) this.begin('defense');
      else if (this.phase === 'defense' && gameRuntime.now() >= this.nextShotAt) {
        this.cycle++;
        this.begin('attack');
      }
    } else if (this.nextIndex === 6 && this.resolved === 6) {
      this.cancel(); this.hooks.complete();
    }
  }

  cancel() {
    this.active = false;
    this.layer.replaceChildren();
    this.shots = [];
    this.actors = [];
  }
}
window.SanctuaryEncounter = SanctuaryEncounter;
