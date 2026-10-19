class DodgeSequence {
  static insetAt(config, remaining, duration) {
    const margin = config.marginPx;
    const inset = remaining >= 0
      ? margin + (config.startMarginPx - margin) * (remaining / duration)
      : margin * (1 + remaining / config.judgementMs.bad);
    return Math.max(0, inset);
  }

  constructor(stage, config, onResolve, onIdle = () => {}) {
    this.stage = stage;
    this.config = config;
    this.onResolve = onResolve;
    this.onIdle = onIdle;
    this.queue = [];
    this.current = null;
    this.colors = { y: '#ffd629', g: '#39ff67', b: '#3d8cff', r: '#ff3434' };
    this.layer = document.createElement('div');
    this.layer.className = 'dodge-layer';
    this.layer.innerHTML = '<div class="dodge-frame"></div><div class="dodge-growing"></div><div class="dodge-ammo"></div><div class="dodge-result"></div>';
    this.layer.style.setProperty('--dodge-margin', `${config.marginPx}px`);
    stage.append(this.layer);
    this.growing = this.layer.querySelector('.dodge-growing');
    this.result = this.layer.querySelector('.dodge-result');
    this.ammo = this.layer.querySelector('.dodge-ammo');
  }

  get active() { return Boolean(this.current && !this.current.resolved); }

  enqueue(target) {
    this.enqueueBatch([target]);
  }

  enqueueBatch(targets) {
    targets.forEach((target) => {
      if (this.current?.target !== target && !this.queue.includes(target)) this.queue.push(target);
    });
    this.startNext();
    this.renderAmmo();
  }

  renderAmmo() {
    const shotsFor = target => Math.max(1, Math.floor(target.dodgeShotCount ?? 1));
    const count = this.queue.filter((target) => target.element.isConnected)
      .reduce((sum, target) => sum + shotsFor(target), 0)
      + (this.current && this.current.target.element.isConnected
        ? this.current.shotsRemaining - (this.current.resolved ? 1 : 0) : 0);
    this.ammo.replaceChildren(...Array.from({ length: count }, () => {
      const bullet = document.createElement('span');
      bullet.className = 'dodge-bullet';
      const cartridge = document.createElement('img');
      cartridge.className = 'dodge-cartridge';
      cartridge.src = 'sprites/UI/dodge_bullet_gold_v2.png';
      cartridge.alt = '';
      cartridge.draggable = false;
      bullet.append(cartridge);
      return bullet;
    }));
    this.ammo.setAttribute('aria-label', `${count} incoming bullets`);
  }

  startNext(continuation = null) {
    if (this.current) return;
    const target = continuation?.target ?? this.queue.shift();
    if (!target) return;
    if (!target.element.isConnected) {
      this.startNext();
      return;
    }
    const colors = Object.keys(this.colors);
    const color = colors[Math.floor(Math.random() * colors.length)];
    const { min, max } = this.config.durationMs;
    const duration = target.dodgeDurationMs ?? (min + Math.random() * (max - min));
    const startedAt = gameRuntime.now();
    const flipColors = colors.filter(candidate => candidate !== color);
    this.current = { target, color, duration, startedAt, perfectTime: startedAt + duration, resolved: false,
      shotsRemaining: continuation?.shotsRemaining ?? Math.max(1, Math.floor(target.dodgeShotCount ?? 1)),
      colorChangeProgress: target.dodgeColorChangeProgress,
      flipColor: flipColors[Math.floor(Math.random() * flipColors.length)], colorChanged: false };
    this.layer.style.setProperty('--dodge-color', this.colors[color]);
    this.result.textContent = '';
    this.layer.classList.remove('dodge-success', 'dodge-miss');
    this.growing.style.display = '';
    this.layer.classList.add('visible');
    this.renderAmmo();
    this.update(gameRuntime.now());
  }

  update(now) {
    if (!this.active) return;
    const shot = this.current;
    if (!shot.target.element.isConnected) {
      this.clearCurrent();
      return;
    }
    this.updateColor(now);
    const remaining = shot.perfectTime - now;
    // Move each edge by the same pixel distance, not a percentage of the rectangle size.
    this.growing.style.transform = 'none';
    this.growing.style.inset = `${DodgeSequence.insetAt(this.config, remaining, shot.duration)}px`;
    this.layer.classList.toggle('timing-zone', Math.abs(remaining) <= this.config.judgementMs.great);
    if (remaining < -this.config.judgementMs.bad) this.resolve('miss');
  }

  press(color) {
    if (!this.active) return false;
    this.updateColor(gameRuntime.now());
    const shot = this.current;
    const distance = Math.abs(gameRuntime.now() - shot.perfectTime);
    const judgement = color === shot.color
      ? Object.keys(this.config.judgementMs).find((key) => distance <= this.config.judgementMs[key]) || 'miss'
      : 'miss';
    this.resolve(judgement);
    return true;
  }

  updateColor(now) {
    const shot = this.current;
    if (!shot || shot.resolved || shot.colorChanged || shot.colorChangeProgress == null
        || now < shot.startedAt + shot.duration * shot.colorChangeProgress) return;
    shot.colorChanged = true;
    shot.color = shot.flipColor;
    this.layer.style.setProperty('--dodge-color', this.colors[shot.color]);
  }

  resolve(judgement) {
    if (!this.active) return;
    const shot = this.current;
    shot.resolved = true;
    this.renderAmmo();
    const damage = this.config.damage[judgement];
    this.growing.style.display = judgement === 'miss' ? '' : 'none';
    this.layer.classList.remove('timing-zone');
    this.layer.classList.add(judgement === 'miss' ? 'dodge-miss' : 'dodge-success');
    const appliedDamage = this.onResolve(shot.target, damage, judgement,
      { finalShot: shot.shotsRemaining === 1 }) ?? damage;
    if (this.current !== shot) return;
    const label = document.createElement('div');
    label.className = 'dodge-result-label';
    label.textContent = `${judgement[0].toUpperCase()}${judgement.slice(1)}`;
    const life = document.createElement('div');
    life.className = 'dodge-result-life';
    life.textContent = `Life -${appliedDamage}`;
    this.result.replaceChildren(label, life);
    const resultColors = { perfect: '#ffd629', great: '#39ff67', good: '#3d8cff', bad: '#b15cff', miss: '#ff3434' };
    this.result.style.color = resultColors[judgement];
    this.holdTimer = gameRuntime.setTimeout(() => this.clearCurrent(), this.config.resultHoldMs);
  }

  clearCurrent(notifyIdle = true) {
    gameRuntime.clearTimeout(this.holdTimer);
    const shot = this.current;
    const continuation = notifyIdle && shot?.resolved && shot.shotsRemaining > 1
      && shot.target.element.isConnected
      ? { target: shot.target, shotsRemaining: shot.shotsRemaining - 1 } : null;
    this.current = null;
    this.layer.classList.remove('visible', 'timing-zone', 'dodge-success', 'dodge-miss');
    this.startNext(continuation);
    this.renderAmmo();
    if (notifyIdle && !this.current && this.queue.length === 0) this.onIdle();
  }

  clear() {
    this.queue = [];
    this.clearCurrent(false);
  }
}

window.DodgeSequence = DodgeSequence;
