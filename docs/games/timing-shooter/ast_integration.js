window.AST_GAME_CONFIG = { embedded: true };
window.AST_GAME_CONFIG = window.AST_GAME_CONFIG || { embedded: false };
window.astSubmitClearScore = function (result) {
  if (!window.AST_GAME_CONFIG.embedded || !window.AstGameScores?.postMessage) return;
  window.AstGameScores.postMessage(JSON.stringify({
    type: 'stageClear', game: 'timing-shooter', stageId: 'stage1', revision: 1,
    runId: window.astGameRunId, ...result
  }));
};
window.astGameRunId = window.crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`;
