window.TIMING_SHOOTER_OPENING = {
  // One world is two portrait viewports wide; cameras use 0 (left), 0.5 (center), 1 (right).
  worldSize: { width: 1720, height: 1860 },
  // Keep one painting for the entire approach; the scene camera supplies the movement.
  frames: [
    {
      src: 'backgrounds/opening/single/mansion_wide_3440x3720.webp',
      focus: { x: 0.5, y: 0.435, width: 0.061 }
    }
  ],
  // Half of the two-screen world fits the entire opening painting in one viewport.
  zoom: { from: 0.5, to: 1 },
  approachCenter: {
    from: { x: 0.5, y: 0.5 },
    // Keep the left gate pillar in view, with the entrance to its right.
    to: { x: 0.34, y: 0.5 }
  },
  travelMs: 750,
  cover: {
    src: 'backgrounds/opening/single/lamp_cover_3440x3720.webp',
    fadeMs: 500
  },
  guardRevealMs: 120,
  guard: {
    src: 'sprites/enemies/mafia_gate_guard.png',
    x: 0.518,
    footY: 0.622,
    height: 0.16,
    aimHeight: 0.55,
    aimOffsetPx: -5
  },
  gameStartMs: 700,
  breach: {
    onePlayerSrc: 'backgrounds/opening/breach/door_kick_1p.webp',
    twoPlayerSrc: 'backgrounds/opening/breach/door_kick_2p.webp',
    holdMs: 2000,
    fadeMs: 500
  }
};
