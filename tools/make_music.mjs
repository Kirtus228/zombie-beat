// Синтез музыкального лупа для zombie-beat: свой трек, без чужих сэмплов.
// 150 BPM, D harmonic minor, 8 тактов = 12.8 с, зацикливается без стыка.
import fs from 'node:fs';
import path from 'node:path';

const SR = 44100;
const BPM = 150;
const STEP = 60 / BPM / 4;            // 16-я = 0.1 с
const BARS = 8;
const STEPS = BARS * 16;
const LEN = Math.round(STEPS * STEP * SR);   // сэмплов в лупе
const buf = new Float32Array(LEN);

// пишем «по кругу»: хвосты и задержки заворачиваются в начало — стык лупа без щелчка
function add(t, v) {
  const i = ((Math.round(t * SR) % LEN) + LEN) % LEN;
  buf[i] += v;
}

function env(t, dur, a = 0.004, decay = 1) {
  if (t < 0 || t > dur) return 0;
  const at = t < a ? t / a : 1;
  const dr = Math.exp(-decay * (t / dur) * 4);
  return at * dr;
}

function kick(t0, gain = 1) {
  for (let i = 0; i < 0.22 * SR; i++) {
    const t = i / SR;
    const f = 150 * Math.exp(-28 * t) + 46;
    add(t0 + t, Math.sin(2 * Math.PI * f * t) * Math.exp(-9 * t) * gain);
  }
}

function snare(t0, gain = 0.8) {
  let n = 0;
  for (let i = 0; i < 0.16 * SR; i++) {
    const t = i / SR;
    n = (n * 0.72 + (Math.random() * 2 - 1) * 0.28);
    const tone = Math.sin(2 * Math.PI * 185 * t) * Math.exp(-26 * t) * 0.35;
    add(t0 + t, (n * 1.5 + tone) * Math.exp(-16 * t) * gain);
  }
}

function hat(t0, gain = 0.25) {
  let prev = 0;
  for (let i = 0; i < 0.05 * SR; i++) {
    const t = i / SR;
    const r = Math.random() * 2 - 1;
    const hp = r - prev; prev = r;               // грубый хайпасс
    add(t0 + t, hp * Math.exp(-70 * t) * gain);
  }
}

function saw(f, t) { const p = (f * t) % 1; return 2 * p - 1; }
function sq(f, t) { return (f * t) % 1 < 0.5 ? 1 : -1; }

function bass(t0, freq, dur, gain = 0.55) {
  for (let i = 0; i < dur * SR; i++) {
    const t = i / SR;
    const v = sq(freq, t) * 0.6 + saw(freq * 1.005, t) * 0.4;
    add(t0 + t, Math.tanh(v * 1.6) * env(t, dur, 0.003, 1.1) * gain);
  }
}

function lead(t0, freq, dur, gain = 0.22) {
  for (let i = 0; i < dur * SR; i++) {
    const t = i / SR;
    const v = sq(freq, t) * 0.7 + saw(freq * 2.01, t) * 0.3;
    add(t0 + t, Math.tanh(v * 1.2) * env(t, dur, 0.002, 1.8) * gain);
  }
}

function stab(t0, freqs, dur, gain = 0.3) {
  for (let i = 0; i < dur * SR; i++) {
    const t = i / SR;
    let v = 0;
    for (const f of freqs) v += sq(f, t) * 0.5 + saw(f * 1.004, t) * 0.5;
    add(t0 + t, Math.tanh(v / freqs.length) * env(t, dur, 0.004, 2.4) * gain);
  }
}

const NOTE = { D1: 36.71, A1: 55.0, Bb1: 58.27, D2: 73.42, F2: 87.31, A2: 110.0, Bb2: 116.54, C2: 65.41, E3: 164.81, F3: 174.61, G3: 196.0, C4: 261.63, D4: 293.66, E4: 329.63, F4: 349.23, A4: 440.0 };
// D harmonic minor от D4: D E F G A Bb C#
const SCALE = [293.66, 329.63, 349.23, 392.0, 440.0, 466.16, 554.37];

