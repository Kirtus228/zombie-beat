
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const CAPS = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/caps/';
const SHOTS = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const idx = [61, 63, 65, 66, 68, 70, 71, 72];
const CW = 300, CH = 250, S = 2, X0 = 25, Y0 = 230;
const cols = 4, gap = 6;
const out = blank(cols * CW * S + (cols + 1) * gap, 2 * CH * S + 3 * gap, [18, 18, 24]);
idx.forEach((n, i) => {
  const img = decodePNG(CAPS + 'cap_' + String(n).padStart(2, '0') + '.png');
  blit(out, img, gap + (i % cols) * (CW * S + gap), gap + Math.floor(i / cols) * (CH * S + gap), S, X0, Y0, CW, CH);
});
save(SHOTS + 'zombie-strike-frames.png', out);
console.log('ok');
