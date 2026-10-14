(function (root) {
  const config = {
    durationBySpeed: { 1: 600, 2: 700, 3: 800, 4: 900, 5: 1000 },
    judgementReferenceDuration: { 1: 650, 2: 800, 3: 950, 4: 1100, 5: 1250 },
    judgementMs: { perfect: 80, great: 180, good: 300, bad: 440 },
    dodgeJudgementMs: { perfect: 80, great: 160, good: 260, bad: 380 },
    attackDamage: { perfect: 10, great: 7, good: 4, bad: 1, miss: 0 },
    dodgeMultiplier: { perfect: 0, great: 0, good: .2, bad: .5, miss: 1 },
    colors: ['b', 'g', 'y', 'r'],
    shotCount: { min: 3, max: 6 },
    initialHp: 100, countdownMs: 2000, betweenShotsMs: 500, resultMs: 3000,
    timingWindows(speed, defense = false) {
      const ratio = (this.durationBySpeed[speed] ?? 1000) / (this.judgementReferenceDuration[speed] ?? 1000);
      const base = defense ? this.dodgeJudgementMs : this.judgementMs;
      return Object.fromEntries(Object.entries(base).map(([grade, ms]) => [grade, Math.round(ms * ratio)]));
    },
    grade(delta, correct, defense = false, speed) {
      if (!correct || !Number.isFinite(delta)) return 'miss';
      const windows = this.timingWindows(speed, defense);
      return Object.keys(windows).find(key => Math.abs(delta) <= windows[key]) || 'miss';
    }
  };
  if (typeof module === 'object') module.exports = config;
  else root.DUEL_CONFIG = config;
})(typeof window === 'object' ? window : globalThis);
