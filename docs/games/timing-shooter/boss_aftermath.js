class BossAftermath {
  constructor(stage, getHall) {
    this.stage = stage;
    this.getHall = getHall;
    this.scenes = {
      stage1: {
        sprite: 'sprites/enemies/mafia_boss_defeated_v1.png',
        portrait: 'sprites/enemies/mafia_boss_defeated_portrait_v1.png',
        name: '저택의 보스', heightRatio: .23, footY: .60,
        dialogue: '밀수? 난 그쪽 일은 아무것도 몰라. 다만… 부두에서 그 일을 도맡는 자가 있다는 얘기는 들었어. 찾으려면 그쪽으로 가 봐.'
      },
      stage2: {
        sprite: 'sprites/enemies/whitehair_boss_defeated_v1.png',
        portrait: 'sprites/enemies/whitehair_boss_defeated_portrait_v1.png',
        name: '검은 부두의 보스', heightRatio: .34, footY: .746,
        hands: true,
        dialogue: '자금 관리는 내 일이 아니야. 그 많은 돈이 어디로 흐르겠어… 카지노지. 자금줄을 찾고 싶다면 그곳을 뒤져 봐.'
      },
      stage3: {
        sprite: 'sprites/enemies/stage3/casino_boss_defeated_v1.png',
        portrait: 'sprites/enemies/stage3/casino_boss_portrait_v1.png',
        name: '카지노의 보스', heightRatio: .34, footY: .623,
        hands: true,
        handClips: ['inset(39% 60% 54% 20%)', 'inset(39% 6% 54% 76%)'],
        dialogue: '장부를 가져가. 돈이 모이는 곳은 여기지만… 명령은 다른 곳에서 내려와. 그 사람의 이름은 그 안에 있어.'
      }
    };
    this.scene = document.createElement('div');
    this.scene.className = 'boss-aftermath-scene';
    stage.append(this.scene);
    this.observer = new ResizeObserver(() => this.position());
    this.observer.observe(stage);
    this.preloads = new Map();
  }

  prepare(stageId) {
    const definition = this.scenes[stageId];
    return Promise.all([definition.sprite, definition.portrait].map(source => {
      if (!this.preloads.has(source)) {
        const image = new Image();
        image.src = source;
        this.preloads.set(source, image);
      }
      return this.preloads.get(source).decode();
    }));
  }

  showDefeat(stageId) {
    this.definition = this.scenes[stageId];
    this.scene.replaceChildren();
    const sprite = new Image();
    sprite.src = this.definition.sprite;
    sprite.alt = `${this.definition.name}가 패배하여 주저앉아 있다`;
    sprite.className = 'boss-aftermath-sprite';
    this.scene.append(sprite);
    if (this.definition.hands) {
      sprite.alt = `${this.definition.name}가 책상에 두 손을 짚고 고개를 숙이고 있다`;
      // Only the hands cross in front of the desk's existing foreground mask.
      for (const side of ['left', 'right']) {
        const hand = sprite.cloneNode();
        hand.classList.add('boss-aftermath-hands', `boss-aftermath-hand-${side}`);
        hand.alt = '';
        hand.setAttribute('aria-hidden', 'true');
        if (this.definition.handClips) hand.style.clipPath = this.definition.handClips[side === 'left' ? 0 : 1];
        this.scene.append(hand);
      }
    }
    this.position();
  }

  position() {
    if (!this.definition) return;
    const hall = this.getHall();
    const slot = hall.config.slots[0];
    const height = this.stage.clientHeight * this.definition.heightRatio;
    for (const sprite of this.scene.children) {
      sprite.style.left = `${hall.screenX(slot.worldX)}px`;
      sprite.style.top = `${this.stage.clientHeight * this.definition.footY - height}px`;
      sprite.style.height = `${height}px`;
    }
  }

  showDialogue(screen) {
    const definition = this.definition;
    if (!definition) return;
    const portrait = screen.querySelector('.boss-dialogue-portrait');
    portrait.src = definition.portrait;
    portrait.alt = `${definition.name}의 지친 얼굴`;
    screen.querySelector('.boss-dialogue-name').textContent = definition.name;
    screen.querySelector('.boss-dialogue-text').textContent = definition.dialogue;
    screen.querySelector('.clear-results').hidden = true;
    screen.querySelector('.boss-dialogue').hidden = false;
    screen.dataset.clearPhase = 'dialogue';
    screen.querySelector('.boss-dialogue-next').focus({ preventScroll: true });
  }
}
window.BossAftermath = BossAftermath;
