window.TIMING_SHOOTER_CONFIG = {
  spawnDurationMs: {
    min: 1000,
    max: 5000
  },
  waveTargets: 2,
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
  judgeCueMs: {
    showBeforePerfect: 100,
    hideAfterPerfect: 80
  },
  autoMissMs: 440,
  dodge: {
    durationMs: { min: 1600, max: 2800 },
    judgementMs: { perfect: 120, great: 260, good: 400, bad: 560 },
    damage: { perfect: 0, great: 0, good: 2, bad: 5, miss: 10 },
    startMarginPx: 48,
    marginPx: 8,
    resultHoldMs: 500
  },
  targetHoldMs: 600
};
