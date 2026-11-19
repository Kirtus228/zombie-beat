
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
const names = ['idle', 'rig-wind', 'rig-go', 'rig-back'];
const CW = 130, CH = 200, X0 = 95, Y0 = 30;
const Z = 4, gap = 8;
// вторая строка — в игровом масштабе 0.62, как это выглядит на экране
function downscale(img, k) {
  const w = Math.max(1, Math.round(img.w * k)), h = Math.max(1, Math.round(img.h * k));
  const out = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const sx = Math.min(img.w - 1, Math.round(x / k)), sy = Math.min(img.h - 1, Math.round(y / k));
      const si = (sy * img.w + sx) * 4, di = (y * w + x) * 4;
      out[di] = img.data[si]; out[di + 1] = img.data[si + 1]; out[di + 2] = img.data[si + 2]; out[di + 3] = img.data[si + 3];
    }
  return { w, h, data: out };
}
const tileW = CW * Z, tileH = CH * Z;
const smallW = Math.round(240 * 0.62), smallH = Math.round(227 * 0.62);
const H = gap + tileH + gap + smallH * 3 + gap;
const W = gap + names.length * (tileW + gap);
const dst = blank(W, H, [26, 26, 34]);
names.forEach((n, i) => {
  const src = n.startsWith('rig-') ? S : D;
  const img = decodePNG(src + n + '.png');
  blit(dst, img, gap + i * (tileW + gap), gap, Z, X0, Y0, CW, CH);
  // мелкая версия: тот же кадр, масштаб игры, три копии подряд = «полоса анимации»
  const small = downscale(img, 0.62);
  for (let k = 0; k < 1; k++) {
    const ox = gap + i * (tileW + gap) + Math.round((tileW - smallW) / 2);
    const oy = gap + tileH + gap;
    blit(dst, small, ox, oy, 3, 0, 0, small.w, small.h);
  }
});
save(S + 'rig-sheet.png', dst);
console.log('ok', dst.w, dst.h);
