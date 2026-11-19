
// Кадры удара зомби «рукой сверху вниз» на кадрах пака.
// Приём: НЕ стираем руку целиком — у пака нет кадра с опущенной рукой, но есть
// кадры, где кисть висит в воздухе (punch1_0 — рука поднята) и где кисть перед
// грудью (punch2_1). Стираем только КИСТЬ (маленькая область), дорисовываем
// предплечье по нужной дуге и раскрытую когтистую ладонь.
// Тело, голова, шорты, ноги остаются паком.
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');
const SHOTS = path.join(ROOT, 'shots');

const SKIN = [152, 182, 138], INK = [34, 36, 30], NAIL = [188, 202, 176];

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

const SRC_FRAMES = { wind: 'punch1_0', go: 'punch2_1', back: 'punch2_1' };
const ref = decodePNG(path.join(SRC, 'punch2_1.png'));
const W = ref.w, H = ref.h;

// стираем только область кисти и заливаем вдоль строки (майка плоская)
function eraseHand(d, box) {
  for (let y = box.y0; y <= box.y1; y++)
    for (let x = box.x0; x <= box.x1; x++) {
      const i = (y * W + x) * 4;
      if (d[i + 3] > 40) { d[i] = 0; d[i + 1] = 0; d[i + 2] = 0; d[i + 3] = 0; }
    }
  for (let y = box.y0; y <= box.y1; y++)
    for (let x = box.x0; x <= box.x1; x++) {
      const i = (y * W + x) * 4;
      if (d[i + 3] > 40) continue;
      let col = null;
      for (let step = 1; step < 40 && !col; step++) {
        for (const nx of [x - step, x + step]) {
          if (nx < 0 || nx >= W) continue;
          const ni = (y * W + nx) * 4;
          if (d[ni + 3] < 40) continue;
          const c = [d[ni], d[ni + 1], d[ni + 2]];
          if (c[0] < 70 && c[1] < 70 && c[2] < 70) continue;
          col = c; break;
        }
      }
      if (!col) continue;
      d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
    }
}

function paint(d) {
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
  // ладонь + четыре пальца веером + большой палец, когти светлее кожи
  const hand = (wrist, angDeg, spreadDeg, len, palmR) => {
    mark(wrist.x, wrist.y, palmR + 0.8, palmR + 1.3);
    const a0 = angDeg * Math.PI / 180, sp = spreadDeg * Math.PI / 180;
    const tips = [];
    for (let k = -2; k <= 1; k++) {
      const ang = a0 + (k / 1.6) * sp;
      const bx = wrist.x + Math.cos(ang) * palmR * 0.6, by = wrist.y + Math.sin(ang) * palmR * 0.6;
      const tx = wrist.x + Math.cos(ang) * len, ty = wrist.y + Math.sin(ang) * len;
      tips.push({ x: tx, y: ty });
      capsule(bx, by, tx, ty, 3.4, 2.2);
    }
    const th = a0 + sp * 2.1;
    capsule(wrist.x, wrist.y, wrist.x + Math.cos(th) * len * 0.58, wrist.y + Math.sin(th) * len * 0.58, 3.2, 2.2);
    return tips;
  };
  const finish = () => {
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
  };
  return { mark, capsule, put, hand, finish };
}

// --- кадры ---
// 1) замах: рука поднята выше головы. База punch1_0 — там кисть уже в воздухе.
function frameWind() {
  const d = new Uint8Array(decodePNG(path.join(SRC, SRC_FRAMES.wind + '.png')).data);
  eraseHand(d, { x0: 138, y0: 78, x1: 162, y1: 106 });
  const p = paint(d);
  p.capsule(147, 104, 151, 84, 5.6, 4.8);      // предплечье вверх
  p.mark(148, 100, 6.0, 6.5);                  // плечо/локоть чуть полнее
  const tips = p.hand({ x: 152, y: 82 }, -86, 30, 12, 4.0);
  p.finish();
  for (const t of tips) p.put(t.x, t.y, NAIL);
  return d;
}
// 2) удар: рука опущена вниз-вперёд. База punch2_1 — кисть перед грудью.
function frameDown(low) {
  const d = new Uint8Array(decodePNG(path.join(SRC, SRC_FRAMES.go + '.png')).data);
  eraseHand(d, { x0: 166, y0: 86, x1: 194, y1: 120 });
  const p = paint(d);
  const wrist = low ? { x: 186, y: 132 } : { x: 184, y: 122 };
  const elbow = low ? { x: 170, y: 116 } : { x: 168, y: 110 };
  p.capsule(elbow.x, elbow.y, wrist.x, wrist.y, 5.6, 4.8);
  p.mark(elbow.x, elbow.y, 5.6, 6.0);
  const tips = p.hand(wrist, low ? 74 : 52, 30, 11, 3.8);
  p.finish();
  for (const t of tips) p.put(t.x, t.y, NAIL);
  return d;
}

const frames = { claw_wind: frameWind(), claw_go: frameDown(false), claw_back: frameDown(true) };
for (const [name, d] of Object.entries(frames)) fs.writeFileSync(path.join(SHOTS, 'rig-' + name + '.png'), encodePNG(W, H, d));
console.log('ok 3 frames -> shots/rig-claw_*.png');
