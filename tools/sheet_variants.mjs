
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
const phases = ['wind', 'go', 'back'];
const CW = 115, CH = 170, X0 = 110, Y0 = 45, Z = 4, gap = 8;
const rows = ['A', 'B', 'C'];
const cols = 4;
const dst = blank(gap + cols * (CW * Z + gap), gap + rows.length * (CH * Z + gap), [26, 26, 34]);
rows.forEach((v, r) => {
  const base = decodePNG(D + 'idle.png');
  blit(dst, base, gap, gap + r * (CH * Z + gap), Z, X0, Y0, CW, CH);
  phases.forEach((p, i) => {
    const img = decodePNG(S + 'var' + v + '-' + p + '.png');
    blit(dst, img, gap + (i + 1) * (CW * Z + gap), gap + r * (CH * Z + gap), Z, X0, Y0, CW, CH);
  });
});
save(S + 'rig-variants.png', dst);
console.log('ok', dst.w, dst.h);
