// Copies the sprites the site uses from the iOS export (ios/build/sprites, read only) into site/art as WebP.
// The results are committed, so a normal build needs neither ios/ nor cwebp. Run it after the art changes:
//   (cd ios/Packages/HingePopArt && swift run render-assets ../../build/sprites --sprites) && npm run art
// Art only: `npm run art -- --arenas` exports just the backdrops (all 16 biomes x 4 variants).
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

const arenasOnly = process.argv.includes('--arenas');
if (!arenasOnly) for (const b of ['basic', 'fast', 'armored', 'magnetic', 'repel', 'golden', 'frozen', 'boss']) webp('bubble-' + b, 384, 80);
if (!arenasOnly) webp('bubble-basic', 192, 82, 'game-bubble');
if (!arenasOnly) for (const p of ['overcharge', 'freeze', 'focus', 'shield', 'chainBurst']) webp('power-' + p, 240, 82);
// Every biome, and its variants 1-3 as arena-<biome>-v<n>-tall/wide (variant 0 keeps the plain name).
const ARENAS = ['classic', 'neon', 'forest', 'space', 'frost', 'reef', 'magma',
  'candy', 'dunes', 'storm', 'crystal', 'haunted', 'circuit', 'jungle', 'clouds', 'clockwork'];
for (const a of ARENAS) {
  for (const v of ['', '-v1', '-v2', '-v3']) {
    webp(`arena-${a}${v}-tall`, 0, 58);
    webp(`arena-${a}${v}-wide`, 0, 58);
  }
}
if (!arenasOnly) for (const c of ['captainFizz', 'docFlux', 'sirGlowstick', 'chosenFizz', 'merlinFizz', 'bigBurp', 'booBubble', 'discoDot']) webp('cameo-' + c, 200, 82);
if (!arenasOnly) {
  webp('logo', 1000, 82);
  webp('fx-particleStar', 64, 80, 'star');
  webp('fx-popBurst', 240, 74, 'burst');
}

let total = 0;
for (const f of readdirSync(to)) {
  const n = statSync(join(to, f)).size;
  total += n;
  console.log(String(Math.round(n / 1024)).padStart(5), 'KB', f);
}
console.log(String(Math.round(total / 1024)).padStart(5), 'KB total');
