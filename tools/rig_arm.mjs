
// Рука удара в стиле пака: ТОЛСТЫЙ ЧЁРНЫЙ КОНТУР (2 px) и тонкая кожа внутри —
// как у паковских рук и ног (skin 4-7 px + ink 2-3 px по сторонам).
// Тело и вторая рука — кадр пака idle, не тронуты. Стирается только поднятая
// рука пака правее плеча (за ней фон, торс не задет).
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');
const SHOTS = path.join(ROOT, 'shots');

const SKIN = [152, 182, 138], INK = [34, 36, 30], NAIL = [188, 202, 176];
const SH = { x: 164, y: 100 };
const ERASE = { x0: 164, x1: 210, y0: 78, y1: 132 };
const ERASE_FLAP = { x0: 159, x1: 170, y0: 104, y1: 132 };

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

// строим руку: наружный силуэт -> контур 2 px -> кожа внутри
function drawArm(outer, core, chain, hand, inkPx) {
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
  // плечо (широкое, уходит под майку)
  mark(SH.x, SH.y, 6.5, 7.5);
  for (let i = 0; i < chain.length - 1; i++) {
    const a = chain[i], b = chain[i + 1];
    capsule(a.x, a.y, b.x, b.y, a.r, b.r);
  }
  // кисть: ладонь и пальцы — наружным радиусом на 1 px больше кожи
  const wrist = chain[chain.length - 1];
  mark(wrist.x, wrist.y, hand.palm, hand.palm + 1);
  const a0 = hand.ang * Math.PI / 180, sp = hand.spread * Math.PI / 180;
  const tips = [];
  for (let k = -2; k <= 1; k++) {
    const ang = a0 + (k / 1.7) * sp;
    const bx = wrist.x + Math.cos(ang) * (hand.palm - 1), by = wrist.y + Math.sin(ang) * (hand.palm - 1);
    const tx = wrist.x + Math.cos(ang) * hand.len, ty = wrist.y + Math.sin(ang) * hand.len;
    tips.push({ x: tx, y: ty });
    capsule(bx, by, tx, ty, 2.6, 1.9);
  }
  const th = a0 + sp * 2.0;
  capsule(wrist.x, wrist.y, wrist.x + Math.cos(th) * hand.len * 0.62, wrist.y + Math.sin(th) * hand.len * 0.62, 2.5, 1.9);

  // ядро = эрозия наружного силуэта на inkPx
  const inside = (x, y) => x >= 0 && y >= 0 && x < W && y < H && M[y * W + x];
  const K = new Uint8Array(W * H);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      if (!M[y * W + x]) continue;
      let ok = true;
      for (let dy = -inkPx; dy <= inkPx && ok; dy++)
        for (let dx = -inkPx; dx <= inkPx && ok; dx++)
          if (!inside(x + dx, y + dy)) ok = false;
      if (ok) K[y * W + x] = 1;
    }
  const put = (x, y, c) => {
    const i = (y * W + x) * 4;
    outer[i] = c[0]; outer[i + 1] = c[1]; outer[i + 2] = c[2]; outer[i + 3] = 255;
  };
  // контур: только там, где фон (на теле контура нет — рука выходит из-под майки)
  const opaqueBase = (x, y) => base.data[(y * W + x) * 4 + 3] > 40 && !K[y * W + x];
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      if (!M[y * W + x]) continue;
      if (K[y * W + x]) continue;
      // контур рисуем, если рядом фон или уже нарисованный контур
      let nearBg = false;
      for (let dy = -1; dy <= 1 && !nearBg; dy++)
        for (let dx = -1; dx <= 1 && !nearBg; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          if (!M[ny * W + nx] && !opaqueBase(nx, ny)) nearBg = true;
        }
      if (nearBg) put(x, y, INK);
    }
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) if (K[y * W + x]) put(x, y, core);
  for (const t of tips) put(Math.round(t.x), Math.round(t.y), NAIL);
  return outer;
}

function build(chain, hand, inkPx) {
  const d = new Uint8Array(base.data);
  for (const b of [ERASE, ERASE_FLAP])
    for (let y = b.y0; y <= b.y1; y++)
      for (let x = b.x0; x <= b.x1; x++) {
        const i = (y * W + x) * 4;
        d[i] = 0; d[i + 1] = 0; d[i + 2] = 0; d[i + 3] = 0;
      }
  return drawArm(d, SKIN, chain, hand, inkPx);
}

const variants = {
  A: { ink: 2, chain: { wind: [[{ x: SH.x, y: SH.y, r: 5.6 }, { x: 170, y: 84, r: 4.6 }, { x: 176, y: 66, r: 3.8 }], { ang: -84, spread: 30, len: 12, palm: 4 }] } },
};
// три варианта толщины/формы (ink 2 px у всех — как у пака)
const make = (ink, bw) => ({
  wind: [[{ x: SH.x, y: SH.y, r: bw }, { x: 170, y: 84, r: bw - 1.0 }, { x: 176, y: 66, r: bw - 1.8 }], { ang: -84, spread: 30, len: 12, palm: bw - 1.4 }],
  go: [[{ x: SH.x, y: SH.y, r: bw }, { x: 181, y: 113, r: bw - 1.0 }, { x: 194, y: 121, r: bw - 1.8 }], { ang: 22, spread: 32, len: 12, palm: bw - 1.4 }],
  back: [[{ x: SH.x, y: SH.y, r: bw }, { x: 175, y: 129, r: bw - 1.0 }, { x: 181, y: 144, r: bw - 1.8 }], { ang: 76, spread: 30, len: 11, palm: bw - 1.6 }],
});
const sets = { A: make(1, 6.0), B: make(2, 6.5), C: make(2, 7.5) };
for (const [k, set] of Object.entries(sets))
  for (const phase of ['wind', 'go', 'back']) {
    const d = build(set[phase][0], set[phase][1], k === 'A' ? 1 : 2);
    fs.writeFileSync(path.join(SHOTS, 'var' + k + '-' + phase + '.png'), encodePNG(W, H, d));
  }
console.log('ok variants A/B/C');
