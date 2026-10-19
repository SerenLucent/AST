class Hostage {
  constructor(stage, getHall, onHit) {
    this.stage = stage;
    this.getHall = getHall;
    this.onHit = onHit;
    this.color = null;
    this.hit = false;
  }

  prepare(config) {
    return Promise.all([config.crouch, config.fallen].map(src => {
      const image = new Image();
      image.src = src;
      return image.decode();
    }));
  }

  enter(config, secondPlayer = false) {
    this.clear();
    if (!config) return;
    this.config = config;
    this.slot = secondPlayer ? config.slot2p : config.slot;
    this.hit = false;
    this.element = document.createElement('div');
    this.element.className = 'hostage';
    this.element.setAttribute('aria-label', 'Civilian hostage');
    this.body = new Image();
    this.body.className = 'hostage-body';
    this.body.src = config.crouch;
    this.body.alt = 'Frightened civilian crouching with hands over his head';
    this.reticle = document.createElement('div');
    this.reticle.className = 'hostage-reticle';
    this.reticle.hidden = true;
    this.rings = ['circle', 'perfect_target', 'target'].map(prefix => {
      const image = new Image();
      image.className = `hostage-${prefix}`;
      image.alt = '';
      image.dataset.prefix = prefix;
      this.reticle.append(image);
      return image;
    });
    this.cross = document.createElement('div');
    this.cross.className = 'hostage-cross';
    this.cross.setAttribute('aria-label', 'Hostage shot');
    this.cross.hidden = true;
    this.element.append(this.body, this.reticle, this.cross);
    this.stage.append(this.element);
    this.position();
  }

  position() {
    if (!this.element) return;
    const height = this.stage.clientHeight * this.slot.heightRatio;
    let x = this.getHall().screenX(this.slot.worldX);
    if (this.hit) x = Math.max(height * 0.7, Math.min(this.stage.clientWidth - height * 0.7, x));
    this.element.style.left = `${x}px`;
    this.element.style.top = `${this.stage.clientHeight * this.slot.footY}px`;
    this.element.style.width = `${height}px`;
    this.element.style.height = `${height}px`;
    this.x = x;
    this.y = this.stage.clientHeight * this.slot.footY - height * 0.55;
  }

  refreshColor(targets, change = true, excluded = []) {
    if (!this.element || this.hit) return;
    const used = new Set([...targets.map(target => target.color), ...excluded]);
    if (!change && this.color && !used.has(this.color)) return;
    const available = ['b', 'g', 'r', 'y'].filter(color => !used.has(color));
    const different = available.filter(color => color !== this.color);
    const choices = different.length ? different : available;
    this.color = choices[Math.floor(Math.random() * choices.length)] ?? null;
    this.rings.forEach(image => { if (this.color) image.src = `sprites/${image.dataset.prefix}_${this.color}.png`; });
    this.reticle.dataset.color = this.color ?? '';
    this.setEnabled(this.enabled);
  }

  setEnabled(enabled) {
    this.enabled = Boolean(enabled);
    if (this.reticle) this.reticle.hidden = !this.enabled || !this.color || this.hit;
  }

  press(color) {
    if (!this.element || this.hit || !this.enabled || color !== this.color) return false;
    this.hit = true;
    this.setEnabled(false);
    this.body.src = this.config.fallen;
    this.body.alt = 'Collapsed civilian hostage';
    this.element.classList.add('hostage-fallen');
    this.cross.hidden = false;
    this.position();
    this.onHit(this);
    this.removeTimer = gameRuntime.setTimeout(() => {
      this.element?.remove();
      this.element = null;
    }, this.config.hitHoldMs);
    return true;
  }

  clear() {
    gameRuntime.clearTimeout(this.removeTimer);
    this.element?.remove();
    this.element = null;
    this.color = null;
    this.enabled = false;
  }
}

window.Hostage = Hostage;

class HostageGroup {
  constructor(stage, getHall, onHit) {
    this.stage = stage;
    this.getHall = getHall;
    this.onHit = onHit;
    this.members = [];
  }
  get primary() { return this.members.find(member => member.element && !member.hit) ?? this.members.find(member => member.element); }
  get element() { return this.primary?.element ?? null; }
  get hit() { return !this.members.some(member => member.element && !member.hit); }
  get color() { return this.primary?.color ?? null; }
  set color(value) { this.members.forEach(member => { member.color = value; }); }
  get body() { return this.primary?.body; }
  get reticle() { return this.primary?.reticle; }
  get cross() { return this.primary?.cross; }
  get slot() { return this.primary?.slot; }
  get x() { return this.primary?.x; }
  get y() { return this.primary?.y; }
  prepare(config) {
    const definitions = Array.isArray(config) ? config : config ? [config] : [];
    return Promise.all(definitions.map(definition => new Hostage(this.stage, this.getHall, this.onHit).prepare(definition)));
  }
  enter(config, secondPlayer = false) {
    this.clear();
    const definitions = Array.isArray(config) ? config : config ? [config] : [];
    this.members = definitions.map(definition => {
      const member = new Hostage(this.stage, this.getHall, this.onHit);
      member.enter(definition, secondPlayer);
      return member;
    });
  }
  position() { this.members.forEach(member => member.position()); }
  refreshColor(targets, change = true, excluded = []) {
    const primary = this.primary;
    if (!primary || primary.hit) return;
    primary.refreshColor(targets, change, excluded);
    // Staff share one reserved color, leaving room for enemy and supply colors.
    for (const member of this.members) {
      if (member === primary || member.hit || !member.element) continue;
      member.color = primary.color;
      member.rings.forEach(image => { if (member.color) image.src = `sprites/${image.dataset.prefix}_${member.color}.png`; });
      member.reticle.dataset.color = member.color ?? '';
      member.setEnabled(member.enabled);
    }
  }
  setEnabled(enabled) { this.members.forEach(member => member.setEnabled(enabled)); }
  press(color) {
    const member = this.members.find(entry => entry.element && !entry.hit && entry.enabled && entry.color === color);
    return member ? member.press(color) : false;
  }
  clear() { this.members.forEach(member => member.clear()); this.members = []; }
}
window.HostageGroup = HostageGroup;
