class OpeningShotEffect {
  constructor(layer, flash, assetRoot = '') {
    this.layer = layer;
    this.flash = flash;
    this.timers = [];
    this.sources = [
      'sprites/effects/bullet_effect_1.png',
      'sprites/effects/bullet_effect_2.png',
      'sprites/effects/bullet_effect_3.png'
    ].map(src => `${assetRoot}${src}`);
  }

  prepare() {
    if (!this.ready) {
      this.images = this.sources.map(src => Object.assign(new Image(), { src }));
      this.ready = Promise.all(this.images.map(image => image.decode()))
        .catch(error => { this.ready = null; throw error; });
    }
    return this.ready;
  }

  play(anchor) {
    this.clear();
    const bounds = this.layer.getBoundingClientRect();
    const target = anchor.getBoundingClientRect();
    const impact = new Image();
    impact.className = 'opening-impact';
    impact.alt = '';
    impact.src = this.sources[0];
    impact.style.left = `${target.left + target.width / 2 - bounds.left}px`;
    impact.style.top = `${target.top + target.height / 2 - bounds.top}px`;
    this.layer.append(impact);
    this.impact = impact;
    this.animation = this.flash.animate([{ opacity: .45 }, { opacity: 0 }], { duration: 170 });
    for (const [delay, callback] of [
      [55, () => { impact.src = this.sources[1]; }],
      [110, () => { impact.src = this.sources[2]; }],
      [230, () => { impact.remove(); if (this.impact === impact) this.impact = null; }]
    ]) this.timers.push(gameRuntime.setTimeout(callback, delay));
  }

  clear() {
    this.timers.forEach(timer => gameRuntime.clearTimeout(timer));
    this.timers = [];
    this.animation?.cancel();
    this.impact?.remove();
    this.impact = null;
  }
}

window.OpeningShotEffect = OpeningShotEffect;
