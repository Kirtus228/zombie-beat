// Синтез звуков боя и зомби: свой звук, без сторонних сэмплов и лицензий.
// Пишет build/sfx/<name>.wav; конвертация в ogg — ffmpeg (см. docs/sfx-report.md).
import fs from 'node:fs';
import path from 'node:path';

const SR = 44100;

// детерминированный генератор: звуки воспроизводятся байт в байт при пересборке
let rnd = 0x2f6e2b1;
function rand() {
  rnd |= 0; rnd = (rnd + 0x6d2b79f5) | 0;
  let t = Math.imul(rnd ^ (rnd >>> 15), 1 | rnd);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
function noise() { return rand() * 2 - 1; }

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

// ---------- ГОРЛО ЗОМБИ ----------
// Глоттальный импульс (сумма гармоник в узкий импульс), jitter, субгармоника f/2,
// подвижные форманты гласных, дыхание перед звуком, хвост с гарглом.

// полосовой биквад (RBJ), пик на f с усилением 1
function band() {
  let b0 = 0, b1 = 0, b2 = 0, a1 = 0, a2 = 0, x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  return {
    set(f, q) {
      const w = 2 * Math.PI * f / SR, al = Math.sin(w) / (2 * q), a0 = 1 + al;
      b0 = al / a0; b1 = 0; b2 = -al / a0;
      a1 = -2 * Math.cos(w) / a0; a2 = (1 - al) / a0;
    },
    tick(x) {
      const y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1; x1 = x; y2 = y1; y1 = y; return y;
    },
  };
}

const VOWEL = {
  a: [730, 1090, 2440],
  o: [450, 800, 2400],
  u: [500, 900, 2400],
  y: [500, 900, 2400],
};

// плавный перевод формантов между гласными (доля k от длительности)
function vowelTrack(list, k) {
  let i = 0;
  while (i < list.length - 2 && k > list[i + 1][1]) i++;
  const a = list[i], b = list[Math.min(i + 1, list.length - 1)];
  const span = Math.max(1e-6, b[1] - a[1]);
  let u = Math.max(0, Math.min(1, (k - a[1]) / span));
  u = u * u * (3 - 2 * u);
  return VOWEL[a[0]].map((f, j) => f + (VOWEL[b[0]][j] - f) * u);
}

function growl(b, n, opt) {
  const {
    f0 = 100, f1 = 70,                 // высота в начале и в конце, Гц
    vowels = [['a', 0], ['o', 1]],     // из какой гласной в какую
    breath = 0.2,                      // доля дыхания 10–25 %
    inhale = 0.1,                      // вдох перед звуком, с
    attack = 0.06,                     // атака голоса, с
    gurgle = 0.4,                      // сила гаргла в хвосте
    creak = 0.35,                      // субгармоника f/2
    trem = 0.25,                       // трепет горла, амплитуда
    tremHz = 22,                       // частота трепета 15–30 Гц
    rough = 1,                         // общая «грязность»
  } = opt;

  const dur = n / SR;
  const tIn = inhale;
  const H = 18;                        // число гармоник глоттального источника

  const F = [band(), band(), band()];
  const FQ = [9, 11, 10];              // F1 пошире: его гармоники не проваливаются
  const FW = [1.5, 0.85, 0.18];        // F1 громче (он и в речи несёт больше всего), F3 тише
  for (let j = 0; j < 3; j++) F[j].set(VOWEL.a[j], FQ[j]);

  const breathF = band();              // дыхание 1–4 кГц
  breathF.set(2200, 0.9);
  const gurgleF = band();              // низкий резонатор гаргла
  gurgleF.set(240, 6);
  const gurgleF2 = band();
  gurgleF2.set(430, 7);

  let phase = 0, cyc = 0;
  let jSlow = 0, jTarget = 0;
  let jQuick = 0;
  let yBody = 0;                       // грудной корпус
  let yTop = 0, yTop2 = 0;             // мягкий срез верха
  let nBreath = 0, nGur = 0;           // срез верха у шума (белый шум ярчит)

  const jStep = Math.max(1, Math.round(0.02 * SR));

  for (let i = 0; i < n; i++) {
    const t = i / SR, k = t / dur;

    // jitter: медленный дрейф ±2.5 % + быстрый ±1 % на цикл
    if (i % jStep === 0) jTarget = (rand() * 2 - 1) * 0.025;
    jSlow += (jTarget - jSlow) * 0.0015;

    const fBase = f0 + (f1 - f0) * k;
    const fNow = Math.max(35, fBase * (1 + jSlow + jQuick));

    // глоттальный источник: гармоники с cos-фазами складываются в узкий импульс
    let src = 0;
    for (let h = 1; h <= H; h++) src += Math.cos(2 * Math.PI * h * phase) / Math.pow(h, 1.5);
    src /= 2.6;                        // нормировка; дальше всё равно нормализуем

    // субгармоника f/2 — «скрипучесть» мёртвого горла
    const sub = Math.sin(Math.PI * phase * 2) * 0.16 * creak;

    // ход фазы; на каждом обороте — новый быстрый jitter и лёгкая аритмия
    phase += fNow / SR;
    if (phase >= 1) {
      phase -= 1;
      cyc++;
      jQuick = (rand() * 2 - 1) * 0.01;
    }

    // форманты: переводим раз в 32 сэмпла
    if ((i & 31) === 0) {
      const v = vowelTrack(vowels, k);
      for (let j = 0; j < 3; j++) F[j].set(v[j], FQ[j]);
    }

    let voice = 0;
    for (let j = 0; j < 3; j++) voice += F[j].tick(src) * FW[j];
    voice += sub * 0.5;

    // грудной корпус 180 Гц, чтобы голос не был тощим
    yBody = lowpass(src, yBody, 0.025);
    voice += yBody * 0.5;

    // хрип: быстрая АМ голоса
    const am = 1 - trem * (0.5 + 0.5 * Math.sin(2 * Math.PI * tremHz * t));
    voice *= am;

    // огибающая: вдох, атака, спад
    let env;
    if (t < tIn) {
      env = 0;
    } else {
      const a = Math.min(1, (t - tIn) / attack);
      const att = a * a * (3 - 2 * a);
      const dec = Math.min(1, Math.pow(1 - k, 1.2) * 1.7);
      env = att * dec;
    }

    // дыхание: шум 1–4 кГц; вдох перед звуком, дальше — придыхание в голосе
    const brEnv = t < tIn
      ? Math.pow(t / Math.max(1e-6, tIn), 1.4) * 0.9
      : env * breath;
    nBreath = lowpass(noise(), nBreath, 0.25);
    const br = breathF.tick(nBreath) * brEnv * 0.5;

    // гаргл в хвосте: шум через низкие резонаторы с АМ 15–30 Гц
    const tail = Math.max(0, (k - 0.45) / 0.55);
    const gEnv = gurgle * tail * tail * (0.4 + 0.6 * env);
    const gAm = 0.5 + 0.5 * Math.sin(2 * Math.PI * (tremHz * 0.8) * t);
    nGur = lowpass(noise(), nGur, 0.08);
    const gur = (gurgleF.tick(nGur) + gurgleF2.tick(nGur) * 0.6) * gEnv * gAm * rough;

    // мягкий срез верха: два однополюсника ~1.2 кГц — голос не «цифровой»
    yTop = lowpass(voice * env, yTop, 0.14);
    yTop2 = lowpass(yTop, yTop2, 0.2);

    b[i] = yTop2 * 1.9 + br + gur * 0.5;
  }
}

save('z_attack', render(0.5, (b, n) => growl(b, n, {
  f0: 128, f1: 74, vowels: [['a', 0], ['y', 0.65], ['u', 1]],
  breath: 0.2, inhale: 0.1, attack: 0.05, gurgle: 0.45, creak: 0.4, trem: 0.3, tremHz: 26,
})));
save('z_hurt', render(0.34, (b, n) => growl(b, n, {
  f0: 150, f1: 92, vowels: [['u', 0], ['a', 0.7]],
  breath: 0.22, inhale: 0.09, attack: 0.04, gurgle: 0.3, creak: 0.3, trem: 0.28, tremHz: 24,
})));
save('z_death', render(1.1, (b, n) => growl(b, n, {
  f0: 105, f1: 44, vowels: [['u', 0], ['u', 0.72], ['a', 0.86], ['u', 1]],
  breath: 0.24, inhale: 0.13, attack: 0.07, gurgle: 0.4, creak: 0.45, trem: 0.35, tremHz: 18,
})));
save('z_groan', render(1.4, (b, n) => growl(b, n, {
  f0: 84, f1: 70, vowels: [['u', 0], ['o', 0.55], ['u', 1]],
  breath: 0.16, inhale: 0.14, attack: 0.11, gurgle: 0.22, creak: 0.28, trem: 0.18, tremHz: 16,
})));
