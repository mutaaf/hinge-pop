// Copies the sprites the site uses from the iOS export (ios/build/sprites, read only) into site/art as WebP.
// The results are committed, so a normal build needs neither ios/ nor cwebp. Run it after the art changes:
//   npm run art
import { execFileSync } from 'node:child_process';
import { mkdirSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const from = 'ios/build/sprites', to = 'site/art';
mkdirSync(to, { recursive: true });
const webp = (name, width, q, out = name) => {
  const args = ['-quiet', '-q', String(q), '-alpha_q', '85', '-m', '6', '-mt', '-sharp_yuv'];
  if (width) args.push('-resize', String(width), '0');
  execFileSync('cwebp', [...args, join(from, name + '.png'), '-o', join(to, out + '.webp')]);
};

for (const b of ['basic', 'fast', 'armored', 'magnetic', 'repel', 'golden', 'frozen', 'boss']) webp('bubble-' + b, 384, 80);
webp('bubble-basic', 192, 82, 'game-bubble');
for (const p of ['overcharge', 'freeze', 'focus', 'shield', 'chainBurst']) webp('power-' + p, 240, 82);
for (const a of ['classic', 'neon', 'forest', 'space']) {
  webp(`arena-${a}-tall`, 0, 58);
  webp(`arena-${a}-wide`, 0, 58);
}
webp('logo', 1000, 82);
webp('fx-particleStar', 64, 80, 'star');
webp('fx-popBurst', 240, 74, 'burst');

let total = 0;
for (const f of readdirSync(to)) {
  const n = statSync(join(to, f)).size;
  total += n;
  console.log(String(Math.round(n / 1024)).padStart(5), 'KB', f);
}
console.log(String(Math.round(total / 1024)).padStart(5), 'KB total');
