class OpeningSequence {
  constructor(stage, config) {
    this.stage = stage;
    this.config = config;
    this.phase = 'idle';
    this.camera = 0.5;
    this.layer = document.createElement('section');
    this.layer.id = 'openingViewport';
    this.layer.setAttribute('aria-label', 'Mansion approach');
    this.layer.innerHTML = `
      <div class="opening-world">
        <div class="opening-scene-plane">
          <div class="opening-scenery"></div>
          <div class="opening-guard">
            <img class="opening-guard-body" alt="Mafia guard looking away">
            <div class="opening-reticle"></div>
          </div>
        </div>
      </div>
      <div class="opening-caption" aria-live="polite"></div>
      <div class="opening-shot-flash"></div>`;
    stage.prepend(this.layer);
    this.world = this.layer.querySelector('.opening-world');
    this.scenePlane = this.layer.querySelector('.opening-scene-plane');
    this.scenery = this.layer.querySelector('.opening-scenery');
    this.guard = this.layer.querySelector('.opening-guard');
    this.guardBody = this.layer.querySelector('.opening-guard-body');
    this.reticle = this.layer.querySelector('.opening-reticle');
    this.caption = this.layer.querySelector('.opening-caption');
    this.flash = this.layer.querySelector('.opening-shot-flash');
    this.fade = document.createElement('div');
    this.fade.className = 'opening-cover-fade';
    this.layer.append(this.fade);
    this.breachImages = [config.breach.onePlayerSrc, config.breach.twoPlayerSrc].map((src) => {
      const image = new Image();
      image.className = 'opening-breach-image';
      image.src = src;
      image.alt = 'Police officer kicking open the mansion door';
      this.layer.insertBefore(image, this.caption);
      return image;
    });
    this.frames = config.frames.map((frame) => {
      const image = new Image();
      image.className = 'opening-frame';
      image.src = frame.src;
      image.alt = '';
      image.focus = frame.focus;
      image.style.opacity = '1';
      this.scenery.append(image);
      return image;
    });
    this.coverImage = new Image();
    this.coverImage.className = 'opening-frame';
    this.coverImage.src = config.cover.src;
    this.coverImage.alt = '';
    this.coverImage.style.opacity = '0';
    this.scenery.append(this.coverImage);
    this.guardBody.src = config.guard.src;
    this.guard.style.left = `${config.guard.x * 100}%`;
    this.guard.style.top = `${config.guard.footY * 100}%`;
    this.guard.style.height = `${config.guard.height * 100}%`;
    this.reticle.style.top = `calc(${(1 - config.guard.aimHeight) * 100}% + ${config.guard.aimOffsetPx ?? 0}px)`;
    this.resizeObserver = new ResizeObserver(() => this.setCamera(this.camera));
    this.resizeObserver.observe(stage);
  }

  get active() { return !['idle', 'complete'].includes(this.phase); }
  get canShoot() { return this.phase === 'ready'; }

  async prepare() {
    if (!this.assetsReady) {
      this.assetsReady = Promise.all([...this.frames, this.coverImage, this.guardBody, ...this.breachImages].map((image) => image.decode()));
    }
    try {
      await this.assetsReady;
    } catch (error) {
      this.assetsReady = null;
      throw error;
    }
  }

  // Move only the camera: enemies and aiming rings keep their shared world coordinates.
  setCamera(view, durationMs = 0) {
    this.camera = Math.max(0, Math.min(1, view));
    this.world.style.transition = durationMs ? `transform ${durationMs}ms ease-in-out` : 'none';
    this.world.style.transform = `translateX(${-this.camera * this.stage.clientWidth}px)`;
  }

  delay(ms) { return new Promise((resolve) => gameRuntime.setTimeout(resolve, ms)); }

  async animate(element, keyframes, options) {
    const animation = element.animate(keyframes, options);
    await animation.finished;
    animation.commitStyles();
    animation.cancel();
  }

  renderApproach(progress) {
    const travel = Math.min(1, Math.max(0, progress));
    const eased = 1 - Math.pow(1 - travel, 2);
    const zoom = this.config.zoom.from * Math.pow(this.config.zoom.to / this.config.zoom.from, eased);
    const focus = this.frames[0].focus;
    const centers = this.config.approachCenter;
    const centerX = centers.from.x + (centers.to.x - centers.from.x) * eased;
    const centerY = centers.from.y + (centers.to.y - centers.from.y) * eased;
    const offsetX = 0.5 - centerX * zoom;
    const offsetY = 0.5 - centerY * zoom;
    this.currentZoom = zoom;
    this.scenePlane.style.transformOrigin = '0 0';
    this.scenePlane.style.transform = `translate(${offsetX * 100}%, ${offsetY * 100}%) scale(${zoom})`;
    this.reticle.style.transform = `translate(-50%, -50%) scale(${1 / zoom})`;
    this.projectedFocus = { x: offsetX + focus.x * zoom, y: offsetY + focus.y * zoom, width: focus.width * zoom };
  }

  moveToCover() {
    const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const duration = reducedMotion ? Math.min(350, this.config.travelMs) : this.config.travelMs;
    this.renderApproach(0);
    return new Promise((resolve) => {
      const start = gameRuntime.now();
      const advance = (now) => {
        const progress = Math.max(0, Math.min((now - start) / duration, 1));
        this.renderApproach(progress);
        if (progress < 1) {
          gameRuntime.requestAnimationFrame(advance);
        } else {
          resolve();
        }
      };
      gameRuntime.requestAnimationFrame(advance);
    });
  }

