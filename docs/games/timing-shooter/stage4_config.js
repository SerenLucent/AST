// Stage-four opening and its two boss phases share the established combat engine.
window.TIMING_SHOOTER_STAGE4_OPENING = {
  label: '성역 외부 입구', captionArt: true,
  background: 'backgrounds/stage4_sanctuary/opening_palace_v1.png',
  idle: 'sprites/enemies/stage4/palace_guard_idle_v2.png',
  knockdown: 'sprites/enemies/stage4/palace_guard_fall_atlas_v2.png',
  entry: 'backgrounds/stage4_sanctuary/hold_0_to_1_male_v1.png',
  entryCoop: 'backgrounds/stage4_sanctuary/hold_0_to_1_coop_v1.png',
  revealMs: 700, entryHoldMs: 2000,
  guardLayout: { left: 18, top: 36.5, width: 60, height: 28 },
  fallLayout: { left: 18, top: 36.5, width: 60, height: 28 },
  reticleLayout: { left: 57, top: 45.5 },
  canvasWidth: 700, canvasHeight: 700,
  frames: [
    { rect: [0, 0, 700, 700], offset: 0, top: 36.5, durationMs: 120 },
    { rect: [700, 0, 700, 700], offset: 0, top: 36.5, durationMs: 140 },
    { rect: [0, 700, 700, 700], offset: 0, top: 36.5, durationMs: 160 },
    { rect: [700, 700, 700, 700], offset: 0, top: 36.5, durationMs: 900 }
  ]
};

// Warning must finish before the trap corridor's first dodge starts.
window.TIMING_SHOOTER_STAGE4_TRAP_ROOM = {
  name: '총구 함정 통로', camera: .5, singleView: true,
  background: 'backgrounds/stage4_sanctuary/wave_4_trap_v2.png',
  special: 'trap', enemyTotal: 6, shotIntervalMs: 500,
  slots: [], occluders: [],
  warning: {
    durationMs: 2200,
    targets: [
      { x: .109, y: .268 }, { x: .132, y: .358 }, { x: .107, y: .428 },
      { x: .891, y: .268 }, { x: .867, y: .358 }, { x: .893, y: .428 }
    ]
  }
};

// Final boss phase, entered after the upstairs escape scene.
window.TIMING_SHOOTER_STAGE4_PILLAR_ROOM = {
  name: '1층 기둥 결전', camera: .5, singleView: true,
  background: 'backgrounds/duel_1p_vs_mafia_aim_v2.png',
  backgroundFit: 'cover', backgroundPositionX: .35,
  enemyTotal: 1,
  occluders: [],
  boss: {
    sprite: 'sprites/duel/mafia_aim_v1.png',
    hitSprite: 'sprites/duel/mafia_aim_v1.png',
    maxHp: 50,
    guardsEveryTurns: 0, guardsPerTurn: 0,
    dodgeShotCount: 5, dodgeDurationMs: 650,
    muzzleOffsetXRatio: -96 / 1536, muzzleOffsetYRatio: -518 / 1536,
    embedded: true, muzzle: { x: .259, y: .257 },
    dodgeColorChangeProgress: null, colorChangeProgress: null
  },
  slots: [
    { id: 'sanctuary_final_boss', worldX: .29, aimY: .30, footY: .575, heightRatio: .37 }
  ]
};

