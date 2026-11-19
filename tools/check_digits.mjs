
import { decodePNG } from './pngtool.mjs';
const S = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat/shots/';
for (const n of ['v-claw_wind', 'v-claw_go']) {
  const img = decodePNG(S + n + '.png');
  const seen = new Uint8Array(img.w * img.h);
  const isNail = (i) => img.data[i + 3] > 40 && Math.abs(img.data[i] - 196) < 12 && Math.abs(img.data[i + 1] - 208) < 12 && Math.abs(img.data[i + 2] - 184) < 12;
  let blobs = 0;
  for (let y = 0; y < img.h; y++)
    for (let x = 0; x < img.w; x++) {
      const idx = y * img.w + x;
      if (seen[idx] || !isNail(idx * 4)) continue;
      blobs++;
      const st = [idx];
      while (st.length) {
        const i2 = st.pop();
        if (seen[i2]) continue;
        const xx = i2 % img.w, yy = (i2 - xx) / img.w;
        if (!isNail(i2 * 4)) continue;
        seen[i2] = 1;
        for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1]]) {
          const nx = xx + dx, ny = yy + dy;
          if (nx < 0 || ny < 0 || nx >= img.w || ny >= img.h) continue;
          st.push(ny * img.w + nx);
        }
      }
    }
  console.log(n, 'nail clusters =', blobs);
}
