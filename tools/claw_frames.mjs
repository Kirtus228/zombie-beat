
// Когтистая кисть на кадре пака: НЕ рисуем зомби заново — берём кадр пака
// punch2_2 (рука вытянута вперёд) и раскрываем кулак в когтистую ладонь.
// Стиль тот же, что у пака: сплошная кожа + чернильный контур, пальцы — доли
// одного силуэта (а не тонкие палочки), между ними чернильные прорези.
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');

function decodePNG(file) {
  const buf = fs.readFileSync(file);
  let pos = 8, w = 0, h = 0, colorType = 0; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos); const type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); colorType = data[9]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  const channels = colorType === 6 ? 4 : 3;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = w * channels;
  const out = new Uint8Array(w * h * 4);
  let prev = new Uint8Array(stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const cur = new Uint8Array(stride);
    for (let i = 0; i < stride; i++) {
      const a = i >= channels ? cur[i - channels] : 0;
      const b = prev[i];
      const c = i >= channels ? prev[i - channels] : 0;
      let v = line[i];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += Math.floor((a + b) / 2);
      else if (f === 4) { const p = a + b - c; const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); }
      cur[i] = v & 0xff;
    }
    for (let x = 0; x < w; x++) {
      out[(y * w + x) * 4] = cur[x * channels];
      out[(y * w + x) * 4 + 1] = cur[x * channels + 1];
      out[(y * w + x) * 4 + 2] = cur[x * channels + 2];
      out[(y * w + x) * 4 + 3] = channels === 4 ? cur[x * channels + 3] : 255;
    }
    prev = cur;
  }
  return { w, h, data: out };
}
function crc32(buf) { let c, crc = 0xffffffff; for (let n = 0; n < buf.length; n++) { c = (crc ^ buf[n]) & 0xff; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crc = c ^ (crc >>> 8); } return (crc ^ 0xffffffff) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const t = Buffer.from(type, 'ascii'); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data]))); return Buffer.concat([len, t, data, crc]); }
function encodePNG(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

const SKIN = [152, 182, 138], INK = [34, 36, 30], NAIL = [182, 196, 170];

const base = decodePNG(path.join(SRC, 'punch2_2.png'));
const W = base.w, H = base.h;
const img = { w: W, h: H, d: new Uint8Array(base.data) };

function put(x, y, col) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  const i = (y * W + x) * 4;
  img.d[i] = col[0]; img.d[i + 1] = col[1]; img.d[i + 2] = col[2]; img.d[i + 3] = 255;
}
function opaque(x, y) { const i = (y * W + x) * 4; return img.d[i + 3] > 40; }

const M = new Uint8Array(W * H);
function markEllipse(cx, cy, rx, ry) {
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
    for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      if (x < 0 || y < 0 || x >= W || y >= H) continue;
      const dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) M[y * W + x] = 1;
    }
}

// 1) ладонь: продолжает кулак пака (центр кисти пака ~185,101)
markEllipse(186, 101, 5.5, 7.5);

function markCapsule(x0, y0, x1, y1, r0, r1) {
  const steps = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 3) + 1;
  for (let s = 0; s <= steps; s++) {
    const t = s / steps;
    const cx = x0 + (x1 - x0) * t, cy = y0 + (y1 - y0) * t;
    const r = r0 + (r1 - r0) * t;
    for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++)
      for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) {
        if (x < 0 || y < 0 || x >= W || y >= H) continue;
        const dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy <= r * r + 0.25) M[y * W + x] = 1;
      }
  }
}

// 2) четыре пальца: толстые, начинаются внутри ладони — поэтому силуэт один,
//    а край получается «веером» с лепестками, как у пака.
const fingers = [
  [185, 91, 198, 84, 3.1, 2.2],
  [185, 97, 202, 93, 3.3, 2.3],
  [185, 103, 202, 104, 3.3, 2.3],
  [185, 108, 197, 113, 3.0, 2.1],
];
for (const f of fingers) markCapsule(f[0], f[1], f[2], f[3], f[4], f[5]);
// 3) большой палец снизу
markCapsule(184, 111, 191, 120, 3.0, 2.0);
const lobes = fingers.map(f => ({ x: f[2], y: f[3] }));

// 4) контур наружу (1 px): пиксели рядом с силуэтом, где ещё пусто
const outline = new Uint8Array(W * H);
for (let y = 0; y < H; y++)
  for (let x = 0; x < W; x++) {
    if (!M[y * W + x]) continue;
    for (let dy = -1; dy <= 1; dy++)
      for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
        if (!M[ny * W + nx] && !opaque(nx, ny)) outline[ny * W + nx] = 1;
      }
  }
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (outline[y * W + x]) put(x, y, INK);
// 5) заливка кожи
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (M[y * W + x]) put(x, y, SKIN);

// 6) когти: чуть светлее кожи кончик — 1 px, чтобы на экране это был налёт
//    кости, а не белый веер
for (const f of fingers) put(f[2], f[3], NAIL);

fs.writeFileSync(path.join(SRC, 'claw_go.png'), encodePNG(W, H, img.d));
console.log('ok claw_go.png', W + 'x' + H);
