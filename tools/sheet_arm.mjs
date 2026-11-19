
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
function down(img, k) {
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
const items = [['idle', D], ['rig2-claw_wind', S], ['rig2-claw_go', S], ['rig2-claw_back', S]];
const CW = 140, CH = 200, X0 = 95, Y0 = 25, Z = 4, gap = 8;
const dst = blank(gap + items.length * (CW * Z + gap), gap + CH * Z + 150, [26, 26, 34]);
items.forEach(([n, dir], i) => {
  const img = decodePNG(dir + n + '.png');
  blit(dst, img, gap + i * (CW * Z + gap), gap, Z, X0, Y0, CW, CH);
  const small = down(img, 0.62);
  blit(dst, small, gap + i * (CW * Z + gap) + 20, gap + CH * Z + 20, 2, 0, 0, small.w, small.h);
});
save(S + 'arm-updown.png', dst);
console.log('ok', dst.w, dst.h);
