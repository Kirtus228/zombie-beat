
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
import fs from 'node:fs';
const names = fs.readdirSync(D).filter(f => f.endsWith('.png') && !f.startsWith('_')).map(f => f.replace('.png', '')).sort();
const CW = 100, CH = 175, X0 = 70, Y0 = 40, Z = 2, gap = 4;
const cols = 6;
const rows = Math.ceil(names.length / cols);
const dst = blank(gap + cols * (CW * Z + gap), gap + rows * (CH * Z + gap), [26, 26, 34]);
names.forEach((n, i) => {
  const img = decodePNG(D + n + '.png');
  blit(dst, img, gap + (i % cols) * (CW * Z + gap), gap + Math.floor(i / cols) * (CH * Z + gap), Z, X0, Y0, CW, CH);
});
save(S + 'all-frames.png', dst);
console.log('ok', dst.w, dst.h, '|', names.join(' '));
