class HallScene {
  constructor(stage, config) {
    this.stage = stage;
    this.config = config;
    this.camera = 0.5;
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
    this.observer = new ResizeObserver(() => this.setCamera(this.camera));
    this.observer.observe(stage);
  }

  prepare() { return Promise.all(this.images.map((image) => image.decode())); }

  setCamera(view) {
    this.camera = Math.max(0, Math.min(1, view));
    const transform = `translateX(${-this.camera * this.stage.clientWidth}px)`;
    this.background.style.transform = transform;
    this.foreground.style.transform = transform;
    this.frontColumns.style.transform = transform;
    if (this.defeated) this.setDefeatOrigin();
    this.onCameraChange?.();
  }

  screenX(worldX) { return (worldX * 2 - this.camera) * this.stage.clientWidth; }

  setDefeatOrigin() {
    const focusX = ((this.camera + 0.5) / 2) * 100;
    this.images.forEach((image) => { image.style.transformOrigin = `${focusX}% 100%`; });
  }

  playDefeat() {
    this.defeated = true;
    this.setDefeatOrigin();
    this.stage.classList.add('game-over');
  }
}

window.HallScene = HallScene;
