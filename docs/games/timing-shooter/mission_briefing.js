async function animateModeCard(card, slot, reveal, host) {
  await card.animate([
    { borderColor: '#ffd84a', boxShadow: '0 0 28px #ffd84a' },
    { borderColor: 'transparent', boxShadow: 'none' },
    { borderColor: '#ffd84a', boxShadow: '0 0 28px #ffd84a' }
  ], { duration: 300, iterations: 2 }).finished;
  const start = card.getBoundingClientRect();
  const fly = card.cloneNode(true);
  fly.removeAttribute('id');
  fly.disabled = true;
  fly.className = 'mission-flying-card';
  const flight = document.createElement('div');
  flight.className = 'mission-card-flight';
  flight.append(fly);
  host.append(flight);
  reveal();
  const end = slot.getBoundingClientRect();
  const parent = host.getBoundingClientRect();
  Object.assign(flight.style, { left: `${end.left - parent.left}px`, top: `${end.top - parent.top}px`, width: `${end.width}px`, height: `${end.height}px` });
  const dx = start.left + start.width / 2 - end.left - end.width / 2;
  const dy = start.top + start.height / 2 - end.top - end.height / 2;
  const timing = { duration: 850, easing: 'cubic-bezier(.22,.7,.25,1)', fill: 'forwards' };
  try {
    // Move the center independently so spinning cannot swing the flight path.
    await Promise.all([
      flight.animate([
        { transform: `translate(${dx}px, ${dy}px) scale(${start.width / end.width}, ${start.height / end.height})` },
        { transform: 'translate(0, 0) scale(1)' }
      ], timing).finished,
      fly.animate([{ transform: 'rotateY(0deg)' }, { transform: 'rotateY(360deg)' }], timing).finished
    ]);
    const portrait = document.createElement('img');
    portrait.src = card.querySelector('img').src;
    portrait.alt = card.getAttribute('aria-label') || '';
    slot.replaceChildren(portrait);
  } finally { flight.remove(); }
}

class MissionBriefing {
  constructor(screen, onLaunch) {
    this.screen = screen;
    this.active = false;
    this.busy = false;
    this.selectedStage = 1;
    this.root = document.createElement('section');
    this.root.className = 'mission-briefing';
    this.root.hidden = true;
    this.root.setAttribute('aria-label', '1P 수사 브리핑');
    this.root.innerHTML = `
      <header class="mission-heading"><button type="button" class="mission-back" aria-label="모드 선택으로 돌아가기" title="뒤로"><img src="sprites/UI/back_arrow_gold_v1.png" alt=""><span>Back</span></button><h2>수사 브리핑</h2></header>
      <div class="mission-card-slot"></div>
      <figure class="mission-board"><img src="backgrounds/mission_briefing_v3.png" alt="주인공 경찰이 마피아 수장을 가리킨다. 아래의 저택 보스와 흰머리 보스 사진으로 스테이지를 선택한다.">
        <button type="button" class="mission-stage mission-stage-one mission-stage-selected" data-stage="1" aria-label="1스테이지 마피아 저택" aria-pressed="true" title="STAGE 1 · 마피아 저택"></button>
        <button type="button" class="mission-stage mission-stage-two" data-stage="2" aria-label="2스테이지 검은 부두" aria-pressed="false" title="STAGE 2 · 검은 부두"></button>
        <span class="mission-lock mission-lock-chief" role="img" aria-label="마피아 수장 스테이지 잠김" title="준비 중"><i></i></span>
        <span class="mission-lock mission-lock-third" role="img" aria-label="세 번째 보스 스테이지 잠김" title="준비 중"><i></i></span>
      </figure>
      <div class="mission-operation"><span>STAGE 1</span><strong>마피아 저택</strong></div>
      <button type="button" class="mission-launch">소탕 작전</button>`;
    screen.append(this.root);
    this.slot = this.root.querySelector('.mission-card-slot');
    this.launch = this.root.querySelector('.mission-launch');
    this.root.querySelectorAll('[data-stage]').forEach(button => button.addEventListener('click', () => {
      if (this.busy || this.launch.disabled) return;
      this.selectStage(Number(button.dataset.stage));
    }));
    this.root.querySelector('.mission-back').addEventListener('click', () => this.close());
    this.launch.addEventListener('click', async () => {
      if (this.busy || this.launch.disabled) return;
      this.launch.disabled = true;
      try { await onLaunch(this.selectedStage); } finally { this.launch.disabled = false; }
    });
  }

  selectStage(stage) {
    this.selectedStage = stage === 2 ? 2 : 1;
    this.root.querySelectorAll('[data-stage]').forEach(button => {
      const selected = Number(button.dataset.stage) === this.selectedStage;
      button.classList.toggle('mission-stage-selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    this.root.querySelector('.mission-operation span').textContent = `STAGE ${this.selectedStage}`;
    this.root.querySelector('.mission-operation strong').textContent = this.selectedStage === 2 ? '검은 부두' : '마피아 저택';
  }

  restore(card, stageNumber = 1) {
    this.selectStage(stageNumber);
    const portrait = document.createElement('img');
    portrait.src = card.querySelector('img').src;
    portrait.alt = card.getAttribute('aria-label') || '';
    this.slot.replaceChildren(portrait);
    this.root.hidden = false;
    this.screen.classList.add('mission-open');
    this.active = true;
    this.launch.focus({ preventScroll: true });
  }

  async open(card) {
    if (this.active || this.busy) return;
    this.busy = true;
    this.screen.classList.add('mission-transition');
    try {
      const art = this.root.querySelector('.mission-board img');
      await art.decode().catch(() => {});
      await animateModeCard(card, this.slot, () => {
        this.root.hidden = false;
        this.screen.classList.add('mission-open');
      }, this.screen);
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
