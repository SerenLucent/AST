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
    const transform = `translateX(${-(this.camera + this.dodgeOffset) * this.stage.clientWidth}px)`;
    this.background.style.transform = transform;
    this.foreground.style.transform = transform;
    this.frontColumns.style.transform = transform;
    if (this.defeated) this.setDefeatOrigin();
    this.onCameraChange?.();
  }

  screenX(worldX) { return (worldX * 2 - this.camera - this.dodgeOffset) * this.stage.clientWidth; }

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
