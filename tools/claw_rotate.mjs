
// РУКА — ПАКОВСКАЯ, БЕЗ РИСОВАНИЯ.
// Берём кадр пака idle: у зомби там рука уже поднята, с РАСКРЫТОЙ кистью.
// Вырезаем её (только кожа и контур), стираем с кадра, дырку в майке заливаем
// ровно цветом майки пака, и ПОВОРАЧИВАЕМ вырезанную руку вокруг плеча:
// вверх — замах, вниз — удар. Пиксели, контур, когти — всё паковское.
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');
const SHOTS = path.join(ROOT, 'shots');

const TANK = [104, 100, 96], SKIN = [152, 182, 138], INK = [34, 36, 30];
const P = { x: 160, y: 101 };   // плечо (точка вращения)
const R = 46;
const REGION = { x0: 149, y0: 82, x1: 210, y1: 140 };

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

function isSkin(i) { return base.data[i + 3] > 40 && Math.abs(base.data[i] - 152) < 26 && Math.abs(base.data[i + 1] - 182) < 26 && Math.abs(base.data[i + 2] - 138) < 26; }
function isInk(i) { return base.data[i + 3] > 40 && base.data[i] < 80 && base.data[i + 1] < 80 && base.data[i + 2] < 80; }

// 1) маска руки: кожа/контур в области руки, в радиусе от плеча
const arm = new Uint8Array(W * H);
for (let y = REGION.y0; y <= REGION.y1; y++)
  for (let x = REGION.x0; x <= REGION.x1; x++) {
    const dx = x - P.x, dy = y - P.y;
    if (dx * dx + dy * dy > R * R) continue;
    const i = (y * W + x) * 4;
    if (isSkin(i) || isInk(i)) arm[y * W + x] = 1;
  }
// рука должна начинаться у плеча: нижнюю часть (кисть у груди) не трогаем
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (y < 84) arm[y * W + x] = 0;

// 2) тело без руки: стираем её и заливаем майкой то, что было на торсе
const body = new Uint8Array(base.data);
let erasedCount = 0;
for (let idx = 0; idx < W * H; idx++) {
  if (!arm[idx]) continue;
  const x = idx % W, y = (idx - x) / W;
  const i = idx * 4;
  body[i] = 0; body[i + 1] = 0; body[i + 2] = 0; body[i + 3] = 0;
  erasedCount++;
}

// 3) поворот руки вокруг плеча и вставка обратно
function frame(deg) {
  const d = new Uint8Array(body);
  const a = deg * Math.PI / 180, ca = Math.cos(-a), sa = Math.sin(-a);
  for (let y = Math.max(0, P.y - R - 4); y <= Math.min(H - 1, P.y + R + 4); y++)
    for (let x = Math.max(0, P.x - R - 4); x <= Math.min(W - 1, P.x + R + 4); x++) {
      const dx = x - P.x, dy = y - P.y;
      if (dx * dx + dy * dy > (R + 2) * (R + 2)) continue;
      const sx = Math.round(P.x + dx * ca - dy * sa);
      const sy = Math.round(P.y + dx * sa + dy * ca);
      if (sx < 0 || sy < 0 || sx >= W || sy >= H) continue;
      if (!arm[sy * W + sx]) continue;
      const si = (sy * W + sx) * 4, di = (y * W + x) * 4;
      d[di] = base.data[si]; d[di + 1] = base.data[si + 1]; d[di + 2] = base.data[si + 2]; d[di + 3] = 255;
    }
  return d;
}

// варианты углов: замах поднимаем, удар опускаем
for (const [n, deg] of [['wind', -40], ['go', 25], ['back', 60]])
  fs.writeFileSync(path.join(SHOTS, 'rot-' + n + '.png'), encodePNG(W, H, frame(deg)));
console.log('ok rot-wind/go/back, arm pixels =', erasedCount);
