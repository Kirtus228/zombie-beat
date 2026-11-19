
// Зомби-марионетка: НЕ рисуем модель заново, а режем кадр пака на части и двигаем их.
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const ASSETS = path.join(ROOT, 'assets/zombie');

function decodePNG(file) {
  const buf = fs.readFileSync(file);
  let pos = 8, w = 0, h = 0, bitDepth = 0, colorType = 0; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos); const type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); bitDepth = data[8]; colorType = data[9]; }
    else if (type === 'IDAT') { idat.push(data); }
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (bitDepth !== 8 || (colorType !== 6 && colorType !== 2)) throw new Error('unsupported png');
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

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = c ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
function encodePNG(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

function cls(r, g, b) {
  if (r < 75 && g < 75 && b < 75) return 'ink';
  if (g > 160 && b < 160 && b > 100 && r < 180) return 'skin';
  if (r > 140 && g > 120 && b < 115) return 'hair';
  if (r > 210 && g > 210 && b > 190) return 'white';
  if (Math.abs(r - 104) < 20 && Math.abs(g - 100) < 20 && Math.abs(b - 96) < 20) return 'tank';
  if (Math.abs(r - 96) < 22 && Math.abs(g - 104) < 22 && Math.abs(b - 74) < 22) return 'short';
  if (r > 95 && b > 95 && b >= g) return 'shoe';
  return 'skin';
}

const src = decodePNG(path.join(ASSETS, 'idle.png'));
const W = src.w, H = src.h;
const PIVOT = { head: [145, 84], torso: [145, 149], shorts: [145, 149], armN: [129, 92], armF: [163, 94], legF: [131, 169], legN: [146, 169] };
// у каждой части свой словарь: индекс исходного пикселя -> цвет (одна точка может
// входить в две части с разным цветом — так заделываются перекрытия)
const parts = {};
const TANK = [104, 100, 96], SHORT = [96, 104, 74];
for (const n of Object.keys(PIVOT)) parts[n] = new Map();
for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4;
    if (src.data[i + 3] < 40) continue;
    const r = src.data[i], g = src.data[i + 1], b = src.data[i + 2], a = src.data[i + 3];
    const c = cls(r, g, b);
    let t;
    if (y <= 88) t = 'head';
    else if (y >= 144 && y <= 169 && (c === 'short' || c === 'ink')) t = 'shorts';
    else if (y <= 147) {
      if (x >= 160 && y <= 122) t = 'armF';
      else if (x <= 134 && y >= 87) t = 'armN';
      else t = 'torso';
    } else if (y >= 162) t = x <= 138 ? 'legF' : 'legN';
    else t = 'torso';
    const idx = y * W + x;
    if (t !== 'torso' && t !== 'shorts') parts[t].set(idx, [r, g, b]);
    // дубли: рука закрывала грудь, нога — шорты. В марионетке эти места закрываем
    // цветом одежды, иначе при повороте открывается прозрачная дырка

  }
}

function fillHoles(rowFrom, rowTo, xFrom, xTo, col) {
  for (let y = rowFrom; y <= rowTo; y++) {
    let l = -1, r = -1;
    for (let x = xFrom; x <= xTo; x++) {
      const i = (y * W + x) * 4;
      if (src.data[i + 3] >= 40) { if (l < 0) l = x; r = x; }
    }
    if (l < 0) continue;
    for (let x = l; x <= r; x++) {
      const i = (y * W + x) * 4;
      if (src.data[i + 3] >= 40) continue;
      src.data[i] = col[0]; src.data[i + 1] = col[1]; src.data[i + 2] = col[2]; src.data[i + 3] = 255;
    }
  }
}
// Сплошные майка и шорты: по строкам заливаем силуэт одеждой, контур — по краям.
// Иначе пиксели рук, вырезанные из торса, оставляют «точечный» узор.
const INK = [34, 36, 30];
function solidCloth(partName, y0, y1, x0, x1, col) {
  for (let y = y0; y <= y1; y++) {
    let l = -1, r = -1;
    for (let x = x0; x <= x1; x++) {
      const i = (y * W + x) * 4;
      if (src.data[i + 3] < 40) continue;
      const cl = cls(src.data[i], src.data[i + 1], src.data[i + 2]);
      if (cl !== 'tank') continue;
      if (l < 0) l = x; r = x;
    }
    if (l < 0) continue;
    parts[partName].set(y * W + l - 1, INK);
    parts[partName].set(y * W + r + 1, INK);
    for (let x = l; x <= r; x++) parts[partName].set(y * W + x, col);
  }
}
solidCloth('torso', 88, 147, 112, 159, TANK);
solidCloth('shorts', 146, 170, 112, 159, SHORT);

