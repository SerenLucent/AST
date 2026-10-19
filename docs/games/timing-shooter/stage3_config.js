window.TIMING_SHOOTER_STAGE3 = {
  id: 'stage3', title: '마지막 배팅', camera: 0,
  background: 'backgrounds/stage3_casino/wave_1_lobby_v1.png',
  enemyTotal: 16, waveTargets: 2, riseMs: 420,
  slots: [
    { id: 'casino_reception', worldX: .14, footY: .65, heightRatio: .27, clipBottomY: .464, rise: true },
    { id: 'casino_planter', worldX: .31, footY: .57, heightRatio: .22 },
    { id: 'casino_lobby_door', worldX: .435, footY: .55, heightRatio: .19 }
  ],
  occluders: [
    { id: 'reception_left', polygon: '0% 46.4%, 24% 46.4%, 24% 60%, 0% 60%' },
    { id: 'reception_right', polygon: '76% 46.4%, 100% 46.4%, 100% 60%, 76% 60%' }
  ],
  upperFloor: {
    name: '카지노 테이블 홀', camera: 0,
    background: 'backgrounds/stage3_casino/wave_2_tables_v1.png',
    entryMale: 'backgrounds/stage3_casino/hold_1_to_2_male_v2.png',
    entryCoop: 'backgrounds/stage3_casino/hold_1_to_2_coop_v1.png',
    captionArt: true, entryFit: 'contain', entryPosition: 'center',
    enemyTotal: 20, waveTargets: 2, transitionDelayMs: 1000, loadingHoldMs: 2000, riseMs: 420,
    slots: [
      { id: 'casino_roulette', worldX: .13, footY: .69, heightRatio: .30, clipBottomY: .522, rise: true },
      { id: 'casino_blackjack', worldX: .29, footY: .59, heightRatio: .24, clipBottomY: .475 },
      { id: 'casino_tables_door', worldX: .435, footY: .55, heightRatio: .19 }
    ],
    occluders: [
      { id: 'roulette_left', polygon: '0% 52.2%, 26% 52.2%, 27% 68%, 0% 71%' },
      { id: 'roulette_right', polygon: '74% 52.2%, 100% 52.2%, 100% 71%, 73% 68%' }
    ],
    hostages: [
      {
        crouch: 'sprites/hostages/stage3/dealer_male_crouch_v1.png',
        fallen: 'sprites/hostages/stage3/dealer_male_fallen_v1.png',
        slot: { worldX: .10, footY: .78, heightRatio: .19 },
        slot2p: { worldX: .90, footY: .78, heightRatio: .19 }, hitHoldMs: 4000
      },
      {
        crouch: 'sprites/hostages/stage3/dealer_female_crouch_v1.png',
        fallen: 'sprites/hostages/stage3/dealer_female_fallen_v1.png',
        slot: { worldX: .39, footY: .68, heightRatio: .18 },
        slot2p: { worldX: .61, footY: .68, heightRatio: .18 }, hitHoldMs: 4000
      }
    ]
  },
  diningRoom: {
    name: 'VIP 라운지', camera: 0,
    background: 'backgrounds/stage3_casino/wave_3_vip_v1.png',
    entryMale: 'backgrounds/stage3_casino/hold_2_to_3_male_v1.png',
    entryCoop: 'backgrounds/stage3_casino/hold_2_to_3_coop_v1.png',
    captionArt: true, entryFit: 'contain', entryPosition: 'center',
    enemyTotal: 21, waveTargets: 3, transitionDelayMs: 1000, loadingHoldMs: 2000, riseMs: 420,
    slots: [
      { id: 'casino_sofa', worldX: .18, footY: .64, heightRatio: .27, clipBottomY: .455, rise: true },
      { id: 'casino_bar', worldX: .085, footY: .55, heightRatio: .22, clipBottomY: .408 },
      { id: 'casino_vip_door', worldX: .435, footY: .51, heightRatio: .19 }
    ],
    occluders: [
      { id: 'sofa_left', polygon: '0% 45.5%, 29% 45.5%, 29% 61%, 0% 61%' },
      { id: 'sofa_right', polygon: '71% 45.5%, 100% 45.5%, 100% 61%, 71% 61%' }
    ]
  },
  bossRoom: {
    name: '카지노 집무실', camera: .5, singleView: true,
    background: 'backgrounds/stage3_casino/wave_4_boss_office_v1.png',
    entryMale: 'backgrounds/stage3_casino/hold_3_to_4_male_v1.png',
    entryCoop: 'backgrounds/stage3_casino/hold_3_to_4_coop_v1.png',
    captionArt: true, entryFit: 'contain', entryPosition: 'center',
    enemyTotal: 1, transitionDelayMs: 1000, loadingHoldMs: 2000, riseMs: 420,
    boss: {
      sprite: 'sprites/enemies/stage3/casino_boss_aim_v1.png',
      hitSprite: 'sprites/enemies/stage3/casino_boss_hit_v1.png',
      muzzleOffsetXRatio: -26 / 1536, muzzleOffsetYRatio: -504 / 1536,
      maxHp: 50, guardsEveryTurns: 2, guardsPerTurn: 3, colorChangeProgress: .5,
      dodgeDurationMs: 650, dodgeColorChangeProgress: .5, machineGunRepeatMultiplier: .25
    },
    slots: [
      { id: 'casino_boss', worldX: .5, footY: .65, heightRatio: .34, clipBottomY: .435 },
      { id: 'casino_guard_left', worldX: .23, footY: .65, heightRatio: .31, clipBottomY: .435 },
      { id: 'casino_guard_right', worldX: .77, footY: .65, heightRatio: .31, clipBottomY: .435 },
      { id: 'casino_guard_front', worldX: .37, footY: .68, heightRatio: .31, clipBottomY: .435 }
    ],
    occluders: [{ id: 'casino_desk', polygon: '3% 43.5%, 97% 43.5%, 97% 62%, 3% 62%' }]
  },
  opening: {
    label: '카지노 입구', captionArt: true,
    background: 'backgrounds/stage3_casino/opening_entrance_v1.png',
    idle: 'sprites/enemies/stage3/casino_bouncer_idle_v1.png',
    knockdown: 'sprites/enemies/stage3/casino_bouncer_fall_atlas_v1.png',
    entry: 'backgrounds/stage3_casino/hold_0_to_1_male_v1.png',
    entryCoop: 'backgrounds/stage3_casino/hold_0_to_1_coop_v1.png',
    revealMs: 700, entryHoldMs: 2000,
    guardLayout: { left: 32, top: 28, width: 36, height: 26 },
    fallLayout: { left: 27, top: 32, width: 46, height: 22 },
    reticleLayout: { left: 50, top: 34 }, canvasWidth: 627, canvasHeight: 627,
    frames: [
      { rect: [0, 0, 627, 627], offset: 0, durationMs: 110, top: 32 },
      { rect: [627, 0, 627, 627], offset: 0, durationMs: 120, top: 32 },
      { rect: [0, 627, 627, 627], offset: 0, durationMs: 140, top: 35 },
      { rect: [627, 627, 627, 627], offset: 0, durationMs: 800, top: 35 }
    ]
  }
};
for (const room of [window.TIMING_SHOOTER_STAGE3, window.TIMING_SHOOTER_STAGE3.upperFloor, window.TIMING_SHOOTER_STAGE3.diningRoom]) {
  room.slots2p = room.slots.map(slot => ({ ...slot, id: `${slot.id}_2p`, worldX: 1 - slot.worldX }));
}
