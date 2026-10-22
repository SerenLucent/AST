import {ASSETS} from './asset-manifest.mjs?v=20261022-mic1';

const pending = new Map();
export function assetUrl(source) {
  const asset = ASSETS[source];
  if (!asset) throw new Error('이미지 목록에 없는 파일: ' + source);
  return asset.url;
}

// Reuse decoded images within a page. Content-hashed URLs also reuse the
// browser's HTTP cache across room navigation without cache-busting downloads.
export function loadAsset(source) {
  if (pending.has(source)) return pending.get(source);
  const work = new Promise((resolve, reject) => {
    const im = new Image();
    im.decoding = 'async';
    im.onload = async () => {
      try { if (im.decode) await im.decode(); resolve(im); }
      catch { reject(new Error('이미지 불러오기 실패: ' + source)); }
    };
    im.onerror = () => reject(new Error('이미지 불러오기 실패: ' + source));
    im.src = assetUrl(source);
  });
  pending.set(source, work);
  work.catch(() => { if (pending.get(source) === work) pending.delete(source); });
  return work;
}

// No getImageData / multi-million-pixel scan on a user's phone.
export function spriteFrames(source, threshold = 30) {
  const frames = ASSETS[source]?.['frames' + threshold];
  if (!frames) throw new Error('가구 이미지 영역 정보 없음: ' + source);
  return frames;
}
