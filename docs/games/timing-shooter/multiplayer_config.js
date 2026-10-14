window.TIMING_SHOOTER_MULTIPLAYER = Object.assign({
  // Separate deployment from the public ranking service.
  endpoint: 'https://script.google.com/macros/s/AKfycbw3jUmpOuLkm8x8AJPE-yCJ602R7IfCRSmkIoISTivG_9WXPhX5iQwLZufVOQmGlggWSQ/exec',
  pollMs: 2000,
  timeoutMs: 20000
}, window.TIMING_SHOOTER_MULTIPLAYER || {});
