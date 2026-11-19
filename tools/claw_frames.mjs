
// Кадры удара зомби: раскрытые когти бьют СВЕРХУ ВНИЗ (царапают), не кулаком вперёд.
// База — кадр пака punch2_0 (корпус пака, ноги, голова). Правый «ударный» рукав
// пака заменяется своей рукой в палитре пака: плечо -> локоть -> запястье и
// раскрытая кисть. Рука начинается ПОД майкой, поэтому контур рисуется только
// по границе с фоном и рука не выглядит налепленной.
import fs from 'node:fs';
import zlib from 'node:zlib';
import path from 'node:path';

const ROOT = 'D:/OneDrive/Desktop/Mobidick/games/zombie-beat';
const SRC = path.join(ROOT, 'assets/zombie');

const SKIN = [152, 182, 138], INK = [34, 36, 30], NAIL = [186, 200, 174], TANK = [104, 100, 96];
const ERASE = { x0: 146, x1: 206, y0: 82, y1: 126 };

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

const base = decodePNG(path.join(SRC, 'punch2_0.png'));
const W = base.w, H = base.h;
const isSkin = (d, i) => d[i + 3] > 40 && d[i + 1] > 160 && d[i + 2] < 160 && d[i] < 190;
const isInk = (d, i) => d[i + 3] > 40 && d[i] < 75 && d[i + 1] < 75 && d[i + 2] < 75;

function prepareBody() {
  const d = new Uint8Array(base.data);
  for (let y = ERASE.y0; y <= ERASE.y1; y++)
    for (let x = ERASE.x0; x <= ERASE.x1; x++) {
      const i = (y * W + x) * 4;
      if (isSkin(d, i) || isInk(d, i)) { d[i] = 0; d[i + 1] = 0; d[i + 2] = 0; d[i + 3] = 0; }
    }
  // дыры от стёртой руки закрашиваем НЕ одним цветом, а цветом ближайшего
  // соседа: под рукой могла быть майка, шорты или нога — иначе на шортах
  // остаётся серая заплатка
  const seen = new Uint8Array(W * H);
  const stack = [];
  for (let x = 0; x < W; x++) { stack.push(x, 0); stack.push(x, H - 1); }
  for (let y = 0; y < H; y++) { stack.push(0, y); stack.push(W - 1, y); }
  while (stack.length) {
    const y = stack.pop(), x = stack.pop();
    if (x < 0 || y < 0 || x >= W || y >= H) continue;
    const idx = y * W + x;
    if (seen[idx] || d[idx * 4 + 3] > 40) continue;
    seen[idx] = 1;
    stack.push(x + 1, y); stack.push(x - 1, y); stack.push(x, y + 1); stack.push(x, y - 1);
  }
  // очередь волной от непрозрачных пикселей внутрь дыр
  const fillQ = [];
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const idx = y * W + x;
      if (seen[idx] || d[idx * 4 + 3] > 40) continue;   // только дыры внутри силуэта
      for (let dy = -1; dy <= 1; dy++)
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          if (d[(ny * W + nx) * 4 + 3] > 40) fillQ.push(idx);
        }
    }
  const done = new Uint8Array(W * H);
  while (fillQ.length) {
    const idx = fillQ.shift();
    if (done[idx]) continue;
    done[idx] = 1;
    const x = idx % W, y = (idx - x) / W;
    let col = null;
    for (let dy = -1; dy <= 1 && !col; dy++)
      for (let dx = -1; dx <= 1 && !col; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
        const ni = (ny * W + nx) * 4;
        if (d[ni + 3] > 40) col = [d[ni], d[ni + 1], d[ni + 2]];
      }
    if (!col) continue;
    const i = idx * 4;
    d[i] = col[0]; d[i + 1] = col[1]; d[i + 2] = col[2]; d[i + 3] = 255;
    for (let dy = -1; dy <= 1; dy++)
      for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
        const nidx = ny * W + nx;
        if (seen[nidx] && !done[nidx]) fillQ.push(nidx);
      }
  }
  return d;
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
  // кисть: ладонь + четыре пальца веером + большой; когти светлые
  const hand = (wrist, angDeg, spreadDeg, len, palmR) => {
    mark(wrist.x, wrist.y, palmR + 1.0, palmR + 1.5);
    const a0 = angDeg * Math.PI / 180;
    const spread = spreadDeg * Math.PI / 180;
    const tips = [];
    for (let k = -2; k <= 1; k++) {
      const ang = a0 + (k / 1.6) * spread;
      const bx = wrist.x + Math.cos(ang) * palmR * 0.6;
      const by = wrist.y + Math.sin(ang) * palmR * 0.6;
      const tx = wrist.x + Math.cos(ang) * len;
      const ty = wrist.y + Math.sin(ang) * len;
      tips.push({ x: tx, y: ty });
      capsule(bx, by, tx, ty, 4.0, 2.8);
    }
    const th = a0 + spread * 2.0;
    capsule(wrist.x, wrist.y, wrist.x + Math.cos(th) * len * 0.6, wrist.y + Math.sin(th) * len * 0.6, 3.0, 2.1);
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

// плечо внутри силуэта, чтобы рука выходила из-под майки
const SH = { x: 158, y: 100 };
function frameArm(chain, handCfg) {
  const d = prepareBody();
  const p = paint(d);
  p.mark(SH.x, SH.y, 6.5, 8.0);             // плечо
  for (let i = 0; i < chain.length - 1; i++) {
    const a = chain[i], b = chain[i + 1];
    p.capsule(a.x, a.y, b.x, b.y, a.r, b.r);
  }
  const tips = p.hand(handCfg.wrist, handCfg.ang, handCfg.spread, handCfg.len, handCfg.palmR);
  p.finish();
  for (const t of tips) p.put(t.x, t.y, NAIL);
  return d;
}

const frames = {
  // замах: рука вскинута, когти раскрыты вверх-вперёд
  claw_wind: [
    [{ x: SH.x, y: SH.y, r: 7.0 }, { x: 170, y: 82, r: 5.6 }, { x: 177, y: 66, r: 4.6 }],
    { wrist: { x: 178, y: 64 }, ang: -80, spread: 30, len: 10, palmR: 4.6 },
  ],
  // удар: рука проходит вниз-вперёд, когти у корпуса героя
  claw_go: [
    [{ x: SH.x, y: SH.y, r: 7.0 }, { x: 180, y: 112, r: 5.6 }, { x: 194, y: 122, r: 4.6 }],
    { wrist: { x: 195, y: 123 }, ang: 24, spread: 32, len: 10, palmR: 4.6 },
  ],
  // проводка: когти уходят к полу
  claw_back: [
    [{ x: SH.x, y: SH.y, r: 7.0 }, { x: 178, y: 126, r: 5.6 }, { x: 186, y: 142, r: 4.6 }],
    { wrist: { x: 187, y: 143 }, ang: 68, spread: 30, len: 10, palmR: 4.4 },
  ],
};
for (const [name, [chain, hand]] of Object.entries(frames)) {
  const d = frameArm(chain, hand);
  fs.writeFileSync(path.join(SRC, name + '.png'), encodePNG(W, H, d));
  console.log('ok', name);
}
