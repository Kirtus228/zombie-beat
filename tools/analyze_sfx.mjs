// Спектральный разбор WAV: медианная F0 (автокорреляция), спектральный центроид,
// пики формантов по огибающей спектра. Только читает и печатает.
//   node tools/analyze_sfx.mjs <dir> [--only=z_] [--json]
import fs from 'node:fs';
import path from 'node:path';

const SR = 44100;
const W = 2048, HOP = 512;

function readWav(file) {
  const b = fs.readFileSync(file);
  let off = 12, dataOff = -1, dataLen = 0;
  while (off + 8 <= b.length) {
    const id = b.toString('ascii', off, off + 4);
    const sz = b.readUInt32LE(off + 4);
    if (id === 'data') { dataOff = off + 8; dataLen = Math.min(sz, b.length - off - 8); break; }
    off += 8 + sz + (sz % 2);
  }
  const n = Math.floor(dataLen / 2);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = b.readInt16LE(dataOff + i * 2) / 32768;
  return out;
}

function makeFft(N) {
  const cos = new Float64Array(N / 2), sin = new Float64Array(N / 2);
  for (let i = 0; i < N / 2; i++) { const a = -2 * Math.PI * i / N; cos[i] = Math.cos(a); sin[i] = Math.sin(a); }
  const rev = new Uint32Array(N);
  let bits = 0; while ((1 << bits) < N) bits++;
  for (let i = 0; i < N; i++) { let r = 0; for (let b = 0; b < bits; b++) r |= ((i >> b) & 1) << (bits - 1 - b); rev[i] = r; }
  return { N, cos, sin, rev };
}

function fftMag(fft, re, im, mag) {
  const { N, cos, sin, rev } = fft;
  const tr = new Float64Array(N), ti = new Float64Array(N);
  for (let i = 0; i < N; i++) { tr[i] = re[rev[i]]; ti[i] = im[rev[i]]; }
  for (let size = 2; size <= N; size <<= 1) {
    const half = size >> 1, step = N / size;
    for (let i = 0; i < N; i += size) {
      for (let j = 0; j < half; j++) {
        const k = j * step, cr = cos[k], ci = sin[k];
        const ar = tr[i + j + half], ai = ti[i + j + half];
        const xr = ar * cr - ai * ci, xi = ar * ci + ai * cr;
        tr[i + j + half] = tr[i + j] - xr; ti[i + j + half] = ti[i + j] - xi;
        tr[i + j] += xr; ti[i + j] += xi;
      }
    }
  }
  for (let i = 0; i < N / 2; i++) mag[i] = Math.hypot(tr[i], ti[i]);
}

const db = (v) => 20 * Math.log10(v + 1e-12);

// локальные максимумы: частота + подъём над ближайшими минимумами (dB)
function peaksIn(spec, lo, hi, minProm) {
  const B = spec.length, out = [];
  for (let i = 2; i < B - 2; i++) {
    const f = i * SR / W;
    if (f < lo || f > hi) continue;
    if (!(spec[i] > spec[i - 1] && spec[i] >= spec[i + 1])) continue;
    let l = i, r = i;
    while (l > 0 && spec[l - 1] <= spec[l]) l--;
    while (r < B - 1 && spec[r + 1] <= spec[r]) r++;
    const prom = db(spec[i]) - Math.max(db(spec[l]), db(spec[r]));
    if (prom >= minProm) out.push({ f: Math.round(f), prom: Math.round(prom * 10) / 10 });
  }
  return out;
}

