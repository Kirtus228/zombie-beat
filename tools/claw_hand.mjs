
// Удар зомби = паковский удар (как у главного героя, тот же кадр и та же рука),
// но вместо КУЛАКА — раскрытая когтистая кисть ТОГО ЖЕ размера.
// Кулак в кадре пака висит в воздухе (за ним фон), поэтому его можно стереть
// целиком и поставить на его место ладонь с пальцами — рука при этом остаётся
// паковской: та же толщина, тот же контур, та же палитра.
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');
const SHOTS = path.join(ROOT, 'shots');

const SKIN = [152, 182, 138], INK = [34, 36, 30], NAIL = [196, 208, 184];

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

const W = 260, H = 227;

// рисуем кисть: ладонь + пальцы. inkPx — толщина контура, как у пака (1-2 px).
function makeHand(baseData, cfg) {
  const d = new Uint8Array(baseData);
  // 1) стираем старый кулак (за ним фон)
  for (let y = cfg.erase.y0; y <= cfg.erase.y1; y++)
    for (let x = cfg.erase.x0; x <= cfg.erase.x1; x++) {
      const i = (y * W + x) * 4;
      d[i] = 0; d[i + 1] = 0; d[i + 2] = 0; d[i + 3] = 0;
    }
  // 2) силуэт кисти
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
  // ладонь
  mark(cfg.palm.x, cfg.palm.y, cfg.palm.rx, cfg.palm.ry);
  // пальцы: [x0,y0,x1,y1]
  const tips = [];
  for (const f of cfg.fingers) {
    capsule(f[0], f[1], f[2], f[3], cfg.fingerR, cfg.fingerR - 0.35);
    tips.push({ x: f[2], y: f[3] });
  }
  // большой палец
  capsule(cfg.thumb[0], cfg.thumb[1], cfg.thumb[2], cfg.thumb[3], cfg.fingerR, cfg.fingerR - 0.3);
  tips.push({ x: cfg.thumb[2], y: cfg.thumb[3] });
  // 3) контур в стиле пака: ink-пиксели там, где рядом фон (не на теле)
  const opaque = (x, y) => d[(y * W + x) * 4 + 3] > 40;
  const inkMask = new Uint8Array(W * H);
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      if (!M[y * W + x]) continue;
      for (let dy = -cfg.inkPx; dy <= cfg.inkPx; dy++)
        for (let dx = -cfg.inkPx; dx <= cfg.inkPx; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          if (!M[ny * W + nx] && !opaque(nx, ny)) inkMask[ny * W + nx] = 1;
        }
    }
  // 4) рисуем: ink, потом кожа внутри силуэта, потом когти
  const put = (x, y, c) => {
    const i = (y * W + x) * 4;
    d[i] = c[0]; d[i + 1] = c[1]; d[i + 2] = c[2]; d[i + 3] = 255;
  };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (inkMask[y * W + x]) put(x, y, INK);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (M[y * W + x]) put(x, y, SKIN);
  for (const t of tips) {
    put(t.x, t.y, NAIL);
    put(t.x - Math.sign(t.x - cfg.palm.x), t.y + 0.5, NAIL);
  }
  return d;
}

// ЗАМАХ: кадр пака punch1_0 (рука отведена, как у героя на замахе)
const windCfg = {
  erase: { x0: 141, y0: 80, x1: 162, y1: 107 },
  palm: { x: 150, y: 95, rx: 5.6, ry: 6.6 },
  fingers: [[152, 91, 155, 80], [154, 92, 160, 82], [155, 96, 162, 90], [154, 99, 160, 96]],
  thumb: [147, 100, 143, 106],
  fingerR: 2.1, inkPx: 1,
};
// УДАР: кадр пака punch2_2 (рука вытянута вперёд) — рука толстая, как у пака
const goCfg = {
  erase: { x0: 169, y0: 82, x1: 198, y1: 122 },
  palm: { x: 173, y: 101, rx: 7.0, ry: 8.6 },
  fingers: [[176, 94, 188, 86], [177, 96, 192, 92], [177, 100, 193, 99], [177, 104, 192, 105], [176, 107, 187, 112]],
  thumb: [171, 108, 176, 118],
  fingerR: 2.3, inkPx: 1,
};

const wind = decodePNG(path.join(SRC, 'punch2_1.png')).data;   // замах = паковский замах
const go = makeHand(decodePNG(path.join(SRC, 'punch2_2.png')).data, goCfg);
const back = decodePNG(path.join(SRC, 'punch2_1.png')).data;

for (const [n, d] of [['claw_wind', wind], ['claw_go', go], ['claw_back', back]])
  fs.writeFileSync(path.join(SHOTS, 'v-' + n + '.png'), encodePNG(W, H, d));
console.log('ok v-claw_wind / v-claw_go / v-claw_back');
