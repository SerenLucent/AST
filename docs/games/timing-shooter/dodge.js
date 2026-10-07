class DodgeSequence {
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
    const count = this.queue.filter((target) => target.element.isConnected).length + (this.active ? 1 : 0);
    this.ammo.replaceChildren(...Array.from({ length: count }, () => {
      const bullet = document.createElement('span');
      bullet.className = 'dodge-bullet';
      const cartridge = document.createElement('span');
      cartridge.className = 'dodge-cartridge';
      bullet.append(cartridge);
      return bullet;
    }));
    this.ammo.setAttribute('aria-label', `${count} incoming bullets`);
  }

  startNext() {
    if (this.current) return;
    const target = this.queue.shift();
    if (!target) return;
    if (!target.element.isConnected) {
      this.startNext();
      return;
    }
    const colors = Object.keys(this.colors);
    const color = colors[Math.floor(Math.random() * colors.length)];
    const { min, max } = this.config.durationMs;
    const duration = min + Math.random() * (max - min);
    this.current = { target, color, duration, perfectTime: gameRuntime.now() + duration, resolved: false };
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
    const remaining = shot.perfectTime - now;
    const margin = this.config.marginPx;
    // Move each edge by the same pixel distance, not a percentage of the rectangle size.
    const inset = remaining >= 0
      ? margin + (this.config.startMarginPx - margin) * (remaining / shot.duration)
      : margin * (1 + remaining / this.config.judgementMs.bad);
    this.growing.style.transform = 'none';
    this.growing.style.inset = `${Math.max(0, inset)}px`;
    this.layer.classList.toggle('timing-zone', Math.abs(remaining) <= this.config.judgementMs.great);
    if (remaining < -this.config.judgementMs.bad) this.resolve('miss');
  }

  press(color) {
    if (!this.active) return false;
    const shot = this.current;
    const distance = Math.abs(gameRuntime.now() - shot.perfectTime);
    const judgement = color === shot.color
      ? Object.keys(this.config.judgementMs).find((key) => distance <= this.config.judgementMs[key]) || 'miss'
      : 'miss';
    this.resolve(judgement);
    return true;
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
    const appliedDamage = this.onResolve(shot.target, damage, judgement) ?? damage;
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
    this.current = null;
    this.layer.classList.remove('visible', 'timing-zone', 'dodge-success', 'dodge-miss');
    this.startNext();
    this.renderAmmo();
    if (notifyIdle && !this.current && this.queue.length === 0) this.onIdle();
  }

  clear() {
    this.queue = [];
    this.clearCurrent(false);
  }
}

window.DodgeSequence = DodgeSequence;