const rot = (px, py, a) => [px * Math.cos(a) - py * Math.sin(a), px * Math.sin(a) + py * Math.cos(a)];

function compose(pose) {
  const out = new Uint8Array(W * H * 4);
  const order = ['legF', 'armF', 'legN', 'shorts', 'torso', 'armN', 'head'];
  const ang = { legF: pose.legF || 0, legN: pose.legN || 0, armF: pose.armF || 0, armN: pose.armN || 0, torso: pose.torso || 0, shorts: pose.torso || 0, head: pose.head || 0 };
  const offx = pose.dx || 0, offy = pose.dy || 0;
  for (const name of order) {
    const map = parts[name];
    if (map.size === 0) continue;
    const [pvx, pvy] = PIVOT[name];
    const a = ang[name] * Math.PI / 180;
    const ca = Math.cos(a), sa = Math.sin(a);
    // bbox части после поворота
    let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
    for (const idx of map.keys()) {
      const sx = idx % W, sy = (idx - sx) / W;
      const X = pvx + (sx - pvx) * ca - (sy - pvy) * sa + offx;
      const Y = pvy + (sx - pvx) * sa + (sy - pvy) * ca + offy;
      if (X < x0) x0 = X; if (X > x1) x1 = X;
      if (Y < y0) y0 = Y; if (Y > y1) y1 = Y;
    }
    const cx0 = Math.max(0, Math.floor(x0)), cx1 = Math.min(W - 1, Math.ceil(x1));
    const cy0 = Math.max(0, Math.floor(y0)), cy1 = Math.min(H - 1, Math.ceil(y1));
    // обратное отображение: для каждого пикселя экрана ищем исходный пиксель части
    for (let Y = cy0; Y <= cy1; Y++) {
      for (let X = cx0; X <= cx1; X++) {
        const dx = X - pvx - offx, dy = Y - pvy - offy;
        const sx = Math.round(pvx + dx * ca + dy * sa);
        const sy = Math.round(pvy - dx * sa + dy * ca);
        if (sx < 0 || sy < 0 || sx >= W || sy >= H) continue;
        const col = map.get(sy * W + sx);
        if (!col) continue;
        const di = (Y * W + X) * 4;
        out[di] = col[0]; out[di + 1] = col[1]; out[di + 2] = col[2]; out[di + 3] = 255;
      }
    }
  }
  return out;
}

function save(name, pose) {
  fs.writeFileSync(path.join(ASSETS, name + '.png'), encodePNG(W, H, compose(pose)));
  console.log('wrote', name);
}

const mode = process.argv[2] || 'anim';
if (mode === 'parts') {
  for (const n of Object.keys(PIVOT)) {
    const map = parts[n];
    if (map.size === 0) { console.log('НЕТ ЧАСТИ', n); continue; }
    let bx0 = 1e9, bx1 = -1e9, by0 = 1e9, by1 = -1e9;
    for (const idx of map.keys()) {
      const x = idx % W, y = (idx - x) / W;
      bx0 = Math.min(bx0, x); bx1 = Math.max(bx1, x); by0 = Math.min(by0, y); by1 = Math.max(by1, y);
    }
    console.log(n, 'bbox', bx0, by0, (bx1 - bx0 + 1) + 'x' + (by1 - by0 + 1), 'px', map.size);
  }
} else {
  save('z_idle', {});
  for (let i = 0; i < 6; i++) {
    const t = i / 6 * Math.PI * 2;
    save('z_walk_' + i, {
      torso: 12 + 2 * Math.sin(t), head: -8 + 2.5 * Math.sin(t + 1),
      legN: -14 * Math.sin(t) + 4, legF: 8 * Math.sin(t + Math.PI) - 2,
      armN: 6 + 7 * Math.sin(t + Math.PI / 2), armF: 4 + 6 * Math.sin(t),
      dy: 1.5 * Math.cos(t)
    });
  }
  const atk = [
    { torso: -6, head: 8, armN: -130, armF: -140, legN: 4, legF: -2, dy: 0 },
    { torso: -2, head: 10, armN: -150, armF: -158, legN: 2, legF: -4, dy: -1 },
    { torso: 22, head: -6, armN: -75, armF: -85, legN: -12, legF: 8, dy: 1 },
    { torso: 28, head: -10, armN: -25, armF: -35, legN: -16, legF: 10, dy: 2 },
    { torso: 14, head: -4, armN: -8, armF: -14, legN: -6, legF: 4, dy: 0 }
  ];
  for (let i = 0; i < atk.length; i++) save('z_atk_' + i, atk[i]);
}