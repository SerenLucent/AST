window.TIMING_SHOOTER_CONFIG = {
  spawnDurationMs: {
    min: 1000,
    max: 5000
  },
  waveTargets: 2,
  targetRevealDelayMs: 700,
  respawnDelayMs: { min: 2000, max: 3000 },
  judgementMs: {
    perfect: 80,
    great: 180,
    good: 300,
    bad: 440
  },
  damageByJudgement: {
    perfect: { min: 90, max: 100 },
    great: { min: 70, max: 89 },
    good: { min: 40, max: 69 },
    bad: { min: 0, max: 40 },
    miss: { min: 0, max: 0 }
  },
  hpDamageByJudgement: { bad: 1, good: 2, great: 3, perfect: 4, miss: 0 },
  powerUpHpBonus: 1,
  judgeCueMs: {
    showBeforePerfect: 100,
    hideAfterPerfect: 80
  },
  autoMissMs: 440,
  dodge: {
    durationMs: { min: 650, max: 1800 },
    judgementMs: { perfect: 80, great: 160, good: 260, bad: 380 },
    damage: { perfect: 0, great: 0, good: 2, bad: 5, miss: 10 },
    startMarginPx: 88,
    marginPx: 8,
    resultHoldMs: 500
  },
  targetHoldMs: 600
};
