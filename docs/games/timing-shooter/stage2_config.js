window.TIMING_SHOOTER_STAGE2 = {
  id: 'stage2', title: '검은 부두', camera: 0,
  background: 'backgrounds/stage2_black_wharf/wave_1_wharf_v2.png',
  enemyTotal: 10, riseMs: 420,
  slots: [
    { id: 'wharf_crates', worldX: .18, footY: .67, heightRatio: .25, clipBottomY: .554, rise: true },
    { id: 'wharf_barrels', worldX: .34, footY: .56, heightRatio: .18 },
    { id: 'wharf_door', worldX: .42, footY: .55, heightRatio: .17 }
  ],
  occluders: [
    { id: 'wharf_left_cargo', polygon: '4% 55%, 26.5% 55%, 26.5% 68%, 4% 68%' },
    { id: 'wharf_cart', polygon: '77% 55%, 97% 55%, 97% 69%, 77% 69%' }
  ],
  upperFloor: {
    name: '밀수품 창고', camera: 0,
    background: 'backgrounds/stage2_black_wharf/wave_2_warehouse_v2.png',
    entryMale: 'backgrounds/stage2_black_wharf/hold_1_to_2_warehouse_v1.png',
    bakedEntryCaption: true, entryFit: 'contain', entryPosition: 'center',
    enemyTotal: 10, transitionDelayMs: 1000, loadingHoldMs: 2000, riseMs: 420,
    slots: [
      { id: 'warehouse_crates', worldX: .28, footY: .69, heightRatio: .25, clipBottomY: .554, rise: true },
      { id: 'warehouse_rear', worldX: .39, footY: .57, heightRatio: .18 },
      { id: 'warehouse_column', worldX: .18, footY: .56, heightRatio: .19 }
    ],
    occluders: [
      { id: 'warehouse_crates', polygon: '21% 55.4%, 37% 55.4%, 37% 69%, 21% 69%' },
      { id: 'warehouse_cart', polygon: '65% 54.8%, 87.5% 54.8%, 87.5% 70%, 65% 70%' }
    ]
  },
  diningRoom: {
    name: '옛 세관', camera: 0,
    background: 'backgrounds/stage2_black_wharf/wave_3_customs_v2.png',
    entryMale: 'backgrounds/stage2_black_wharf/hold_2_to_3_customs_v1.png',
    bakedEntryCaption: true, entryFit: 'contain', entryPosition: 'center',
    enemyTotal: 10, transitionDelayMs: 1000, loadingHoldMs: 2000, riseMs: 420,
    slots: [
      { id: 'customs_counter', worldX: .22, footY: .64, heightRatio: .24, clipBottomY: .504, rise: true },
      { id: 'customs_stairs', worldX: .37, footY: .58, heightRatio: .18 },
      { id: 'customs_pillar', worldX: .12, footY: .68, heightRatio: .22 }
    ],
    occluders: [
      { id: 'customs_counter', polygon: '8.5% 50.4%, 32.8% 50.4%, 32.8% 64%, 8.5% 64%' },
      { id: 'customs_cart', polygon: '74% 51.5%, 94% 51.5%, 94% 64%, 74% 64%' }
    ]
  },
  bossRoom: {
    name: '항만 사무실', camera: .5,
    background: 'backgrounds/stage2_black_wharf/wave_4_boss_office_v2.png',
    entryMale: 'backgrounds/stage2_black_wharf/hold_3_to_4_office_v1.png',
    bakedEntryCaption: true, entryFit: 'contain', entryPosition: 'center',
    enemyTotal: 1, transitionDelayMs: 1000, loadingHoldMs: 2000, riseMs: 420,
    boss: {
      sprite: 'sprites/enemies/whitehair_boss_aim_v1.png',
      hitSprite: 'sprites/enemies/whitehair_boss_hit_v1.png',
      maxHp: 50, guardsEveryTurns: 3, colorChangeProgress: .5,
      dodgeDurationMs: 650, machineGunRepeatMultiplier: .25
    },
    slots: [
      { id: 'whitehair_boss', worldX: .5, footY: .70, heightRatio: .34, clipBottomY: .55 },
      { id: 'office_guard_left', worldX: .345, footY: .70, heightRatio: .32, clipBottomY: .55 },
      { id: 'office_guard_right', worldX: .655, footY: .70, heightRatio: .32, clipBottomY: .55 }
    ],
    occluders: [{ id: 'office_desk', polygon: '24% 54.8%, 76% 54.8%, 75% 72%, 25% 72%' }]
  },
  opening: {
    background: 'backgrounds/stage2_black_wharf/opening_wharf_clean_v2.png',
    idle: 'sprites/enemies/dock_foreman_idle_v1.png',
    knockdown: 'sprites/enemies/dock_foreman_knockdown_atlas_v2.png',
    entry: 'backgrounds/stage2_black_wharf/hold_0_to_1_wharf_v1.png',
    revealMs: 700, entryHoldMs: 2000,
    frames: [
      { rect: [0, 0, 627, 700], offset: 0, durationMs: 110, top: 31.5 },
      { rect: [627, 0, 627, 700], offset: 0, durationMs: 120, top: 31.5 },
      { rect: [0, 760, 627, 494], offset: 251, durationMs: 140, top: 33.5 },
      { rect: [627, 760, 627, 494], offset: 261, durationMs: 800, top: 35.5 }
    ]
  }
};
