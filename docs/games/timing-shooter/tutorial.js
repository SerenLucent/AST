class TutorialSequence {
  constructor(stage, dodgeConfig, playSound) {
    this.stage = stage;
    this.playSound = playSound;
    this.active = false;
    this.timers = new Set();
    this.colors = ['b', 'y', 'r', 'g'];
    this.hints = {
      b: '하늘은 푸르니까, 위쪽 버튼은 파란색!',
      y: '땅은 흙과 같으니까, 아래쪽 버튼은 노란색!',
      r: '앞으로 나아가는 붉은색, 오른쪽 버튼!',
      g: '천천히 완만한 녹색, 왼쪽 버튼!'
    };
    this.names = { b: '파란색 위쪽', y: '노란색 아래쪽', r: '빨간색 오른쪽', g: '녹색 왼쪽' };
    this.layer = document.createElement('section');
    this.layer.className = 'tutorial-layer';
    this.layer.setAttribute('aria-label', '튜토리얼');
    this.layer.innerHTML = `
      <div class="tutorial-heading">연습</div>
      <button class="tutorial-skip" type="button">튜토리얼 건너뛰기</button>
      <div class="tutorial-copy" aria-live="polite"><strong></strong><p></p><div class="tutorial-instruction"></div>
        <div class="tutorial-actions" hidden><button class="tutorial-view-items" type="button">아이템 보기</button><button class="tutorial-start-game" type="button">게임 시작</button></div>
      </div>
      <div class="tutorial-enemy"><img class="tutorial-enemy-body" src="sprites/enemies/mafia_gunman_aim_01.png" alt="연습용 마피아"><div class="tutorial-reticle"></div></div>
      <div class="tutorial-result" aria-live="polite"></div>`;
    stage.append(this.layer);
    this.enemy = this.layer.querySelector('.tutorial-enemy');
    this.body = this.layer.querySelector('.tutorial-enemy-body');
    this.knockdown = document.createElement('div');
    this.knockdown.className = 'tutorial-enemy-knockdown';
    this.knockdown.style.backgroundImage = 'url("sprites/enemies/mafia_knockdown_atlas_v1.png")';
    this.enemy.append(this.knockdown);
    this.reticle = this.layer.querySelector('.tutorial-reticle');
    this.heading = this.layer.querySelector('.tutorial-copy strong');
    this.copy = this.layer.querySelector('.tutorial-copy p');
    this.instruction = this.layer.querySelector('.tutorial-instruction');
    this.result = this.layer.querySelector('.tutorial-result');
    this.actions = this.layer.querySelector('.tutorial-actions');
    const items = [
      { name: '샷건', icon: 'sprites/items/shotgun_icon.png', description: '한 화면에 나오는 모든 적에게 내가 맞힌 한 적의 판정이 똑같이 적용돼요.' },
      { name: '머신건', icon: 'sprites/items/machine_gun_icon.png', description: '한 발만 맞혀도 적을 쓰러뜨려요. 추가 점수를 원하면 최대 4발을 더 연타할 수 있어요.' },
      { name: '매그넘', icon: 'sprites/items/magnum_icon.png', description: '모든 적이 빨간색 타겟으로 나타나며, 버튼 하나로 간편하게 소탕할 수 있어요.' },
      { name: '스나이퍼', icon: 'sprites/items/sniper_icon.png', description: '모든 판정 범위가 여유 있게 넓어져요.' },
      { name: '파워 업', icon: 'sprites/items/power_up_icon.png', description: '20% 추가 점수를 받을 수 있으며, 보스전에서는 추가 데미지를 줘요.' },
      { name: '슬로우 다운', icon: 'sprites/items/slow_down_icon.png', description: '일정 시간 모든 타겟이 느려져요.' },
      { name: '아머 베스트', icon: 'sprites/items/armor_vest_icon.png', description: '일정 시간 회피하지 못해도 데미지를 입지 않아요.' },
      { name: '라이프 업', icon: 'sprites/items/medkit_icon.png', description: 'HP를 회복해요.' }
    ];
    this.itemDialog = document.createElement('dialog');
    this.itemDialog.className = 'tutorial-items-dialog';
    this.itemDialog.setAttribute('aria-labelledby', 'tutorialItemsTitle');
    this.itemDialog.innerHTML = `<header><h2 id="tutorialItemsTitle">아이템 안내</h2><button type="button" class="tutorial-items-close" aria-label="닫기" title="닫기">×</button></header>
      <ul class="tutorial-items-list">${items.map(item => `<li><span class="tutorial-item-icon active-item-icon" data-item-id="${item.icon.split('/').pop().replace('_icon.png', '')}"><img src="${item.icon}" alt=""></span><div><h3>${item.name}</h3><p>${item.description}</p></div></li>`).join('')}</ul>`;
    this.layer.append(this.itemDialog);
    this.layer.querySelector('.tutorial-view-items').addEventListener('click', () => {
      if (this.active && this.phase === 'items' && !this.itemDialog.open) this.itemDialog.showModal();
    });
    this.itemDialog.querySelector('.tutorial-items-close').addEventListener('click', () => this.itemDialog.close());
    this.layer.querySelector('.tutorial-start-game').addEventListener('click', () => this.beginGame());
    this.layer.querySelector('.tutorial-skip').addEventListener('pointerdown', event => {
      event.preventDefault();
      this.finish();
    });
    this.dodge = new DodgeSequence(stage, dodgeConfig, () => {
      this.playSound('sound/miss.mp3');
      this.phase = 'feedback';
      this.clearCue();
      this.later(() => this.nextLesson(), 900);
      return 0;
    });
  }

  start() {
    this.active = true;
    this.index = 0;
    this.actions.hidden = true;
    this.enemy.hidden = false;
    this.layer.querySelector('.tutorial-skip').hidden = false;
    if (this.itemDialog.open) this.itemDialog.close();
    this.done = new Promise(resolve => { this.resolveDone = resolve; });
    this.layer.classList.add('visible');
    this.stage.classList.add('tutorial-running');
    this.showLesson();
    return this.done;
  }

  later(callback, delay) {
    const id = gameRuntime.setTimeout(() => {
      this.timers.delete(id);
      if (this.active) callback();
    }, delay);
    this.timers.add(id);
  }

  clearCue() {
    this.stage.querySelectorAll('.tutorial-cue').forEach(button => button.classList.remove('tutorial-cue'));
  }

  setText(element, text) {
    const colors = { '파란색': 'b', '노란색': 'y', '붉은색': 'r', '빨간색': 'r', '녹색': 'g' };
    element.replaceChildren(...text.split(/(파란색|노란색|붉은색|빨간색|녹색)/).map(word => {
      if (!colors[word]) return document.createTextNode(word);
      const span = document.createElement('span');
      span.className = 'tutorial-color';
      span.dataset.color = colors[word];
      span.textContent = word;
      return span;
    }));
  }

  cue() {
    this.phase = 'waiting';
    this.setText(this.instruction, `지금! ${this.names[this.color]} 버튼을 눌러보세요.`);
    this.stage.querySelector(`.pad-button[data-color="${this.color}"]`).classList.add('tutorial-cue');
  }

  setReticle(color) {
    this.reticle.hidden = false;
    this.reticle.replaceChildren(...['target', 'perfect_target', 'circle'].map((name, index) => {
      const image = new Image();
      image.src = `sprites/${name}_${color}.png`;
      image.alt = '';
      image.className = ['tutorial-target', 'tutorial-perfect', 'tutorial-ring'][index];
      return image;
    }));
    this.ring = this.reticle.querySelector('.tutorial-ring');
  }

  animateTiming(duration, update, complete) {
    const startedAt = gameRuntime.now();
    const step = now => {
      if (!this.active) return;
      const progress = Math.min(1, (now - startedAt) / duration);
      update(progress);
      if (progress < 1) this.frame = gameRuntime.requestAnimationFrame(step);
      else complete();
    };
    this.frame = gameRuntime.requestAnimationFrame(step);
  }

  showLesson() {
    this.phase = 'moving';
    this.color = this.colors[this.index % 4];
    this.clearCue();
    this.result.textContent = '';
    this.body.src = 'sprites/enemies/mafia_gunman_aim_01.png';
    this.enemy.classList.remove('shot');
    this.dodge.clear();
    const shooting = this.index < 4;
    this.heading.textContent = `${shooting ? '사격' : '회피'} 연습 ${this.index % 4 + 1} / 4`;
    this.setText(this.copy, shooting
      ? `${this.hints[this.color]} 큰 원이 줄어들어 작은 원과 겹치면 같은 색 버튼으로 쏴요.`
      : `${this.hints[this.color]} 안쪽 사각형이 커져 바깥 사각형과 겹치면 같은 색 버튼으로 피해요.`);
    this.instruction.textContent = '정확히 겹치면 멈춰줄게요. 먼저 모양을 지켜보세요.';
    if (shooting) {
      this.setReticle(this.color);
      this.animateTiming(1800, progress => {
        this.ring.style.transform = `translate(-50%, -50%) scale(${1.55 + (52 / 120 - 1.55) * progress})`;
      }, () => this.cue());
    } else {
      this.reticle.hidden = true;
      this.dodge.enqueue({ element: this.enemy });
      const shot = this.dodge.current;
      shot.color = this.color;
      shot.duration = 2000;
      const now = gameRuntime.now();
      shot.perfectTime = now + shot.duration;
      this.dodge.layer.style.setProperty('--dodge-color', this.dodge.colors[this.color]);
      this.animateTiming(shot.duration, progress => this.dodge.update(now + progress * shot.duration), () => this.cue());
    }
  }

  press(color) {
    if (!this.active) return false;
    if (this.phase === 'moving') {
      this.instruction.textContent = '조금만 기다려요. 두 모양이 겹치는 순간 멈춰줄게요.';
      return true;
    }
    if (this.phase !== 'waiting') return true;
    if (color !== this.color) {
      this.setText(this.instruction, `${this.names[this.color]} 버튼이에요. 반짝이는 버튼을 눌러보세요!`);
      return true;
    }
    this.phase = 'feedback';
    this.clearCue();
    if (this.index < 4) {
      this.playSound('sound/gun.mp3');
      this.showHitEffect();
      this.enemy.classList.add('shot');
      this.knockdown.style.backgroundPosition = '0% 0%';
      for (let frame = 1; frame < 4; frame++) {
        this.later(() => {
          this.knockdown.style.backgroundPosition = `${frame * 100 / 3}% 0%`;
        }, frame * 100);
      }
      this.reticle.hidden = true;
      this.result.textContent = 'Perfect!';
      this.later(() => this.nextLesson(), 900);
    } else {
      // Freeze the judgement clock as well as the rectangle while awaiting input.
      this.dodge.current.perfectTime = gameRuntime.now();
      this.dodge.press(color);
    }
    return true;
  }

  nextLesson() {
    this.index++;
    if (this.index === 4) {
      this.phase = 'demo';
      this.result.textContent = '';
      this.body.src = 'sprites/enemies/mafia_gunman_aim_01.png';
      this.enemy.classList.remove('shot');
      this.heading.textContent = '적을 격추하지 못했다면?';
      this.copy.textContent = '이번에는 쏘지 않고 기다려볼게요. 타이밍을 놓치면 적이 살아남아 반격해요.';
      this.instruction.textContent = '잠시 지켜보세요. 다음은 탄환을 피하는 연습이에요.';
      this.setReticle('r');
      this.animateTiming(1500, progress => {
        this.ring.style.transform = `translate(-50%, -50%) scale(${1.55 - 1.33 * progress})`;
      }, () => {
        this.reticle.hidden = true;
        this.result.textContent = 'Miss!';
        this.playSound('sound/miss.mp3');
        this.instruction.textContent = '회피는 원 대신 사각형! 안쪽 사각형이 바깥쪽으로 커져요.';
        this.later(() => this.showLesson(), 2200);
      });
    } else if (this.index >= 8) {
      this.showItemChoice();
    } else this.showLesson();
  }

  showHitEffect() {
    const effect = document.createElement('img');
    effect.className = 'tutorial-hit-effect';
    effect.alt = '';
    effect.src = 'sprites/effects/bullet_effect_1.png';
    effect.style.setProperty('--hit-color', { b: '#4695ff', y: '#ffd629', r: '#ff403a', g: '#43ff68' }[this.color]);
    this.enemy.append(effect);
    this.later(() => { effect.src = 'sprites/effects/bullet_effect_2.png'; }, 55);
    this.later(() => { effect.src = 'sprites/effects/bullet_effect_3.png'; }, 110);
    this.later(() => effect.remove(), 230);
  }

  showItemChoice() {
    this.dodge.clear();
    this.clearCue();
    this.reticle.hidden = true;
    this.enemy.hidden = true;
    this.result.textContent = '';
    this.heading.textContent = '연습 완료!';
    this.copy.textContent = '자, 그럼 나오는 아이템들을 볼래?';
    this.instruction.textContent = '';
    this.phase = 'items';
    this.actions.hidden = false;
    this.layer.querySelector('.tutorial-skip').hidden = true;
  }

  beginGame() {
    if (!this.active || this.phase !== 'items') return;
    if (this.itemDialog.open) this.itemDialog.close();
    this.actions.hidden = true;
    this.heading.textContent = '이제 실전으로!';
    this.copy.textContent = '원은 줄어들 때 쏘고, 사각형은 커질 때 피해요. 색깔에 맞는 버튼을 기억하세요.';
    this.instruction.textContent = '잠시 후 OPEN FIRE 신호탄 장면으로 이동해요.';
    this.phase = 'complete';
    this.later(() => this.finish(), 1600);
  }

  finish() {
    if (!this.active) return;
    this.active = false;
    if (this.itemDialog.open) this.itemDialog.close();
    this.actions.hidden = true;
    gameRuntime.cancelAnimationFrame(this.frame);
    this.timers.forEach(id => gameRuntime.clearTimeout(id));
    this.timers.clear();
    this.layer.querySelectorAll('.tutorial-hit-effect').forEach(effect => effect.remove());
    this.dodge.clear();
    this.clearCue();
    this.layer.classList.remove('visible');
    this.enemy.classList.remove('shot');
    this.stage.classList.remove('tutorial-running');
    this.resolveDone();
  }
}
window.TutorialSequence = TutorialSequence;
