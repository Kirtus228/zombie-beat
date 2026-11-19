
// Рука по ПАРАМЕТРАМ ПАКА. Замерено на кадрах пака:
//   рука/нога: контур 2 px с каждой стороны, кожа 6-7 px, наружный диаметр ~11 px
//   пальцы: 2-3 px кожи, контур 1 px
// Значит: наружный радиус 5.5, эрозия под контур 2 px -> кожа 7 px. Никаких «на глаз».
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');
const SHOTS = path.join(ROOT, 'shots');

const SKIN = [152, 182, 138], INK = [34, 36, 30], NAIL = [196, 208, 184];
const SH = { x: 163, y: 103 };
const INK_PX = 2;
const R_SHOULDER = 5.5, R_ELBOW = 5.0, R_WRIST = 4.2;

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

const base = decodePNG(path.join(SRC, 'idle.png'));
const W = base.w, H = base.h;
const baseOpaque = (idx) => base.data[idx * 4 + 3] > 40;

function build(chain, hand) {
  const d = new Uint8Array(base.data);
  for (let y = 74; y <= 136; y++)
    for (let x = 164; x < W; x++) {
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
  mark(SH.x, SH.y, R_SHOULDER + 0.5, R_SHOULDER + 1.0);
  for (let i = 0; i < chain.length - 1; i++) {
    const a = chain[i], b = chain[i + 1];
    capsule(a.x, a.y, b.x, b.y, a.r, b.r);
  }
  const wrist = chain[chain.length - 1];
  mark(wrist.x, wrist.y, hand.palm, hand.palm + 1.2);
  const a0 = hand.ang * Math.PI / 180, sp = hand.spread * Math.PI / 180;
  const tips = [];
  for (let k = -2; k <= 1; k++) {
    const ang = a0 + (k / 1.7) * sp;
    const bx = wrist.x + Math.cos(ang) * (hand.palm - 1), by = wrist.y + Math.sin(ang) * (hand.palm - 1);
    const tx = wrist.x + Math.cos(ang) * hand.len, ty = wrist.y + Math.sin(ang) * hand.len;
    tips.push({ x: tx, y: ty });
    capsule(bx, by, tx, ty, 2.4, 1.9);
  }
  const th = a0 + sp * 2.0;
  capsule(wrist.x, wrist.y, wrist.x + Math.cos(th) * hand.len * 0.6, wrist.y + Math.sin(th) * hand.len * 0.62, 2.3, 1.9);

  // контур 2 px внутри силуэта (только там, где силуэт выходит на фон)
  const inner = new Uint8Array(W * H);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      if (!M[y * W + x]) continue;
      let edge = false;
      for (let dy = -INK_PX; dy <= INK_PX && !edge; dy++)
        for (let dx = -INK_PX; dx <= INK_PX && !edge; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) { edge = true; break; }
          if (!M[ny * W + nx]) edge = true;
        }
      if (edge) inner[y * W + x] = 1;
    }
  const put = (x, y, c) => {
    const i = (y * W + x) * 4;
    d[i] = c[0]; d[i + 1] = c[1]; d[i + 2] = c[2]; d[i + 3] = 255;
  };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (M[y * W + x]) put(x, y, INK);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (M[y * W + x] && !inner[y * W + x]) put(x, y, SKIN);
  for (const t of tips) put(t.x, t.y, NAIL);
  return d;
}

const wind = build(
  [{ x: SH.x, y: SH.y, r: R_SHOULDER }, { x: 171, y: 86, r: R_ELBOW }, { x: 174, y: 70, r: R_WRIST }],
  { ang: -86, spread: 28, len: 11, palm: 4.4 },
);
const go = build(
  [{ x: SH.x, y: SH.y, r: R_SHOULDER }, { x: 180, y: 112, r: R_ELBOW }, { x: 193, y: 120, r: R_WRIST }],
  { ang: 24, spread: 30, len: 11, palm: 4.6 },
);
const back = build(
  [{ x: SH.x, y: SH.y, r: R_SHOULDER }, { x: 176, y: 128, r: R_ELBOW }, { x: 182, y: 143, r: R_WRIST }],
  { ang: 74, spread: 28, len: 10, palm: 4.2 },
);

for (const [n, d] of [['claw_wind', wind], ['claw_go', go], ['claw_back', back]])
  fs.writeFileSync(path.join(SHOTS, 'p2-' + n + '.png'), encodePNG(W, H, d));
console.log('ok p2-claw_wind/go/back');
