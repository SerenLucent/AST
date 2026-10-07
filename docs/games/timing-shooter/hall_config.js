(function (root) {
  const config = {
    background: 'backgrounds/mafia_fountain_hall_v1.png',
    riseMs: 420,
    slots: [
      { id: 'fountain_left', worldX: 0.41, footY: 0.59, heightRatio: 0.20, rise: true, clipBottomY: 0.602 },
      { id: 'fountain_right', worldX: 0.59, footY: 0.59, heightRatio: 0.20, rise: true, clipBottomY: 0.602 },
      // Keep slot IDs stable for the server; these enemies now emerge beside the plants.
      { id: 'column_left', worldX: 0.296, footY: 0.514, heightRatio: 0.16, cover: 'plant' },
      { id: 'column_right', worldX: 0.704, footY: 0.514, heightRatio: 0.16, cover: 'plant' },
      { id: 'balcony_left', worldX: 0.37, footY: 0.33, heightRatio: 0.135 },
      { id: 'balcony_right', worldX: 0.63, footY: 0.33, heightRatio: 0.135 },
      { id: 'stairs_left', worldX: 0.285, footY: 0.63, heightRatio: 0.23, depth: 3 },
      { id: 'stairs_right', worldX: 0.715, footY: 0.63, heightRatio: 0.23, depth: 3 }
    ],
    // These polygons expose only existing scenery pixels in the foreground layer.
    occluders: [
      { id: 'fountain', polygon: '35% 51%, 38% 50%, 62% 50%, 65% 51%, 65% 55%, 67.5% 58.5%, 65% 60.5%, 35% 60.5%, 32.5% 58.5%, 35% 55%' },
      { id: 'plant_left', polygon: '26.7% 42.3%, 24.7% 41.6%, 25.2% 43%, 24% 43.3%, 25.3% 44%, 24.1% 45.5%, 25.4% 45%, 25% 47.8%, 26.2% 47.3%, 26.2% 48.5%, 26% 49%, 26.2% 50.5%, 26.9% 51%, 27.8% 50.8%, 28.1% 49%, 27.6% 48.5%, 27.6% 47.5%, 28.3% 47.4%, 29.5% 47.7%, 28.7% 46%, 30.1% 45.7%, 28.9% 45%, 30% 44.4%, 28.3% 43.7%, 29% 42.9%, 27.7% 43.1%, 27.3% 42%' },
      { id: 'plant_right', polygon: '73.3% 42.3%, 75.3% 41.6%, 74.8% 43%, 76% 43.3%, 74.7% 44%, 75.9% 45.5%, 74.6% 45%, 75% 47.8%, 73.8% 47.3%, 73.8% 48.5%, 74% 49%, 73.8% 50.5%, 73.1% 51%, 72.2% 50.8%, 71.9% 49%, 72.4% 48.5%, 72.4% 47.5%, 71.7% 47.4%, 70.5% 47.7%, 71.3% 46%, 69.9% 45.7%, 71.1% 45%, 70% 44.4%, 71.7% 43.7%, 71% 42.9%, 72.3% 43.1%, 72.7% 42%' },
      { id: 'front_column_left', depth: 4, polygon: '15% 0%, 22% 0%, 22% 40%, 24% 42%, 24% 55%, 21% 57%, 12% 57%, 12% 44%, 15% 40%' },
      { id: 'front_column_right', depth: 4, polygon: '78% 0%, 85% 0%, 85% 40%, 88% 44%, 88% 57%, 79% 57%, 76% 55%, 76% 42%, 78% 40%' },
      { id: 'balcony', polygon: '27% 27%, 73% 27%, 73% 34%, 27% 34%' }
    ]
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = config;
  else root.TIMING_SHOOTER_HALL = config;
})(typeof window !== 'undefined' ? window : globalThis);