  async revealCover() {
    this.phase = 'transition';
    this.caption.textContent = '';
    const halfDuration = this.config.cover.fadeMs / 2;
    await this.animate(this.fade, [{ opacity: 0 }, { opacity: 1 }], {
      duration: halfDuration, easing: 'ease-in-out', fill: 'forwards'
    });
    this.frames.forEach((frame) => { frame.style.opacity = '0'; });
    this.coverImage.style.opacity = '1';
    this.scenePlane.style.transform = 'none';
    this.currentZoom = 1;
    this.reticle.style.transform = 'translate(-50%, -50%)';
    await this.animate(this.fade, [{ opacity: 1 }, { opacity: 0 }], {
      duration: halfDuration, easing: 'ease-in-out', fill: 'forwards'
    });
  }

  async play({ onShot, onComplete, onBreach, mode = '1p' }) {
    await this.prepare();
    this.onShot = onShot;
    this.onComplete = onComplete;
    this.onBreach = onBreach;
    this.mode = mode;
    this.breachImages.forEach((image) => image.classList.remove('visible'));
    this.caption.classList.remove('game-start');
    this.phase = 'approach';
    this.coverImage.style.opacity = '0';
    this.frames.forEach((frame) => { frame.style.opacity = '1'; });
    this.stage.classList.add('opening-running');
    this.layer.classList.add('visible');
    this.setCamera(0.5);
    this.caption.textContent = 'HOLD YOUR FIRE';
    await this.moveToCover();
    await this.revealCover();
    this.phase = 'cover';
    this.caption.textContent = '';
    this.guard.classList.add('visible');
    await this.delay(this.config.guardRevealMs);
    this.color = ['y', 'r', 'b', 'g'][Math.floor(Math.random() * 4)];
    this.reticle.replaceChildren(...[
      ['opening-target', `target_${this.color}`],
      ['opening-perfect', `perfect_target_${this.color}`],
      ['opening-ring', `circle_${this.color}`],
      ['opening-judge', `judge_${this.color}`]
    ].map(([className, name]) => {
      const image = new Image();
      image.className = className;
      image.src = `sprites/${name}.png`;
      image.alt = '';
      return image;
    }));
    await Promise.all([...this.reticle.children].map((image) => image.decode()));
    this.reticle.classList.add('visible');
    this.caption.textContent = 'OPEN FIRE';
    this.phase = 'ready';
    this.stage.classList.add('opening-ready');
    this.stage.querySelector(`.pad-button[data-color="${this.color}"]`).classList.add('signal-color');
  }

  shoot(color) {
    if (!this.canShoot || color !== this.color) return false;
    this.phase = 'shot';
    this.stage.classList.remove('opening-ready');
    this.stage.querySelectorAll('.signal-color').forEach((button) => button.classList.remove('signal-color'));
    this.reticle.classList.remove('visible');
    this.caption.textContent = '';
    this.onShot();
    this.animate(this.flash, [{ opacity: 0.45 }, { opacity: 0 }], { duration: 170 });
    const impact = new Image();
    impact.className = 'opening-impact';
    impact.src = 'sprites/effects/bullet_effect_1.png';
    impact.style.left = `${this.config.guard.x * 100}%`;
    impact.style.top = `calc(${(this.config.guard.footY - this.config.guard.height * this.config.guard.aimHeight) * 100}% + ${this.config.guard.aimOffsetPx ?? 0}px)`;
    impact.style.width = `${100 / this.currentZoom}px`;
    impact.style.height = `${100 / this.currentZoom}px`;
    this.scenePlane.append(impact);
    gameRuntime.setTimeout(() => { impact.src = 'sprites/effects/bullet_effect_2.png'; }, 55);
    gameRuntime.setTimeout(() => { impact.src = 'sprites/effects/bullet_effect_3.png'; }, 110);
    gameRuntime.setTimeout(() => impact.remove(), 230);
    this.animate(this.guard, [
      { transform: 'translate(-50%, -100%) rotate(0deg)', opacity: 1 },
      { transform: 'translate(-50%, -84%) rotate(-9deg)', opacity: 0 }
    ], { duration: 520, easing: 'ease-in', fill: 'forwards' });
    this.enterMansion().catch((error) => {
      console.error('[Opening] Door entry failed:', error);
      this.onComplete();
    });
    return true;
  }

  async enterMansion() {
    this.caption.textContent = 'GAME START';
    this.caption.classList.add('game-start');
    await this.delay(this.config.gameStartMs);
    const halfDuration = this.config.breach.fadeMs / 2;
    await this.animate(this.fade, [{ opacity: 0 }, { opacity: 1 }], {
      duration: halfDuration, fill: 'forwards'
    });
    this.phase = 'breach';
    this.onBreach?.();
    this.caption.classList.remove('game-start');
    this.caption.textContent = 'HOLD YOUR FIRE';
    this.breachImages[this.mode === '2p' ? 1 : 0].classList.add('visible');
    await this.animate(this.fade, [{ opacity: 1 }, { opacity: 0 }], {
      duration: halfDuration, fill: 'forwards'
    });
    await this.delay(this.config.breach.holdMs);
    await this.onComplete();
  }

  finish() {
    this.phase = 'complete';
    this.stage.classList.remove('opening-running', 'opening-ready');
    this.layer.classList.remove('visible');
  }
}

window.OpeningSequence = OpeningSequence;
