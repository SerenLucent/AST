class WharfOpeningSequence {
  constructor(stage, config) {
    this.stage = stage;
    this.config = config;
    this.phase = 'idle';
    this.layer = document.createElement('section');
    this.layer.id = 'wharfOpeningViewport';
    this.layer.className = 'wharf-opening';
    this.layer.hidden = true;
    this.layer.setAttribute('aria-label', '검은 부두 침투');
    this.layer.innerHTML = `<img class="wharf-opening-background" alt="검은 부두 진입로">
      <img class="wharf-foreman" alt="상자 위에서 담배를 피우는 밀수단원">
      <canvas class="wharf-foreman-fall" width="627" height="700" hidden></canvas>
      <div class="opening-reticle wharf-reticle"></div>
      <img class="wharf-entry" alt="경찰이 부두 안쪽으로 전진한다" hidden>
      <div class="opening-caption" aria-live="polite"></div>
      <div class="opening-shot-flash"></div>`;
    this.background = this.layer.querySelector('.wharf-opening-background');
    this.guardBody = this.layer.querySelector('.wharf-foreman');
    this.fall = this.layer.querySelector('.wharf-foreman-fall');
    this.entry = this.layer.querySelector('.wharf-entry');
    this.reticle = this.layer.querySelector('.opening-reticle');
    this.caption = this.layer.querySelector('.opening-caption');
    this.flash = this.layer.querySelector('.opening-shot-flash');
    this.shotEffect = new OpeningShotEffect(this.layer, this.flash);
    this.knockdownImage = new Image();
    if (config.label) {
      this.layer.setAttribute('aria-label', config.label);
      this.background.alt = config.label;
      this.guardBody.alt = `${config.label}를 지키는 경비`;
      this.entry.alt = `경찰이 ${config.label}로 진입한다`;
    }
    for (const [element, layout] of [[this.guardBody, config.guardLayout], [this.fall, config.fallLayout], [this.reticle, config.reticleLayout]]) {
      if (layout) for (const [key, value] of Object.entries(layout)) element.style[key] = `${value}%`;
    }
    if (config.guardLayout) this.guardBody.style.objectFit = 'contain';
    this.fall.width = config.canvasWidth ?? 627;
    this.fall.height = config.canvasHeight ?? 700;
    stage.prepend(this.layer);
  }

  get active() { return !['idle', 'complete'].includes(this.phase); }
  get canShoot() { return this.phase === 'ready'; }
  delay(ms) { return new Promise(resolve => gameRuntime.setTimeout(resolve, ms)); }

  prepare() {
    if (!this.assetsReady) {
      this.background.src = this.config.background;
      this.guardBody.src = this.config.idle;
      this.knockdownImage.src = this.config.knockdown;
      this.entry.src = this.config.entry;
      this.assetsReady = Promise.all([this.shotEffect.prepare(), ...[this.background, this.guardBody, this.knockdownImage, this.entry].map(image => image.decode())])
        .catch(error => { this.assetsReady = null; throw error; });
    }
    return this.assetsReady;
  }

  async play({ mode = '1p', onShot, onBreach, onComplete, transition }) {
    await this.prepare();
    this.entry.src = mode === '2p' && this.config.entryCoop ? this.config.entryCoop : this.config.entry;
    await this.entry.decode();
    this.onShot = onShot;
    this.onBreach = onBreach;
    this.onComplete = onComplete;
    this.transition = transition;
    this.phase = 'approach';
    this.guardBody.hidden = false;
    this.fall.hidden = true;
    this.entry.hidden = true;
    this.caption.classList.remove('game-start');
    this.caption.classList.remove('hold-fire-art');
    this.caption.textContent = '';
    this.layer.hidden = false;
    this.stage.classList.add('opening-running');
    await this.delay(this.config.revealMs);
    this.color = ['y', 'r', 'b', 'g'][Math.floor(Math.random() * 4)];
    this.reticle.replaceChildren(...[['opening-target', 'target'], ['opening-perfect', 'perfect_target'],
      ['opening-ring', 'circle'], ['opening-judge', 'judge']].map(([className, prefix]) => {
      const image = new Image();
      image.src = `sprites/${prefix}_${this.color}.png`;
      image.className = className;
      image.alt = '';
      return image;
    }));
    await Promise.all([...this.reticle.children].map(image => image.decode()));
    this.reticle.classList.add('visible');
    this.caption.textContent = 'OPEN FIRE';
    this.phase = 'ready';
    this.stage.classList.add('opening-ready');
    this.stage.querySelector(`.pad-button[data-color="${this.color}"]`).classList.add('signal-color');
  }

  shoot(color) {
    if (!this.canShoot || color !== this.color) return false;
    this.phase = 'shot';
    this.caption.textContent = '';
    this.reticle.classList.remove('visible');
    this.stage.classList.remove('opening-ready');
    this.stage.querySelectorAll('.signal-color').forEach(button => button.classList.remove('signal-color'));
    this.onShot?.();
    this.shotEffect.play(this.reticle);
    this.guardBody.hidden = true;
    this.fall.hidden = false;
    this.enterWharf().catch(error => {
      console.error('[Wharf opening] Entry failed:', error);
      this.onComplete?.();
    });
    return true;
  }

  async enterWharf() {
    const context = this.fall.getContext('2d');
    for (let index = 0; index < this.config.frames.length; index++) {
      const frame = this.config.frames[index];
      context.clearRect(0, 0, this.fall.width, this.fall.height);
      context.drawImage(this.knockdownImage, ...frame.rect, 0, frame.offset, frame.rect[2], frame.rect[3]);
      this.fall.style.top = `${frame.top}%`;
      this.fall.dataset.frame = String(index);
      await this.delay(frame.durationMs);
    }
    this.caption.textContent = 'GAME START';
    this.caption.classList.add('game-start');
    await this.delay(700);
    const showEntry = () => {
      this.phase = 'transition';
      this.caption.textContent = '';
      this.caption.classList.remove('game-start');
      this.onBreach?.();
      this.fall.hidden = true;
      this.entry.hidden = false;
      if (this.config.captionArt) this.caption.classList.add('hold-fire-art');
    };
    if (this.transition) await this.transition(showEntry);
    else showEntry();
    await this.delay(this.config.entryHoldMs);
    await this.onComplete?.();
  }

  finish() {
    this.shotEffect.clear();
    this.phase = 'complete';
    this.layer.hidden = true;
    this.caption.textContent = '';
    this.reticle.classList.remove('visible');
    this.stage.classList.remove('opening-running', 'opening-ready');
    this.stage.querySelectorAll('.signal-color').forEach(button => button.classList.remove('signal-color'));
  }
}
