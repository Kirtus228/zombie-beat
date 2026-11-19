
// Риг руки зомби, шаг 1: тело без рук.
// Тело берём из кадра пака idle, стираем обе руки и ВОССТАНАВЛИВАЕМ торс по
// геометрии (майка — плоское пятно, поэтому её можно залить цветом и обвести
// контуром, как это сделано в паке). Это разметка, а не «ближайший цвет».
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');
const SHOTS = path.join(ROOT, 'shots');

const SKIN = [152, 182, 138], INK = [34, 36, 30];
const TANK = [104, 100, 96], SHORTS = [96, 104, 74];

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

// --- разметка тела (снята с кадра пака) ---
// майка: прямоугольник; вырез — треугольник с кожей; выше — шея/плечи
const TANK_BOX = { x0: 103, x1: 168, y0: 100, y1: 150 };
const VNECK = { x0: 114, x1: 136, y0: 96, y1: 126 };   // в нём кожа
const NECK = { x0: 112, x1: 152, y0: 84, y1: 101 };    // плечи/шея — кожа
const ARMS = [
  { x0: 158, x1: 204, y0: 76, y1: 132 },   // дальняя рука, поднята с когтями
  { x0: 108, x1: 142, y0: 84, y1: 142 },   // ближняя рука через грудь
];

const d = new Uint8Array(base.data);
const inBox = (b, x, y) => x >= b.x0 && x <= b.x1 && y >= b.y0 && y <= b.y1;
const erased = new Uint8Array(W * H);
for (const a of ARMS)
  for (let y = a.y0; y <= a.y1; y++)
    for (let x = a.x0; x <= a.x1; x++) {
      const i = (y * W + x) * 4;
      if (d[i + 3] < 40) continue;
      d[i] = 0; d[i + 1] = 0; d[i + 2] = 0; d[i + 3] = 0;
      erased[y * W + x] = 1;
    }

// заливка по разметке: майка / вырез / шея / шорты
function fillColour(x, y) {
  if (y >= TANK_BOX.y0 - 2 && y <= TANK_BOX.y1 + 2 && x >= TANK_BOX.x0 && x <= TANK_BOX.x1) {
    if (inBox(VNECK, x, y)) return SKIN;
    return TANK;
  }
  if (inBox(NECK, x, y)) return SKIN;
  if (y > 150 && y < 175 && x > 108 && x < 165) return SHORTS;
  return null;   // фон
}
for (let y = 0; y < H; y++)
  for (let x = 0; x < W; x++) {
    const idx = y * W + x;
    if (!erased[idx]) continue;
    const c = fillColour(x, y);
    if (!c) continue;
    const i = idx * 4;
    d[i] = c[0]; d[i + 1] = c[1]; d[i + 2] = c[2]; d[i + 3] = 255;
  }
// контур по границе залитого с фоном — как обводка в паке
{
  const outline = [];
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const idx = y * W + x;
      if (d[idx * 4 + 3] > 40) continue;
      for (let dy = -1; dy <= 1; dy++)
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          if (erased[ny * W + nx] && d[(ny * W + nx) * 4 + 3] > 40) { outline.push([x, y]); dx = 2; dy = 2; }
        }
    }
  for (const [x, y] of outline) {
    const i = (y * W + x) * 4;
    d[i] = INK[0]; d[i + 1] = INK[1]; d[i + 2] = INK[2]; d[i + 3] = 255;
  }
}

fs.writeFileSync(path.join(SHOTS, 'rig-body.png'), encodePNG(W, H, d));
fs.writeFileSync(path.join(SRC, '_rig_body.png'), encodePNG(W, H, d));
console.log('ok rig-body');
