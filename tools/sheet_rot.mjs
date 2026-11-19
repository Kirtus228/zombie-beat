
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
const items = [['idle', D], ['rot-wind', S], ['rot-go', S], ['rot-back', S]];
const CW = 150, CH = 200, X0 = 95, Y0 = 25, Z = 4, gap = 8;
const dst = blank(gap + items.length * (CW * Z + gap), gap + CH * Z, [26, 26, 34]);
items.forEach(([n, dir], i) => {
  const img = decodePNG(dir + n + '.png');
  blit(dst, img, gap + i * (CW * Z + gap), gap, Z, X0, Y0, CW, CH);
});
save(S + 'rot-sheet.png', dst);
console.log('ok');
