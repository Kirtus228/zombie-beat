
// Риг руки зомби: тело и ноги — кадр пака idle целиком, НИЧЕГО не заливаем.
// Стирается только поднятая рука пака правее плеча (она в воздухе, за ней фон),
// и на её месте рисуется своя рука в нужной фазе: вверх -> вниз.
// Вторая рука (у груди) остаётся паковской — зомби и так стоит с одной рукой у груди.
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');
const SHOTS = path.join(ROOT, 'shots');

const SKIN = [152, 182, 138], INK = [34, 36, 30], NAIL = [188, 202, 176];
const SHOULDER = { x: 162, y: 106 };
const ERASE = { x0: 164, x1: 210, y0: 80, y1: 132 };
// отдельный «остаток» паковского предплечья ниже плеча: сам он не нужен,
// потому что руку рисуем свою
const ERASE_FLAP = { x0: 157, x1: 168, y0: 108, y1: 134 };

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

const idle = decodePNG(path.join(SRC, 'idle.png'));
const W = idle.w, H = idle.h;

function build(chain, hand) {
  const d = new Uint8Array(idle.data);
  // стираем только руку пака правее плеча — за ней фон, торс не задет
  const boxes = [ERASE, ERASE_FLAP];
  for (const b of boxes)
    for (let y = b.y0; y <= b.y1; y++)
      for (let x = b.x0; x <= b.x1; x++) {
        const i = (y * W + x) * 4;
        d[i] = 0; d[i + 1] = 0; d[i + 2] = 0; d[i + 3] = 0;
      }
  const M = new Uint8Array(W * H);
  const mark = (cx, cy, rx, ry) => {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
      for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        if (x < 0 || y < 0 || x >= W || y >= H) continue;
        const dx = (x - cx) / rx, dy = (y - cy) / ry;
        if (dx * dx + dy * dy <= 1.0) M[y * W + x] = 1;
      }
  };
  const capsule = (x0, y0, x1, y1, r0, r1) => {
    const steps = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 3) + 1;
    for (let s = 0; s <= steps; s++) {
      const t = s / steps;
      mark(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r0 + (r1 - r0) * t, r0 + (r1 - r0) * t);
    }
  };
  const put = (x, y, col) => {
    x = Math.round(x); y = Math.round(y);
    if (x < 0 || y < 0 || x >= W || y >= H) return;
    const i = (y * W + x) * 4;
    d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
  };
  // плечо: круг, который перекрывает паковское плечо и стыкуется с торсом
  mark(SHOULDER.x, SHOULDER.y, 7.0, 8.0);
  for (let i = 0; i < chain.length - 1; i++) {
    const a = chain[i], b = chain[i + 1];
    capsule(a.x, a.y, b.x, b.y, a.r, b.r);
  }
  // кисть
  const wrist = chain[chain.length - 1];
  mark(wrist.x, wrist.y, hand.palm + 0.8, hand.palm + 1.3);
  const a0 = hand.ang * Math.PI / 180, sp = hand.spread * Math.PI / 180;
  const tips = [];
  for (let k = -2; k <= 1; k++) {
    const ang = a0 + (k / 1.6) * sp;
    const bx = wrist.x + Math.cos(ang) * hand.palm * 0.6, by = wrist.y + Math.sin(ang) * hand.palm * 0.6;
    const tx = wrist.x + Math.cos(ang) * hand.len, ty = wrist.y + Math.sin(ang) * hand.len;
    tips.push({ x: tx, y: ty });
    capsule(bx, by, tx, ty, 3.4, 2.2);
  }
  const th = a0 + sp * 2.1;
  capsule(wrist.x, wrist.y, wrist.x + Math.cos(th) * hand.len * 0.58, wrist.y + Math.sin(th) * hand.len * 0.58, 3.2, 2.2);
  // контур только по границе с фоном
  const opaque = (x, y) => d[(y * W + x) * 4 + 3] > 40;
  const ink = new Uint8Array(W * H);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      if (!M[y * W + x]) continue;
      for (let dy = -1; dy <= 1; dy++)
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          if (!M[ny * W + nx] && !opaque(nx, ny)) ink[ny * W + nx] = 1;
        }
    }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (ink[y * W + x]) put(x, y, INK);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (M[y * W + x]) put(x, y, SKIN);
  for (const t of tips) put(t.x, t.y, NAIL);
  return d;
}

// 1) замах: рука вскинута над головой, когти раскрыты
const wind = build(
  [{ x: SHOULDER.x, y: SHOULDER.y, r: 7.4 }, { x: 168, y: 86, r: 6.0 }, { x: 177, y: 66, r: 5.0 }],
  { ang: -80, spread: 30, len: 13, palm: 4.4 },
);
// 2) удар: рука проходит вниз-вперёд, когти у корпуса героя
const go = build(
  [{ x: SHOULDER.x, y: SHOULDER.y, r: 7.4 }, { x: 181, y: 112, r: 6.0 }, { x: 195, y: 121, r: 5.0 }],
  { ang: 20, spread: 32, len: 12, palm: 4.4 },
);
// 3) проводка: когти уходят вниз
const back = build(
  [{ x: SHOULDER.x, y: SHOULDER.y, r: 7.4 }, { x: 176, y: 129, r: 6.0 }, { x: 182, y: 145, r: 5.0 }],
  { ang: 72, spread: 30, len: 11, palm: 4.2 },
);

for (const [n, d] of [['wind', wind], ['go', go], ['back', back]])
  fs.writeFileSync(path.join(SHOTS, 'rig-' + n + '.png'), encodePNG(W, H, d));
console.log('ok rig-wind/go/back');
