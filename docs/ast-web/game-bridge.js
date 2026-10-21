(() => {
  'use strict';
  const kind = location.pathname.includes('/ast-home/') ? 'ast-home' : 'timing-shooter';
  const channel = 'ast-web-' + kind;
  const target = location.origin;
  if (parent === window) return;
  const post = data => parent.postMessage(JSON.stringify({channel, ...data}), target);
  if (kind === 'ast-home') {
    window.AstHome = {postMessage(raw) {
      const data = JSON.parse(raw);
      post({id: data.id, payload: data.payload});
    }};
  } else {
    window.AstGameScores = {postMessage(raw) {
      const data = JSON.parse(raw);
      if (data.type === 'exitGame') { post({exit: true}); return; }
      post({id: data.runId || crypto.randomUUID(), payload: data});
    }};
  }
  window.addEventListener('message', event => {
    if (event.source !== parent || event.origin !== target || typeof event.data !== 'string') return;
    let data; try {data = JSON.parse(event.data)} catch {return}
    if (data.channel !== channel) return;
    if (kind === 'ast-home') window.astHomeResponse?.(data);
    else if (data.error) {
      // Do not claim the score was saved when the server rejected it.
      let message = document.getElementById('ast-web-save-error');
      if (!message) {message = document.createElement('p'); message.id='ast-web-save-error'; message.setAttribute('role','alert'); document.body.appendChild(message)}
      message.textContent = '점수 저장 실패: ' + data.error;
      message.style.cssText = 'position:fixed;bottom:0;left:0;right:0;z-index:999999;background:#fff3e0;color:#842d0c;padding:12px;font:14px sans-serif';
    }
  });
})();
