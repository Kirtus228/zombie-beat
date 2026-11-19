import fs from 'node:fs';
import path from 'node:path';
const dir = 'games/zombie-beat/build/sfx';
const names = ['swing', 'hit', 'player_hurt', 'z_attack', 'z_hurt', 'z_death', 'z_groan'];
const SR = 44100;
const gap = Buffer.alloc(SR * 2 * 0.4); // 0.4 с тишины
const parts = [];
for (const n of names) {
  const b = fs.readFileSync(path.join(dir, n + '.wav'));
  parts.push(b.subarray(44));
  parts.push(gap);
}
const data = Buffer.concat(parts);
const hdr = Buffer.alloc(44);
hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + data.length, 4); hdr.write('WAVE', 8);
hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20); hdr.writeUInt16LE(1, 22);
hdr.writeUInt32LE(SR, 24); hdr.writeUInt32LE(SR * 2, 28); hdr.writeUInt16LE(2, 32); hdr.writeUInt16LE(16, 34);
hdr.write('data', 36); hdr.writeUInt32LE(data.length, 40);
fs.writeFileSync(path.join(dir, 'all.wav'), Buffer.concat([hdr, data]));
console.log('all.wav', (data.length / 2 / SR).toFixed(2) + 's');