{
  const room = (name, background, enemyTotal, slots, extra = {}) => ({
    name, camera: 0, background, enemyTotal, waveTargets: 3, slots, occluders: [],
    entryMale: background, entryCoop: background, entryFit: 'contain', entryPosition: 'center',
    captionArt: true, transitionDelayMs: 700, loadingHoldMs: 2200, riseMs: 420, ...extra
  });
  const atrium = room('대리석 아트리움', 'backgrounds/stage4_sanctuary/wave_1_atrium_v1.png', 18, [
    { id: 'atrium_left', worldX: .12, footY: .62, heightRatio: .26 },
    { id: 'atrium_counter', worldX: .29, footY: .63, heightRatio: .26 },
    { id: 'atrium_door', worldX: .43, footY: .54, heightRatio: .22 }
  ]);
  const stairs = room('중앙 계단', 'backgrounds/stage4_sanctuary/wave_2_stairs_v1.png', 21, [
    { id: 'stairs_planter', worldX: .11, footY: .62, heightRatio: .26 },
    { id: 'stairs_landing', worldX: .29, footY: .57, heightRatio: .24 },
    { id: 'stairs_door', worldX: .43, footY: .57, heightRatio: .24 }
  ]);
  const balcony = room('맞은편 난간', 'backgrounds/stage4_sanctuary/wave_3_balcony_v1.png', 6, [], {
    camera: .5, singleView: true, special: 'balcony', maxActiveTargets: 3,
    actorSlots: [.085, .251, .417, .583, .749, .915].map(x => ({ x, y: .34 }))
  });
  const trap = room('총구 함정 통로', 'backgrounds/stage4_sanctuary/wave_4_trap_v2.png', 6, [], window.TIMING_SHOOTER_STAGE4_TRAP_ROOM);
  const antechamber = room('보스 집무실 앞', 'backgrounds/stage4_sanctuary/wave_5_antechamber_v1.png', 24, [
    { id: 'ante_console', worldX: .13, footY: .62, heightRatio: .27 },
    { id: 'ante_guard', worldX: .29, footY: .62, heightRatio: .27 },
    { id: 'ante_door', worldX: .43, footY: .54, heightRatio: .22 }
  ]);
  const upper = room('2층 집무실', 'backgrounds/stage4_sanctuary/boss_upper_room_v1.png', 1, [
    { id: 'sanctuary_boss_upper', worldX: .56, footY: .67, heightRatio: .30 },
    { id: 'sanctuary_guard_left', worldX: .16, footY: .67, heightRatio: .27 },
    { id: 'sanctuary_guard_right', worldX: .84, footY: .67, heightRatio: .27 },
    { id: 'sanctuary_guard_front', worldX: .34, footY: .74, heightRatio: .27, depth: 2 }
  ], {
    camera: .5, singleView: true, bossPhase: 1,
    boss: { ...window.TIMING_SHOOTER_STAGE4_PILLAR_ROOM.boss,
      guardsEveryTurns: 2, guardsPerTurn: 3, dodgeShotCount: 1, embedded: false }
  });
  const final = room('1층 기둥 결전', 'backgrounds/duel_1p_vs_mafia_aim_v2.png', 1,
    window.TIMING_SHOOTER_STAGE4_PILLAR_ROOM.slots, {
      ...window.TIMING_SHOOTER_STAGE4_PILLAR_ROOM, bossPhase: 2,
      entryMale: 'backgrounds/stage4_sanctuary/chase_down_male_v1.png',
      entryCoop: 'backgrounds/stage4_sanctuary/chase_down_coop_v1.png'
    });
  for (const [config, male, coop] of [
    [stairs, 'backgrounds/stage4_sanctuary/hold_1_to_2_male_v1.png', 'backgrounds/stage4_sanctuary/hold_1_to_2_coop_v1.png'],
    [balcony, 'backgrounds/stage4_sanctuary/hold_2_to_3_male_v1.png', 'backgrounds/stage4_sanctuary/hold_2_to_3_coop_v1.png'],
    [trap, 'backgrounds/stage4_sanctuary/hold_3_to_4_male_v1.png', 'backgrounds/stage4_sanctuary/hold_3_to_4_coop_v1.png'],
    [antechamber, 'backgrounds/stage4_sanctuary/hold_4_to_5_male_v1.png', 'backgrounds/stage4_sanctuary/hold_4_to_5_coop_v1.png'],
    [upper, 'backgrounds/stage4_sanctuary/hold_5_to_boss_male_v1.png', 'backgrounds/stage4_sanctuary/hold_5_to_boss_coop_v1.png']
  ]) { config.entryMale = male; config.entryCoop = coop; }
  window.TIMING_SHOOTER_STAGE4 = {
    ...atrium, id: 'stage4', title: '백색 성역', opening: window.TIMING_SHOOTER_STAGE4_OPENING,
    bossRoom: upper, rooms: [atrium, stairs, balcony, trap, antechamber, upper, final],
    escape: { image: 'backgrounds/stage4_sanctuary/boss_escape_stairs_v1.png',
      title: '보스 도주', text: '보스가 1층으로 도주합니다. 놓치기 전에 쫓아가세요.', next: '따라가기' },
    ending: [
      { image: 'backgrounds/stage4_sanctuary/boss_escape_foyer_v1.png', title: '마피아 보스', text: '이건... 예상밖인걸', next: '쫓아가기' },
      { image: 'backgrounds/stage4_sanctuary/chase_foyer_male_v1.png', title: '현관 추격', cinematic: true, autoAdvanceMs: 2000 },
      { image: 'backgrounds/stage4_sanctuary/ending_car_escape_v1.png', title: '마피아 보스', text: '크… 지금 잡힐 순 없지.' },
      { image: 'backgrounds/stage4_sanctuary/ending_police_v1.png', title: '이걸 놓치다니....', text: '추격은 아직 끝나지 않았다', emphasis: true },
      { image: 'backgrounds/stage4_sanctuary/ending_car_escape_v1.png', title: 'SEASON 2 · JAPAN',
        text: '놈의 다음 행선지는 일본. 야쿠자의 그림자 속에서 새로운 추적이 시작된다.', next: '결과 보기' }
    ]
  };
  for (const config of [atrium, stairs, antechamber]) {
    config.slots2p = config.slots.map(slot => ({ ...slot, id: `${slot.id}_2p`, worldX: 1 - slot.worldX }));
  }
  window.TIMING_SHOOTER_STAGE4.slots2p = atrium.slots2p;
}
