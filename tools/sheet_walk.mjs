
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const names = ['walk_1', 'walk_2', 'idle'];
const CW = 140, CH = 200, X0 = 90, Y0 = 20, Z = 4, gap = 8;
const dst = blank(gap + names.length * (CW * Z + gap), gap + CH * Z, [26, 26, 34]);
names.forEach((n, i) => {
  const img = decodePNG(D + n + '.png');
  blit(dst, img, gap + i * (CW * Z + gap), gap, Z, X0, Y0, CW, CH);
});
save(S + 'walk12.png', dst);
console.log('ok');