function analyze(buf) {
  const fft = makeFft(W);
  const re = new Float64Array(W), im = new Float64Array(W), mag = new Float64Array(W / 2);
  const win = new Float64Array(W);
  for (let i = 0; i < W; i++) win[i] = 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (W - 1));

  let maxRms = 0;
  for (let s = 0; s + W <= buf.length; s += HOP) {
    let e = 0;
    for (let i = 0; i < W; i++) { const v = buf[s + i]; e += v * v; }
    maxRms = Math.max(maxRms, Math.sqrt(e / W));
  }

  const f0s = [], centroids = [], frames = [], framesT = [];
  for (let s = 0; s + W <= buf.length; s += HOP) {
    let e = 0;
    for (let i = 0; i < W; i++) { const v = buf[s + i]; e += v * v; re[i] = v * win[i]; im[i] = 0; }
    if (Math.sqrt(e / W) < 0.12 * maxRms) continue;

    // F0: нормированная автокорреляция, 50..400 Гц, первая вершина, близкая к максимуму
    const minLag = Math.floor(SR / 400), maxLag = Math.ceil(SR / 50);
    const r = new Float64Array(maxLag + 2);
    let bestLag = 0, bestR = 0;
    for (let lag = minLag; lag <= maxLag; lag++) {
      let num = 0, d1 = 0, d2 = 0;
      for (let i = 0; i + lag < W; i++) {
        const a = buf[s + i], b = buf[s + i + lag];
        num += a * b; d1 += a * a; d2 += b * b;
      }
      const rr = (d1 > 0 && d2 > 0) ? num / Math.sqrt(d1 * d2) : 0;
      r[lag] = rr;
      if (rr > bestR) { bestR = rr; bestLag = lag; }
    }
    if (bestR > 0.3) {
      let lag = minLag + 1;
      while (lag <= bestLag && !(r[lag] > 0.9 * bestR && r[lag] > r[lag - 1] && r[lag] >= r[lag + 1])) lag++;
      if (lag > maxLag) lag = bestLag;
      f0s.push(SR / lag);
    }

    fftMag(fft, re, im, mag);
    const tt = s / SR / (buf.length / SR);
    frames.push(Array.from(mag));
    framesT.push(tt);
    let num = 0, den = 0;
    for (let i = 1; i < W / 2; i++) {
      const f = i * SR / W;
      if (f < 60 || f > 8000) continue;
      num += f * mag[i]; den += mag[i];
    }
    if (den > 0) centroids.push(num / den);
  }

  const med = (a) => { if (!a.length) return 0; const s = a.slice().sort((x, y) => x - y); return s[s.length >> 1]; };
  const B = W / 2;
  const medianSpec = (sel) => {
    const spec = new Float64Array(B);
    for (let i = 0; i < B; i++) {
      const col = sel.map(f => f[i]).sort((a, b) => a - b);
      spec[i] = col.length ? col[col.length >> 1] : 0;
    }
    return spec;
  };
  const spec = medianSpec(frames);
  const smooth = (src, K) => {
    const env = new Float64Array(B);
    for (let i = 0; i < B; i++) {
      let a = 0, c = 0;
      for (let j = -K; j <= K; j++) { const k2 = i + j; if (k2 >= 0 && k2 < B) { a += src[k2]; c++; } }
      env[i] = a / c;
    }
    return env;
  };
  const envAll = smooth(spec, 4);

  const harm = peaksIn(spec, 200, 2000, 6).slice(0, 6);
  const formants = peaksIn(envAll, 300, 2200, 2.5);
  const band = formants.filter(p => p.f >= 400 && p.f <= 1200);

  let peak = 0;
  for (let i = 0; i < buf.length; i++) peak = Math.max(peak, Math.abs(buf[i]));

  return {
    peak: Math.round(peak * 1000) / 1000,
    f0: Math.round(med(f0s)),
    centroid: Math.round(med(centroids)),
    formants: formants.sort((a, b) => b.prom - a.prom).slice(0, 4).sort((a, b) => a.f - b.f),
    band: band.length,
    harmonics: harm.length,
    peakCount: formants.length,
  };
}

const dir = process.argv[2] || 'games/zombie-beat/build/sfx';
const onlyArg = process.argv.find(a => a.startsWith('--only='));
const only = onlyArg ? onlyArg.slice(7) : '';
const files = fs.readdirSync(dir).filter(f => f.endsWith('.wav') && f.startsWith(only)).sort();
const rows = files.map(f => ({ name: f.replace('.wav', ''), ...analyze(readWav(path.join(dir, f))) }));
if (process.argv.includes('--json')) console.log(JSON.stringify(rows, null, 1));
else for (const r of rows) {
  const pk = r.formants.map(p => p.f + 'Hz(+' + p.prom + 'dB)').join(' ');
  console.log(r.name.padEnd(11), 'F0=' + String(r.f0).padStart(3), 'Hz | центроид=' + String(r.centroid).padStart(4),
    'Hz | пик=' + r.peak.toFixed(2), '| формантов в 400–1200: ' + r.band, '| всего формантов: ' + (pk || 'нет'));
}