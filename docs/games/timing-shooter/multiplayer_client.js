(() => {
  const config = window.TIMING_SHOOTER_MULTIPLAYER;
  let serial = 0;
  function jsonp(parameters) {
    return new Promise((resolve, reject) => {
      const callback = `__tsmp_${Date.now()}_${++serial}`;
      const script = document.createElement('script');
      const url = new URL(config.endpoint);
      Object.entries({ ...parameters, callback }).forEach(([key, value]) => url.searchParams.set(key, value));
      let timer;
      const cleanup = () => {
        clearTimeout(timer); script.remove();
        // A timed-out request can still arrive from Google's redirect.
        window[callback] = () => {};
        setTimeout(() => delete window[callback], 60000);
      };
      window[callback] = data => { cleanup(); resolve(data); };
      script.onerror = () => { cleanup(); reject(new Error('멀티플레이 서버 연결을 재시도합니다.')); };
      script.referrerPolicy = 'no-referrer';
      script.src = url.href;
      timer = setTimeout(() => { cleanup(); reject(new Error('멀티플레이 서버 응답이 늦습니다.')); }, config.timeoutMs);
      document.head.append(script);
    });
  }
  function checked(data) {
    if (data.error) {
      const error = new Error(data.error); error.code = data.code; throw error;
    }
    return data;
  }
  const client = {
    get cloud() { return Boolean(config.endpoint); },
    get pollMs() { return this.cloud ? config.pollMs : 300; },
    async request(input) {
      if (!this.cloud) {
        const response = await fetch('/api/duel', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(input), signal: AbortSignal.timeout(8000)
        });
        if (!(response.headers.get('content-type') || '').includes('application/json')) throw new Error('방 서버에 연결할 수 없습니다.');
        return checked(await response.json());
      }
      if (!/^https:\/\/script\.google\.com\/macros\/s\/[A-Za-z0-9_-]+\/exec$/.test(config.endpoint)) {
        throw new Error('멀티플레이 Apps Script 배포 주소를 확인해 주세요.');
      }
      if (input.action === 'poll') return checked(await jsonp({ action: 'poll', code: input.code, token: input.token }));
      const requestId = input.requestId || crypto.randomUUID();
      const body = JSON.stringify({ ...input, requestId });
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          // Simple POST avoids a CORS preflight; the secret receipt is read via JSONP.
          await fetch(config.endpoint, { method: 'POST', mode: 'no-cors', credentials: 'omit',
            headers: { 'Content-Type': 'text/plain;charset=UTF-8' }, body,
            signal: AbortSignal.timeout(config.timeoutMs) });
          for (let read = 0; read < 4; read++) {
            const data = await jsonp({ action: 'receipt', requestId });
            if (!data.pending) return checked(data);
            await new Promise(resolve => setTimeout(resolve, 700));
          }
        } catch (error) {
          if (error.code || attempt === 1) throw error;
        }
      }
      throw new Error('서버 응답을 받지 못했습니다. 다시 시도해 주세요.');
    },
    create(mode = 'vs') { return this.request({ action: 'create', mode }); },
    join(code, mode = 'vs') { return this.request({ action: 'join', code, mode }); },
    shareCoopResult(session, battle, result) {
      return this.request({ action: 'coopResult', ...session, battle, result });
    }
  };
  window.TimingShooterMultiplayer = client;
})();
