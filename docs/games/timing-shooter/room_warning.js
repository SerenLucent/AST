class RoomWarning {
  constructor(stage, runtime = window.gameRuntime) {
    this.runtime = runtime;
    this.layer = document.createElement('section');
    this.layer.className = 'room-warning';
    this.layer.hidden = true;
    this.layer.setAttribute('role', 'status');
    stage.append(this.layer);
  }

  show(config) {
    this.clear();
    const banner = document.createElement('div');
    banner.className = 'room-warning-banner';
    banner.textContent = 'WARNING';
    this.layer.replaceChildren(banner);
    this.layer.setAttribute('aria-label', '경고: 양쪽 벽의 총구를 조심하세요');
    for (const target of config.targets) {
      const arrow = document.createElement('span');
      arrow.className = `room-warning-arrow ${target.x < .5 ? 'points-left' : 'points-right'}`;
      arrow.style.left = `${target.x * 100}%`;
      arrow.style.top = `${target.y * 100}%`;
      arrow.setAttribute('aria-hidden', 'true');
      this.layer.append(arrow);
    }
    this.layer.hidden = false;
    return new Promise(resolve => {
      this.resolve = resolve;
      this.timer = this.runtime.setTimeout(() => this.clear(true), config.durationMs ?? 2200);
    });
  }

  clear(completed = false) {
    this.runtime.clearTimeout(this.timer);
    this.layer.hidden = true;
    this.layer.replaceChildren();
    const resolve = this.resolve;
    this.resolve = null;
    resolve?.(completed);
  }
}
window.RoomWarning = RoomWarning;
