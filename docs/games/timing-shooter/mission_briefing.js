class MissionBriefing {
  constructor(screen, onLaunch) {
    this.screen = screen;
    this.active = false;
    this.busy = false;
    this.root = document.createElement('section');
    this.root.className = 'mission-briefing';
    this.root.hidden = true;
    this.root.setAttribute('aria-label', '1P 수사 브리핑');
    this.root.innerHTML = `
      <header class="mission-heading"><button type="button" class="mission-back" aria-label="모드 선택으로 돌아가기" title="뒤로">&#8592;</button><h2>수사 브리핑</h2></header>
      <div class="mission-card-slot"></div>
      <figure class="mission-board"><img src="backgrounds/mission_briefing_v3.png" alt="주인공 경찰이 긴 지시봉으로 맨 위 마피아 수장을 가리킨다. 보스 사진들은 모두 보이며, 왼쪽 아래 노란 네온 테두리는 1스테이지 보스다.">
        <button type="button" class="mission-stage-selected" aria-label="1스테이지 마피아 저택 선택됨" aria-pressed="true" title="STAGE 1 · 마피아 저택"></button>
        <span class="mission-lock mission-lock-chief" role="img" aria-label="마피아 수장 스테이지 잠김" title="준비 중"><i></i></span>
        <span class="mission-lock mission-lock-second" role="img" aria-label="두 번째 보스 스테이지 잠김" title="준비 중"><i></i></span>
        <span class="mission-lock mission-lock-third" role="img" aria-label="세 번째 보스 스테이지 잠김" title="준비 중"><i></i></span>
      </figure>
      <div class="mission-operation"><span>STAGE 1</span><strong>마피아 저택</strong></div>
      <button type="button" class="mission-launch">소탕 작전</button>`;
    screen.append(this.root);
    this.slot = this.root.querySelector('.mission-card-slot');
    this.launch = this.root.querySelector('.mission-launch');
    this.root.querySelector('.mission-back').addEventListener('click', () => this.close());
    this.launch.addEventListener('click', async () => {
      if (this.busy || this.launch.disabled) return;
      this.launch.disabled = true;
      try { await onLaunch(); } finally { this.launch.disabled = false; }
    });
  }

  async open(card) {
    if (this.active || this.busy) return;
    this.busy = true;
    this.screen.classList.add('mission-transition');
    try {
      const art = this.root.querySelector('img');
      await Promise.all([
        art.decode().catch(() => {}),
        card.animate([
          { borderColor: '#ffd84a', boxShadow: '0 0 28px #ffd84a' },
          { borderColor: 'transparent', boxShadow: 'none' },
          { borderColor: '#ffd84a', boxShadow: '0 0 28px #ffd84a' }
        ], { duration: 300, iterations: 2 }).finished
      ]);
      const start = card.getBoundingClientRect();
      const fly = card.cloneNode(true);
      fly.removeAttribute('id');
      fly.disabled = true;
      fly.className = 'mission-flying-card';
      this.screen.append(fly);
      this.root.hidden = false;
      this.screen.classList.add('mission-open');
      const end = this.slot.getBoundingClientRect();
      const parent = this.screen.getBoundingClientRect();
      Object.assign(fly.style, { left: `${end.left - parent.left}px`, top: `${end.top - parent.top}px`, width: `${end.width}px`, height: `${end.height}px` });
      await fly.animate([
        { transform: `translate(${start.left - end.left}px, ${start.top - end.top}px) scale(${start.width / end.width}) rotateY(0deg)` },
        { transform: 'translate(0, 0) scale(1) rotateY(360deg)' }
      ], { duration: 850, easing: 'cubic-bezier(.22,.7,.25,1)', fill: 'forwards' }).finished;
      const portrait = document.createElement('img');
      portrait.src = card.querySelector('img').src;
      portrait.alt = '1P MODE';
      this.slot.replaceChildren(portrait);
      fly.remove();
      this.active = true;
      this.launch.focus({ preventScroll: true });
    } finally {
      this.busy = false;
      this.screen.classList.remove('mission-transition');
    }
  }

  close() {
    if (this.busy) return;
    this.active = false;
    this.root.hidden = true;
    this.slot.replaceChildren();
    this.screen.classList.remove('mission-open');
    this.screen.querySelector('[data-mode="1p"]').focus({ preventScroll: true });
  }
}
