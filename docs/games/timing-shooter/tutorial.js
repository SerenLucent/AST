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
      <div class="tutorial-copy" aria-live="polite"><strong></strong><p></p><div class="tutorial-instruction"></div></div>
      <div class="tutorial-enemy"><img class="tutorial-enemy-body" src="sprites/enemies/mafia_gunman_aim_01.png" alt="연습용 마피아"><div class="tutorial-reticle"></div></div>
      <div class="tutorial-result" aria-live="polite"></div>`;
    stage.append(this.layer);
    this.enemy = this.layer.querySelector('.tutorial-enemy');
    this.body = this.layer.querySelector('.tutorial-enemy-body');
    this.reticle = this.layer.querySelector('.tutorial-reticle');
    this.heading = this.layer.querySelector('.tutorial-copy strong');
    this.copy = this.layer.querySelector('.tutorial-copy p');
    this.instruction = this.layer.querySelector('.tutorial-instruction');
    this.result = this.layer.querySelector('.tutorial-result');
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

  cue() {
    this.phase = 'waiting';
    this.instruction.textContent = `지금! ${this.names[this.color]} 버튼을 눌러보세요.`;
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
    this.dodge.clear();
    const shooting = this.index < 4;
    this.heading.textContent = `${shooting ? '사격' : '회피'} 연습 ${this.index % 4 + 1} / 4`;
    this.copy.textContent = shooting
      ? `${this.hints[this.color]} 큰 원이 줄어들어 작은 원과 겹치면 같은 색 버튼으로 쏴요.`
      : `${this.hints[this.color]} 안쪽 사각형이 커져 바깥 사각형과 겹치면 같은 색 버튼으로 피해요.`;
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
      this.instruction.textContent = `${this.names[this.color]} 버튼이에요. 반짝이는 버튼을 눌러보세요!`;
      return true;
    }
    this.phase = 'feedback';
    this.clearCue();
    if (this.index < 4) {
      this.playSound('sound/gun.mp3');
      this.body.src = 'sprites/enemies/mafia_gunman_hit_01.png';
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
      this.dodge.clear();
      this.result.textContent = '연습 완료!';
      this.heading.textContent = '이제 실전으로!';
      this.copy.textContent = '원은 줄어들 때 쏘고, 사각형은 커질 때 피해요. 색깔에 맞는 버튼을 기억하세요.';
      this.instruction.textContent = '잠시 후 OPEN FIRE 신호탄 장면으로 이동해요.';
      this.phase = 'complete';
      this.later(() => this.finish(), 1600);
    } else this.showLesson();
  }

  finish() {
    if (!this.active) return;
    this.active = false;
    gameRuntime.cancelAnimationFrame(this.frame);
    this.timers.forEach(id => gameRuntime.clearTimeout(id));
    this.timers.clear();
    this.dodge.clear();
    this.clearCue();
    this.layer.classList.remove('visible');
    this.stage.classList.remove('tutorial-running');
    this.resolveDone();
  }
}
window.TutorialSequence = TutorialSequence;
