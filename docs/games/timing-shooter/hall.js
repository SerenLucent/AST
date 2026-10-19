class HallScene {
  constructor(stage, config) {
    this.stage = stage;
    this.config = config;
    this.camera = 0.5;
    this.dodgeOffset = 0;
    this.background = document.createElement('div');
    this.background.className = 'hall-world hall-background';
    this.foreground = document.createElement('div');
    this.foreground.className = 'hall-world hall-foreground';
    this.frontColumns = document.createElement('div');
    this.frontColumns.className = 'hall-world hall-front-columns';
    this.images = [];
    const addImage = (parent, occluder = null) => {
      const image = new Image();
      image.src = config.background;
      image.alt = '';
      if (config.backgroundFit) {
        image.style.objectFit = config.backgroundFit;
        image.style.objectPosition = `${(config.backgroundPositionX ?? .5) * 100}% center`;
      }
      if (occluder) {
        image.dataset.occluder = occluder.id;
        image.style.clipPath = `polygon(${occluder.polygon})`;
      }
      parent.append(image);
      this.images.push(image);
    };
    addImage(this.background);
    config.occluders.forEach((occluder) => addImage(occluder.depth === 4 ? this.frontColumns : this.foreground, occluder));
    stage.prepend(this.background, this.foreground, this.frontColumns);
    if (config.singleView) [this.background, this.foreground, this.frontColumns].forEach(layer => { layer.style.width = '100%'; });
    this.setCamera(0.5);
    this.observer = new ResizeObserver(() => this.renderCamera());
    this.observer.observe(stage);
  }

  prepare() {
    if (!this.assetsReady) {
      this.assetsReady = Promise.all(this.images.map((image) => image.decode())).catch((error) => {
        this.assetsReady = null;
        throw error;
      });
    }
    return this.assetsReady;
  }

  setCamera(view) {
    this.camera = Math.max(0, Math.min(1, view));
    this.dodgeMotion = null;
    this.dodgeOffset = 0;
    this.renderCamera();
  }

  renderCamera() {
    const transform = `translateX(${-(this.config.singleView ? this.dodgeOffset : this.camera + this.dodgeOffset) * this.stage.clientWidth}px)`;
    this.background.style.transform = transform;
    this.foreground.style.transform = transform;
    this.frontColumns.style.transform = transform;
    if (this.defeated) this.setDefeatOrigin();
    this.onCameraChange?.();
  }

  project(x, y, withDodge = true) {
    const width = this.stage.clientWidth, height = this.stage.clientHeight;
    const image = this.images[0];
    const scale = Math.max(width / image.naturalWidth, height / image.naturalHeight);
    const drawnWidth = image.naturalWidth * scale, drawnHeight = image.naturalHeight * scale;
    return { x: x * drawnWidth + (width - drawnWidth) * (this.config.backgroundPositionX ?? .5)
      - (withDodge ? this.dodgeOffset * width : 0), y: y * drawnHeight + (height - drawnHeight) * .5 };
  }

  screenX(worldX) {
    if (this.config.backgroundFit === 'cover') return this.project(worldX, 0).x;
    return (this.config.singleView ? worldX - this.dodgeOffset : worldX * 2 - this.camera - this.dodgeOffset) * this.stage.clientWidth;
  }

  playBossHit() {
    if (!this.config.boss?.embedded) return;
    if (!this.hitImage) {
      this.hitImage = new Image();
      this.hitImage.src = this.config.background;
      this.hitImage.alt = '';
      this.hitImage.style.objectFit = 'cover';
      this.hitImage.style.objectPosition = `${this.config.backgroundPositionX * 100}% center`;
      this.background.append(this.hitImage);
    }
    // Reuse the baked pose; this clipped recoil highlight never resizes the column.
    const points = [[.245,.188],[.307,.188],[.314,.238],[.307,.425],[.285,.56],
      [.211,.57],[.21,.545],[.23,.48],[.235,.386],[.213,.35],[.217,.255]];
    this.hitImage.style.clipPath = `polygon(${points.map(([x,y]) => {
      const point = this.project(x,y,false);return `${point.x}px ${point.y}px`;
    }).join(',')})`;
    this.hitAnimation?.cancel();
    this.hitAnimation = this.hitImage.animate([
      { opacity: 0, transform: 'translateX(0)', filter: 'brightness(1)' },
      { opacity: .9, transform: 'translateX(-3px)', filter: 'brightness(1.5)' },
      { opacity: .5, transform: 'translateX(2px)', filter: 'brightness(1.15)' },
      { opacity: 0, transform: 'translateX(0)', filter: 'brightness(1)' }
    ], { duration: 180, fill: 'forwards' });
  }

  playDodge(direction = 1) {
    if (this.defeated) return;
    // End views always lean toward the other half of the shared map.
    const inward = this.camera === 1 ? -1 : this.camera === 0 ? 1 : Math.sign(direction);
    this.dodgeMotion = { start: gameRuntime.now(), from: this.dodgeOffset,
      peak: Math.max(-this.camera, Math.min(1 - this.camera, inward * 0.09)) };
  }

  updateDodge(now) {
    const motion = this.dodgeMotion;
    if (!motion) return;
    const elapsed = Math.max(0, now - motion.start);
    const outMs = 80;
    const holdMs = 90;
    const backMs = 330;
    if (elapsed < outMs) {
      const progress = elapsed / outMs;
      const eased = 1 - (1 - progress) ** 3;
      this.dodgeOffset = motion.from + (motion.peak - motion.from) * eased;
    } else if (elapsed < outMs + holdMs) {
      this.dodgeOffset = motion.peak;
    } else {
      const progress = Math.min(1, (elapsed - outMs - holdMs) / backMs);
      const eased = progress * progress * (3 - 2 * progress);
      this.dodgeOffset = motion.peak * (1 - eased);
    }
    if (elapsed >= outMs + holdMs + backMs) {
      this.dodgeOffset = 0;
      this.dodgeMotion = null;
    }
    this.renderCamera();
  }

  cancelDodge() {
    this.dodgeMotion = null;
    this.dodgeOffset = 0;
    this.renderCamera();
  }

  destroy() {
    this.hitAnimation?.cancel();
    this.observer.disconnect();
    this.background.remove();
    this.foreground.remove();
    this.frontColumns.remove();
  }

  setDefeatOrigin() {
    const focusX = ((this.camera + 0.5) / 2) * 100;
    this.images.forEach((image) => { image.style.transformOrigin = `${focusX}% 100%`; });
  }

  playDefeat() {
    this.cancelDodge();
    this.defeated = true;
    this.setDefeatOrigin();
    this.stage.classList.add('game-over');
  }
}

window.HallScene = HallScene;
