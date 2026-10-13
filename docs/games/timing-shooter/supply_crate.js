class SupplyCrate {
  constructor(stage, getHall, onHit, onReward) {
    this.stage = stage;
    this.getHall = getHall;
    this.onHit = onHit;
    this.onReward = onReward;
    this.atlasSrc = 'sprites/items/supply_crate_atlas_v1.png';
    this.maxHits = 10;
    this.resetRoom(22, 2);
  }

  prepare() {
    const image = new Image();
    image.src = this.atlasSrc;
    return image.decode();
  }

  resetRoom(enemyTotal, enemiesPerTurn) {
    this.clear();
    this.turn = 0;
    this.lastSpawnTurn = Math.ceil(enemyTotal / enemiesPerTurn) - 3;
    const pairs = [];
    for (let first = 2; first <= this.lastSpawnTurn - 3; first++) {
      for (let second = first + 3; second <= this.lastSpawnTurn; second++) pairs.push([first, second]);
    }
    this.spawnTurns = pairs.length ? pairs[Math.floor(Math.random() * pairs.length)]
      : this.lastSpawnTurn >= 2 ? [2] : [];
  }

  nextTurn(targets, excluded = []) {
    this.turn++;
    if (this.element && this.turn >= this.expiresTurn) this.clear();
    const used = new Set([...targets.map(target => target.color), ...excluded]);
    // Reserve a non-red color so equipping Magnum cannot conflict with the crate.
    const choices = ['b', 'g', 'y'].filter(color => !used.has(color));
    if (this.element) return;
    if (!this.spawnTurns.includes(this.turn)) return;
    if (!choices.length) return;
    this.color = choices[Math.floor(Math.random() * choices.length)];
    this.hits = 0;
    this.expiresTurn = this.turn + 2;
    this.element = document.createElement('div');
    this.element.className = 'supply-crate';
    this.element.setAttribute('aria-label', 'Supply crate');
    this.body = document.createElement('div');
    this.body.className = 'supply-crate-body';
    this.body.style.backgroundImage = `url("${this.atlasSrc}")`;
    this.reticle = document.createElement('div');
    this.reticle.className = 'supply-crate-reticle';
    for (const prefix of ['circle', 'perfect_target', 'target']) {
      const image = new Image();
      image.src = `sprites/${prefix}_${this.color}.png`;
      image.className = `supply-crate-${prefix}`;
      image.alt = '';
      this.reticle.append(image);
    }
    this.prompt = document.createElement('div');
    this.prompt.className = 'supply-crate-prompt';
    this.prompt.hidden = true;
    const button = new Image();
    button.src = `sprites/target_${this.color}.png`;
    button.alt = '';
    const label = document.createElement('strong');
    label.textContent = 'PUSH';
    this.prompt.append(button, label);
    this.cue = document.createElement('div');
    this.cue.className = 'supply-crate-cue';
    const title = document.createElement('strong');
    title.textContent = 'BREAK IT!';
    const arrow = document.createElement('span');
    arrow.className = 'supply-crate-arrow';
    arrow.setAttribute('aria-hidden', 'true');
    this.cue.append(title, arrow);
    this.element.append(this.body, this.reticle, this.prompt, this.cue);
    this.stage.append(this.element);
    this.worldX = (this.getHall().camera + 0.5) / 2;
    this.position();
    this.renderDamage();
  }

  position() {
    if (!this.element) return;
    const size = Math.min(112, this.stage.clientHeight * 0.125);
    this.x = this.getHall().screenX(this.worldX);
    this.y = this.stage.clientHeight * 0.69;
    this.element.style.left = `${this.x}px`;
    this.element.style.top = `${this.y}px`;
    this.element.style.width = this.element.style.height = `${size}px`;
  }

  renderDamage() {
    const frame = Math.min(4, Math.floor(this.hits * 4 / this.maxHits));
    this.body.dataset.frame = frame;
    this.body.style.backgroundPosition = `${(frame % 3) * 50}% ${Math.floor(frame / 3) * 100}%`;
    const outlines = [
      '7% 27%, 29% 19%, 86% 23%, 94% 26%, 94% 73%, 78% 87%, 7% 74%',
      '7% 27%, 29% 19%, 86% 23%, 94% 26%, 94% 73%, 78% 87%, 7% 74%',
      '7% 27%, 29% 19%, 86% 23%, 94% 26%, 94% 73%, 78% 87%, 7% 74%',
      '10% 24%, 32% 20%, 89% 26%, 94% 80%, 77% 89%, 5% 77%',
      '8% 60%, 16% 54%, 16% 32%, 22% 27%, 48% 36%, 65% 38%, 85% 54%, 99% 74%, 80% 88%, 7% 85%, 0% 77%'
    ];
    this.body.style.clipPath = `polygon(${outlines[frame]})`;
  }

  setEnabled(enabled) {
    this.enabled = Boolean(enabled);
    if (this.reticle) this.reticle.hidden = !this.enabled || this.hits >= this.maxHits;
    if (this.prompt) {
      this.prompt.hidden = !this.enabled || this.hits >= this.maxHits;
      this.prompt.classList.toggle('rapid', gameRuntime.now() < (this.promptUntil ?? 0));
    }
    if (this.cue) this.cue.hidden = !this.enabled || this.hits >= this.maxHits;
  }

  press(color) {
    if (this.element && this.hits >= this.maxHits && color === this.color) return true;
    if (!this.element || !this.enabled || this.hits >= this.maxHits || color !== this.color) return false;
    this.hits++;
    this.promptUntil = gameRuntime.now() + 2000;
    this.renderDamage();
    this.onHit(this);
    if (this.hits === this.maxHits) {
      this.setEnabled(false);
      this.onReward({ x: this.x, y: this.y });
      this.removeTimer = gameRuntime.setTimeout(() => this.clear(), 350);
    } else this.setEnabled(true);
    return true;
  }

  clear() {
    gameRuntime.clearTimeout(this.removeTimer);
    this.element?.remove();
    this.element = null;
    this.color = null;
    this.enabled = false;
    this.promptUntil = 0;
  }
}
window.SupplyCrate = SupplyCrate;
