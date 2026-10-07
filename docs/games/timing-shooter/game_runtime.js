class GameRuntime {
  constructor() {
    this.paused = false;
    this.offset = 0;
    this.nextId = 1;
    this.timers = new Map();
    this.frames = new Map();
  }

  now() { return (this.paused ? this.pausedAt : performance.now()) - this.offset; }

  setTimeout(callback, delay = 0, ...args) {
    const id = this.nextId++;
    const timer = { callback, args, due: this.now() + Math.max(0, delay), handle: null };
    this.timers.set(id, timer);
    if (!this.paused) this.armTimer(id, timer);
    return id;
  }

  armTimer(id, timer) {
    timer.handle = window.setTimeout(() => {
      this.timers.delete(id);
      timer.callback(...timer.args);
    }, Math.max(0, timer.due - this.now()));
  }

  clearTimeout(id) {
    const timer = this.timers.get(id);
    if (timer) window.clearTimeout(timer.handle);
    this.timers.delete(id);
  }

  requestAnimationFrame(callback) {
    const id = this.nextId++;
    const frame = { callback, handle: null };
    this.frames.set(id, frame);
    if (!this.paused) this.armFrame(id, frame);
    return id;
  }

  armFrame(id, frame) {
    frame.handle = window.requestAnimationFrame(() => {
      this.frames.delete(id);
      frame.callback(this.now());
    });
  }

  cancelAnimationFrame(id) {
    const frame = this.frames.get(id);
    if (frame) window.cancelAnimationFrame(frame.handle);
    this.frames.delete(id);
  }

  pause() {
    if (this.paused) return;
    this.pausedAt = performance.now();
    this.paused = true;
    this.timers.forEach(timer => window.clearTimeout(timer.handle));
    this.frames.forEach(frame => window.cancelAnimationFrame(frame.handle));
  }

  resume() {
    if (!this.paused) return;
    this.offset += performance.now() - this.pausedAt;
    this.paused = false;
    this.timers.forEach((timer, id) => this.armTimer(id, timer));
    this.frames.forEach((frame, id) => this.armFrame(id, frame));
  }
}
window.gameRuntime = new GameRuntime();
