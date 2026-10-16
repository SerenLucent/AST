const enemyVariantDefinitions = [
  {
    "id": "short_slim",
    "name": "키 작고 마른 마피아",
    "aim": "sprites/enemies/variants/mafia_short_slim_aim_v1.png",
    "atlas": "sprites/enemies/variants/mafia_short_slim_knockdown_atlas_v2.png",
    "imageSize": [
      1774,
      887
    ],
    "logicalFrameSize": [
      888,
      469
    ],
    "drawOffsetX": 222,
    "groundY": 423,
    "heightScale": 0.86,
    "frames": [
      {
        "grade": "Perfect",
        "index": 0,
        "source": [
          0,
          0,
          444,
          469
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Perfect",
        "index": 1,
        "source": [
          444,
          0,
          443,
          469
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Perfect",
        "index": 2,
        "source": [
          887,
          0,
          444,
          469
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Perfect",
        "index": 3,
        "source": [
          1331,
          0,
          443,
          469
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Great",
        "index": 0,
        "image": "sprites/enemies/variants/mafia_short_slim_great_heads_v8.png",
        "source": [
          0,
          0,
          615,
          780
        ],
        "destination": [
          271.79999999999995,
          18.119999999999948,
          344.40000000000003,
          436.80000000000007
        ],
        "durationMs": 85
      },
      {
        "grade": "Great",
        "index": 1,
        "image": "sprites/enemies/variants/mafia_short_slim_great_heads_v8.png",
        "source": [
          615,
          0,
          639,
          780
        ],
        "destination": [
          265.08,
          16.43999999999994,
          357.84000000000003,
          436.80000000000007
        ],
        "durationMs": 85
      },
      {
        "grade": "Great",
        "index": 2,
        "image": "sprites/enemies/variants/mafia_short_slim_great_atlas_v7.png",
        "source": [
          0,
          780,
          615,
          474
        ],
        "destination": [
          271.79999999999995,
          193.39999999999998,
          344.40000000000003,
          265.44
        ],
        "durationMs": 85
      },
      {
        "grade": "Great",
        "index": 3,
        "image": "sprites/enemies/variants/mafia_short_slim_great_atlas_v7.png",
        "source": [
          615,
          780,
          639,
          474
        ],
        "destination": [
          265.08,
          186.11999999999998,
          357.84000000000003,
          265.44
        ],
        "durationMs": 85
      }
    ],
    "note": "Perfect unchanged. Great v7 redrawn from this character aim only, preserving build and dark suit. One fixed scale per character; no per-frame auto-fit."
  },
  {
    "id": "burly",
    "name": "덩치 큰 마피아",
    "aim": "sprites/enemies/variants/mafia_burly_aim_v1.png",
    "atlas": "sprites/enemies/variants/mafia_burly_knockdown_atlas_v2.png",
    "imageSize": [
      1774,
      887
    ],
    "logicalFrameSize": [
      888,
      510
    ],
    "drawOffsetX": 222,
    "groundY": 472,
    "heightScale": 1,
    "frames": [
      {
        "grade": "Perfect",
        "index": 0,
        "source": [
          0,
          0,
          444,
          510
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Perfect",
        "index": 1,
        "source": [
          444,
          0,
          443,
          510
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Perfect",
        "index": 2,
        "source": [
          887,
          0,
          444,
          510
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Perfect",
        "index": 3,
        "source": [
          1331,
          0,
          443,
          510
        ],
        "offsetY": 0,
        "durationMs": 100
      },
      {
        "grade": "Great",
        "index": 0,
        "image": "sprites/enemies/variants/mafia_burly_great_atlas_v7.png",
        "source": [
          0,
          0,
          615,
          780
        ],
        "destination": [
          228.75,
          -6.099999999999966,
          430.5,
          546
        ],
        "durationMs": 85
      },
      {
        "grade": "Great",
        "index": 1,
        "image": "sprites/enemies/variants/mafia_burly_great_atlas_v7.png",
        "source": [
          615,
          0,
          639,
          780
        ],
        "destination": [
          220.35000000000002,
          -1.1999999999999886,
          447.29999999999995,
          546
        ],
        "durationMs": 85
      },
      {
        "grade": "Great",
        "index": 2,
        "image": "sprites/enemies/variants/mafia_burly_great_atlas_v7.png",
        "source": [
          0,
          780,
          615,
          474
        ],
        "destination": [
          228.75,
          210.2,
          430.5,
          331.79999999999995
        ],
        "durationMs": 85
      },
      {
        "grade": "Great",
        "index": 3,
        "image": "sprites/enemies/variants/mafia_burly_great_atlas_v7.png",
        "source": [
          615,
          780,
          639,
          474
        ],
        "destination": [
          220.35000000000002,
          197.60000000000002,
          447.29999999999995,
          331.79999999999995
        ],
        "durationMs": 85
      }
    ],
    "note": "Perfect unchanged. Great v7 redrawn from this character aim only, preserving build and dark suit. One fixed scale per character; no per-frame auto-fit."
  }
];
const enemyVariantImages = new Map();
let enemyVariantsReady;
function prepareEnemyVariants() {
  return enemyVariantsReady ??= Promise.all(enemyVariantDefinitions.flatMap(definition => [definition.aim, definition.atlas, ...definition.frames.map(frame => frame.image).filter(Boolean)]).map(src => {
    const image = new Image(); image.src = src; enemyVariantImages.set(src, image);
    return image.decode();
  })).catch(error => { enemyVariantsReady = null; throw error; });
}
function chooseEnemyVariant() {
  const index = Math.floor(Math.random() * (enemyVariantDefinitions.length + 1));
  const definition = index === 0 ? null : enemyVariantDefinitions[index - 1];
  if (!definition) return null;
  return [definition.aim, definition.atlas, ...definition.frames.map(frame => frame.image).filter(Boolean)].every(src => {
    const image = enemyVariantImages.get(src);
    return image?.complete && image.naturalWidth > 0;
  }) ? definition : null;
}
function positionVariantKnockdown(target) {
  const definition = target.enemyVariant;
  const canvas = target.knockdownSprite;
  const scale = target.enemyHeight / definition.logicalFrameSize[1];
  canvas.style.width = definition.logicalFrameSize[0] * scale + 'px';
  canvas.style.height = target.enemyHeight + 'px';
  // Match the aim sprite's foot baseline while allowing the body to fall sideways.
  canvas.style.top = 'calc(50% + ' + (target.enemyHeight * .43 - definition.groundY * scale + target.enemyHeight / 2) + 'px)';
}
function playVariantKnockdown(target) {
  const definition = target.enemyVariant;
  const canvas = document.createElement('canvas');
  [canvas.width, canvas.height] = definition.logicalFrameSize;
  canvas.className = 'enemy-knockdown';
  target.knockdownSprite = canvas;
  target.enemy.style.visibility = 'hidden';
  target.enemy.parentElement.append(canvas);
  positionVariantKnockdown(target);
  const frames = definition.frames.filter(frame => frame.grade === (target.hitJudgement === 'Perfect' ? 'Perfect' : 'Great'));
  const draw = frame => {
    if (!canvas.isConnected) return;
    const context = canvas.getContext('2d');
    context.clearRect(0, 0, canvas.width, canvas.height);
    const destination = frame.destination ?? [definition.drawOffsetX ?? 0, frame.offsetY, frame.source[2], frame.source[3]];
    context.drawImage(enemyVariantImages.get(frame.image ?? definition.atlas), ...frame.source, ...destination);
    canvas.dataset.frame = String(frame.index);
  };
  draw(frames[0]);
  for (let i = 1; i < frames.length; i++) gameRuntime.setTimeout(() => draw(frames[i]), i * frames[i].durationMs);
}
