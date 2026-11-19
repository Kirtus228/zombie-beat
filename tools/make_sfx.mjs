// Синтез звуков боя и зомби: свой звук, без сторонних сэмплов и лицензий.
// Пишет build/sfx/<name>.wav; конвертация в ogg — tools/make_sfx.ps1 или ffmpeg.
import fs from 'node:fs';
import path from 'node:path';

const SR = 44100;

function noise() { return Math.random() * 2 - 1; }

// однополюсные фильтры — дешёвый способ придать «телесность» и «рык»
function lowpass(x, y, a) { return y + a * (x - y); }

function render(seconds, fn) {
  const n = Math.round(seconds * SR);
  const buf = new Float32Array(n);
  fn(buf, n);
  let peak = 0;
  for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(buf[i]));
  const g = peak > 0 ? 0.88 / peak : 1;
  for (let i = 0; i < n; i++) buf[i] = Math.tanh(buf[i] * g * 1.05) * 0.92;
  return buf;
}

function save(name, buf) {
  const out = path.join(process.cwd(), 'games/zombie-beat/build/sfx');
  fs.mkdirSync(out, { recursive: true });
  const data = Buffer.alloc(buf.length * 2);
  for (let i = 0; i < buf.length; i++) {
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, buf[i])) * 32767), i * 2);
  }
  const hdr = Buffer.alloc(44);
  hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + data.length, 4); hdr.write('WAVE', 8);
  hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20); hdr.writeUInt16LE(1, 22);
  hdr.writeUInt32LE(SR, 24); hdr.writeUInt32LE(SR * 2, 28); hdr.writeUInt16LE(2, 32); hdr.writeUInt16LE(16, 34);
  hdr.write('data', 36); hdr.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(out, name + '.wav'), Buffer.concat([hdr, data]));
  console.log('wrote', name + '.wav', (buf.length / SR).toFixed(2) + 's');
}

// свист удара: шум, проносящийся вниз по частоте
save('swing', render(0.18, (b, n) => {
  let lp = 0, lp2 = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, k = i / n;
    const cutoff = 0.42 - 0.34 * k;                 // «вжух» вниз
    lp = lowpass(noise(), lp, cutoff);
    lp2 = lowpass(lp, lp2, cutoff * 0.5);
    const env = Math.sin(Math.PI * Math.pow(k, 0.6)) ** 1.6;
    b[i] = (lp - lp2 * 0.6) * env * 1.4;
  }
}));

// попадание: низкий тумк + щелчок + короткий шумовой хруст
save('hit', render(0.22, (b, n) => {
  let lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, k = i / n;
    const f = 165 * Math.exp(-30 * t) + 52;
    const thump = Math.sin(2 * Math.PI * f * t) * Math.exp(-13 * t);
    const click = Math.exp(-260 * t) * 0.5;
    lp = lowpass(noise(), lp, 0.5 * Math.exp(-9 * t) + 0.06);
    const crunch = lp * Math.exp(-22 * t) * 0.9;
    b[i] = Math.tanh((thump * 1.1 + click + crunch) * 1.3) * (1 - 0.25 * k);
  }
}));

// рык зомби: пила с вибрато, придавленная фильтром + хрип
function growl(b, n, { f0 = 96, f1 = 62, dur = 1, rough = 0.35, breath = 0.22, trem = 4.5 }) {
  let lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, k = i / n;
    const f = (f0 + (f1 - f0) * k) * (1 + 0.03 * Math.sin(2 * Math.PI * 5.5 * t));
    // гармоники пилы, срезанные фильтром — получается «горловой» тон
    let v = 0;
    for (let h = 1; h <= 7; h++) v += Math.sin(2 * Math.PI * f * h * t) / (h * 1.25);
    lp = lowpass(v, lp, 0.16 + 0.1 * Math.sin(2 * Math.PI * trem * t));
    const gurgle = 1 - rough * (0.5 + 0.5 * Math.sin(2 * Math.PI * (7 + 9 * k) * t));
    b[i] = (lp * gurgle + noise() * breath * (0.6 + 0.4 * Math.sin(2 * Math.PI * 3 * t))) * Math.sin(Math.PI * Math.pow(k, 0.7));
  }
}

save('z_attack', render(0.5, (b, n) => growl(b, n, { f0: 128, f1: 74, rough: 0.42, breath: 0.3, trem: 6 })));
save('z_hurt', render(0.34, (b, n) => growl(b, n, { f0: 150, f1: 92, rough: 0.3, breath: 0.24, trem: 7.5 })));
save('z_death', render(1.1, (b, n) => growl(b, n, { f0: 105, f1: 44, rough: 0.5, breath: 0.34, trem: 3.2 })));
save('z_groan', render(1.4, (b, n) => growl(b, n, { f0: 84, f1: 70, rough: 0.22, breath: 0.18, trem: 3.0 })));

// герой получил по лицу: короткий выдох-стон
save('player_hurt', render(0.3, (b, n) => {
  let lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, k = i / n;
    const f = 210 - 70 * k;
    const v = Math.sin(2 * Math.PI * f * t) + Math.sin(2 * Math.PI * f * 2 * t) * 0.4;
    lp = lowpass(v + noise() * 0.5, lp, 0.35);
    b[i] = lp * Math.exp(-9 * t) * Math.sin(Math.PI * Math.pow(k, 0.5));
  }
}));
