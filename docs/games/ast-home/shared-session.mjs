const PREFIX = 'ast-home-pending-v2:';
const ID = /^[a-zA-Z0-9_-]{16,80}$/;
const ACCOUNT = /^[a-f0-9]{64}$/;
const RESULTS = new Set(['applied', 'already_applied', 'conflict', 'insufficient']);

// Account keys come from the native session, never from saved pending data.
// The old ast-home-pending-v1 entry has no owner: retain it, but NEVER replay it.
export class SharedHomeSession {
  constructor({request, storage, createId = () => crypto.randomUUID()}) {
    this.request = request;
    this.storage = storage;
    this.createId = createId;
    this.accountKey = null;
    this.running = false;
  }

  validate(result) {
    if (!ACCOUNT.test(result?.accountKey || '')) {
      throw new Error('AST 앱을 최신 버전으로 업데이트한 뒤 다시 입장해 주세요.');
    }
    if (this.accountKey && result.accountKey !== this.accountKey) {
      throw new Error('계정이 변경되었습니다. 집 꾸미기에 다시 입장해 주세요.');
    }
    if (!Number.isSafeInteger(result.balance) || result.balance < 0 ||
        !Number.isSafeInteger(result.home?.revision) || result.home.revision < 0 ||
        !Array.isArray(result.home.items)) {
      throw new Error('서버 응답 형식을 확인해 주세요.');
    }
    return result;
  }

  get key() {
    if (!this.accountKey) throw new Error('먼저 현재 계정의 잔액을 불러와 주세요.');
    return PREFIX + this.accountKey;
  }

  pending() {
    const raw = this.storage.getItem(this.key);
    if (!raw) return null;
    const entry = JSON.parse(raw);
    const p = entry?.payload;
    if (entry?.version !== 2 || entry.accountKey !== this.accountKey ||
        p?.accountKey !== this.accountKey || p.action !== 'astHomeApply' ||
        !ID.test(p.requestId || '') ||
        !['purchase', 'move'].includes(p.operation) || !p.item ||
        !Number.isSafeInteger(p.expectedRevision) || p.expectedRevision < 0) {
      throw new Error('미완료 구매 기록의 계정을 확인할 수 없어 재시도하지 않았습니다.');
    }
    return p;
  }

  async sendPending(payload) {
    let result;
    try {
      result = await this.request(payload);
    } catch {
      // Retain the original request ID even if the first response was lost.
      result = await this.request(payload);
    }
    this.validate(result);
    if (!RESULTS.has(result.status)) throw new Error('구매 결과를 확인하지 못했습니다.');
    if (this.pending()?.requestId === payload.requestId) {
      this.storage.removeItem(this.key);
    }
    return result;
  }

  async sync(onSnapshot = () => {}) {
    if (this.running) throw new Error('진행 중인 요청을 기다려 주세요.');
    this.running = true;
    try {
      // Fetch this login's authoritative balance BEFORE looking for its retry.
      const current = this.validate(await this.request({action: 'astHomeGet'}));
      this.accountKey = current.accountKey;
      onSnapshot(current);
      const pending = this.pending();
      if (!pending) return current;
      const recovered = await this.sendPending(pending);
      onSnapshot(recovered);
      return recovered;
    } finally {
      this.running = false;
    }
  }

  async commit(item, purchase, revision) {
    if (this.running) throw new Error('진행 중인 요청을 기다려 주세요.');
    this.running = true;
    try {
      if (this.pending()) throw new Error('미완료 구매가 있습니다. 집 꾸미기에 다시 입장해 주세요.');
      const payload = {
        action: 'astHomeApply', accountKey: this.accountKey,
        operation: purchase ? 'purchase' : 'move', item,
        expectedRevision: revision, requestId: this.createId(),
      };
      // If durable storage is unavailable, do not attempt the purchase.
      this.storage.setItem(this.key, JSON.stringify({
        version: 2, accountKey: this.accountKey, payload,
      }));
      return await this.sendPending(payload);
    } finally {
      this.running = false;
    }
  }
}
