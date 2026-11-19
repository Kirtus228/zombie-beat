
import { decodePNG, save, blank, blit } from './pngtool.mjs';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
const D = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/assets/zombie/';
// слева рука пака (протянутая, punch2_2), справа моя (удар) — крупно, для сверки стиля
const pack = decodePNG(D + 'punch2_2.png');
const mine = decodePNG(S + 'p2-claw_go.png');
const Z = 8, CW = 70, CH = 45;
const dst = blank(2 * CW * Z + 30, CH * Z + 20, [26, 26, 34]);
blit(dst, pack, 10, 10, Z, 130, 82, CW, CH);
blit(dst, mine, CW * Z + 20, 10, Z, 150, 82, CW, CH);
save(S + 'arm-compare.png', dst);
console.log('ok');
