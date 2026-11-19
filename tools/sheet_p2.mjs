
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
const items = [['idle', D], ['p2-claw_wind', S], ['p2-claw_go', S], ['p2-claw_back', S]];
const CW = 150, CH = 205, X0 = 95, Y0 = 20, Z = 4, gap = 8;
const dst = blank(gap + items.length * (CW * Z + gap), gap + CH * Z, [26, 26, 34]);
items.forEach(([n, dir], i) => {
  const img = decodePNG(dir + n + '.png');
  blit(dst, img, gap + i * (CW * Z + gap), gap, Z, X0, Y0, CW, CH);
});
save(S + 'p2-sheet.png', dst);
// замер толщины: горизонтальная ширина руки на трёх уровнях в кадре удара
for (const n of ['p2-claw_wind', 'p2-claw_go']) {
  const img = decodePNG(S + n + '.png');
  const rows = [];
  for (let y = 70; y <= 130; y += 10) {
    let runs = 0, start = -1;
    for (let x = 160; x < 210; x++) {
      const i = (y * img.w + x) * 4;
      const on = img.data[i + 3] > 40;
      if (on && start < 0) start = x;
      if (!on && start >= 0) { runs = Math.max(runs, x - start); start = -1; }
    }
    if (runs) rows.push('y=' + y + ':' + runs + 'px');
  }
  console.log(n, rows.join(' '));
}