// гармония по тактам: Dm | Dm | Bb | A | Dm | Dm | Bb | A  (A-мажор = напряжение)
const CHORDS = [
  { root: NOTE.D2, fifth: NOTE.A2, pad: [NOTE.D4, NOTE.F4, NOTE.A4] },
  { root: NOTE.D2, fifth: NOTE.A2, pad: [NOTE.D4, NOTE.F4, NOTE.A4] },
  { root: NOTE.Bb1, fifth: NOTE.F2, pad: [NOTE.Bb2 * 2, NOTE.D4, NOTE.F4] },
  { root: NOTE.A1, fifth: NOTE.E3, pad: [NOTE.A2 * 2, NOTE.C4 * 1.06, NOTE.E4] },
  { root: NOTE.D2, fifth: NOTE.A2, pad: [NOTE.D4, NOTE.F4, NOTE.A4] },
  { root: NOTE.D2, fifth: NOTE.A2, pad: [NOTE.D4, NOTE.F4, NOTE.A4] },
  { root: NOTE.Bb1, fifth: NOTE.F2, pad: [NOTE.Bb2 * 2, NOTE.D4, NOTE.F4] },
  { root: NOTE.A1, fifth: NOTE.E3, pad: [NOTE.A2 * 2, NOTE.C4 * 1.06, NOTE.E4] },
];

for (let s = 0; s < STEPS; s++) {
  const t = s * STEP;
  const bar = Math.floor(s / 16);
  const inBar = s % 16;
  const ch = CHORDS[bar];

  // бочка: четыре четверти + короткий «толчок» перед сменой фразы
  if (inBar % 4 === 0) kick(t);
  if (inBar === 14) kick(t, 0.6);

  // снейр: 2 и 4
  if (inBar === 4 || inBar === 12) snare(t);

  // хэты: все 16-е, ударные сильнее
  hat(t, inBar % 4 === 0 ? 0.18 : (inBar % 2 === 0 ? 0.13 : 0.09));

  // бас: восьмые, на «и» короче — тяга вперёд
  if (inBar % 2 === 0) bass(t, ch.root, STEP * 1.7, 0.5);
  if (inBar === 6 || inBar === 14) bass(t, ch.fifth, STEP * 1.2, 0.33);

  // стаб-аккорд на 1 и 3
  if (inBar === 0 || inBar === 8) stab(t, ch.pad, STEP * 3.2, 0.26);

  // арпеджио 16-ми по D harmonic minor
  const pattern = [0, 2, 4, 3, 4, 2, 5, 4];
  const idx = pattern[s % pattern.length] + (bar >= 4 ? 0 : 0);
  lead(t, SCALE[idx % SCALE.length] * (inBar >= 8 ? 2 : 1), STEP * 0.85, 0.13);

  // редкие «вздохи» для нервозности
  if (inBar === 7 && (bar === 3 || bar === 7)) lead(t, SCALE[6] * 2, STEP * 2.2, 0.1);
}

// райзер в последнем такте: шум с нарастанием — заворачивается в начало лупа
{
  let n = 0;
  const dur = STEP * 16;
  for (let i = 0; i < dur * SR; i++) {
    const t = i / SR;
    n = n * 0.6 + (Math.random() * 2 - 1) * 0.4;
    add((STEPS - 16) * STEP + t, n * Math.pow(t / dur, 2.2) * 0.22);
  }
}

// дилей на ведущую линию (3/16) — тоже по кругу
const dly = new Float32Array(LEN);
const dt = Math.round(STEP * 3 * SR);
for (let i = 0; i < LEN; i++) {
  const prev = dly[(i - dt + LEN) % LEN];
  dly[i] = buf[i] * 0.18 + prev * 0.42;
}

// микс + мягкий лимитер + нормализация
let peak = 0;
for (let i = 0; i < LEN; i++) {
  const v = Math.tanh((buf[i] + dly[i] * 0.5) * 1.15);
  buf[i] = v;
  if (Math.abs(v) > peak) peak = Math.abs(v);
}
const norm = 0.8 / (peak || 1);
for (let i = 0; i < LEN; i++) buf[i] *= norm;

// WAV 16 бит моно
const out = path.join(process.cwd(), 'games/zombie-beat/build/music');
fs.mkdirSync(out, { recursive: true });
const data = Buffer.alloc(LEN * 2);
for (let i = 0; i < LEN; i++) {
  const v = Math.max(-1, Math.min(1, buf[i]));
  data.writeInt16LE(Math.round(v * 32767), i * 2);
}
const hdr = Buffer.alloc(44);
hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + data.length, 4); hdr.write('WAVE', 8);
hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20); hdr.writeUInt16LE(1, 22);
hdr.writeUInt32LE(SR, 24); hdr.writeUInt32LE(SR * 2, 28); hdr.writeUInt16LE(2, 32); hdr.writeUInt16LE(16, 34);
hdr.write('data', 36); hdr.writeUInt32LE(data.length, 40);
const file = path.join(out, 'loop.wav');
fs.writeFileSync(file, Buffer.concat([hdr, data]));
console.log('wrote', file, (LEN / SR).toFixed(2) + 's', (LEN * 2 / 1024).toFixed(0) + ' KB');
