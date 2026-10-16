class BossBattle {
  constructor(config) {
    this.config = config;
    this.maxHp = config.maxHp;
    this.hp = this.maxHp;
    this.turn = 0;
  }

  nextTurn() {
    this.turn += 1;
    const colors = ['b', 'g', 'r', 'y'];
    for (let index = colors.length - 1; index > 0; index--) {
      const other = Math.floor(Math.random() * (index + 1));
      [colors[index], colors[other]] = [colors[other], colors[index]];
    }
    const guardColors = this.turn % this.config.guardsEveryTurns === 0
      ? Array.from({ length: this.config.guardsPerTurn ?? 2 }, (_, i) => colors[2 + i % 2]) : [];
    return { color: colors[0], flipColor: colors[1], guardColors };
  }

  hit(units = 1) {
    this.hp = Math.max(0, this.hp - units);
    return this.hp === 0;
  }

  get percent() { return (this.hp / this.maxHp) * 100; }
}

if (typeof module !== 'undefined' && module.exports) module.exports = BossBattle;
else window.BossBattle = BossBattle;
