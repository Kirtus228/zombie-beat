
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const CAPS = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/caps/';
const SHOTS = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const idx = [75, 76, 77, 78, 79, 80, 81, 82];
const CW = 300, CH = 250, S = 2, X0 = 25, Y0 = 230;
const cols = 4, gap = 6;
const W = cols * CW * S + (cols + 1) * gap, H = 2 * CH * S + 3 * gap;
const out = blank(W, H, [18, 18, 24]);
idx.forEach((n, i) => {
  const img = decodePNG(CAPS + 'cap_' + String(n).padStart(2, '0') + '.png');
  blit(out, img, gap + (i % cols) * (CW * S + gap), gap + Math.floor(i / cols) * (CH * S + gap), S, X0, Y0, CW, CH);
});
save(SHOTS + 'zombie-strike-frames.png', out);
const hit = decodePNG(CAPS + 'cap_80.png');
const big = blank(255 * 4, 225 * 4, [18, 18, 24]);
blit(big, hit, 0, 0, 4, 62, 250, 255, 225);
save(SHOTS + 'zombie-contact-zoom.png', big);
console.log('ok');
