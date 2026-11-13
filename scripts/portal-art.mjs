#!/usr/bin/env node
// The portals' store art, made from the game itself (store/portals/, SUBMIT.md). Build first: npm run build:crazygames.
//
//   node scripts/portal-art.mjs [--covers] [--video] [--level N]
//
// Covers (docs.crazygames.com/requirements/game-covers, as COLD GAS read them on 2026-11-13): 1920×1080 (16:9),
// 800×1200 (2:3), 800×800 (1:1), with the game's title and nothing else on them (no borders, no "Play", no store
// badges). Each is a real frame of a level being played, with the interface hidden, and the game's own logo over it.
//
// Videos (same page): 15–20 s, no sound, landscape 1080p 16:9 and portrait 1080×1620 2:3, opening on the static cover,
// no cursor, no fast-forward, no black bars or promotional text. The game's clock is stepped 1/30 s per frame (rAF and
// performance.now are driven from here), so the footage is smooth at real speed however slow the capture is. The
// player is a small bot using real pointer input: taps, swipes and Snap the Hinge, with the HUD
// showing. Frames are encoded with ffmpeg (H.264, yuv420p, no audio track).
import http from 'node:http';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, statSync } from 'node:fs';
import { dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const want = { covers: args.includes('--covers') || !args.includes('--video'), video: args.includes('--video') || !args.includes('--covers') };
const LEVEL = args.includes('--level') ? Number(args[args.indexOf('--level') + 1]) : 34;
const OUT = join(ROOT, 'store/portals/crazygames'), GD = join(ROOT, 'store/portals/gamedistribution');
const GAME = join(ROOT, 'dist-portals/crazygames/game');
const TMP = join(ROOT, 'dist-portals/art-tmp');
const PORT = 4831, FPS = 30;
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.webp': 'image/webp', '.png': 'image/png', '.txt': 'text/plain' };
if (!existsSync(join(GAME, 'index.html'))) { console.error('build first: npm run build:crazygames'); process.exit(2); }
mkdirSync(OUT, { recursive: true });
mkdirSync(GD, { recursive: true });
rmSync(TMP, { recursive: true, force: true });
mkdirSync(TMP, { recursive: true });

const server = http.createServer((req, res) => {
  const path = decodeURIComponent(req.url.split('?')[0]);
  let file = resolve(GAME, path.slice(1) || 'index.html');
  if (file !== GAME && !file.startsWith(GAME + sep)) { res.writeHead(403); return res.end(); }
  if (!existsSync(file) || statSync(file).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream' });
  res.end(readFileSync(file));
}).listen(PORT, '127.0.0.1');

const browser = await chromium.launch({ args: ['--hide-scrollbars'] });

// The game on a stepped clock: rAF callbacks are queued and run only when advance() says, with performance.now()
// moved by exactly that much.
const CLOCK = `(() => {
  let t = performance.now(); const real = performance.now.bind(performance);
  const q = new Map(); let id = 0;
  window.__clock = {
    start() { t = real(); performance.now = () => t; window.requestAnimationFrame = (cb) => { q.set(++id, cb); return id; }; window.cancelAnimationFrame = (i) => q.delete(i); },
    advance(ms) { t += ms; const list = [...q.values()]; q.clear(); for (const cb of list) { try { cb(t); } catch (e) { console.error(e); } } },
  };
})()`;
const HIDE_UI = '#hud, #coach, #coach2, #panel, #tip, #spot { opacity: 0 !important; }';

async function openGame({ w, h, level }) {
  const ctx = await browser.newContext({ viewport: { width: w / 2, height: h / 2 }, deviceScaleFactor: 2 });
  await ctx.route(/crazygames\.com/, (r) => r.abort());   // no SDK here: the art is the game alone
  await ctx.addInitScript((lv) => localStorage.setItem('hinge-pop-prefs', JSON.stringify({ toured: true, touredTwo: true, level: lv, taught: { tap: 1, cross: 1, small: 1 }, soundOn: false })), level);
  const page = await ctx.newPage();
  await page.goto(`http://127.0.0.1:${PORT}/index.html`);
  await page.waitForFunction(() => window.hingePop?.mode === 'menu' && window.hingePop.usingSprites);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(600);   // the arena backdrop
  await page.evaluate(CLOCK);
  await page.evaluate(() => window.__clock.start());
  await page.click('#play');
  await page.waitForTimeout(400);   // the arena for this level loads
  return { ctx, page };
}
const step = (page) => page.evaluate((ms) => window.__clock.advance(ms), 1000 / FPS);

// The bot: one move every few frames, with real pointer input. Snap the hinge when it's crowded,
// otherwise swipe through (or tap) the bubble nearest the line.
let moves = 0;
async function act(page) {
  const s = await page.evaluate(() => {
    const h = window.hingePop, sim = h.sim;
    if (h.mode !== 'play' || sim.ready > 0) return { mode: h.mode };
    const r = document.getElementById('game').getBoundingClientRect();
    return {
      mode: h.mode, ox: r.left, oy: r.top, line: sim.line(), vertical: sim.vertical, snapReady: sim.players[0].snapLeft <= 0,
      bubbles: sim.bubbles.map((b) => ({ x: b.x + b.vx * 0.06, y: b.y + b.vy * 0.06, r: b.r, g: b.g })),
    };
  });
  if (s.mode === 'ended') { await page.click('#play').catch(() => {}); return; }
  if (s.mode !== 'play' || !s.bubbles) return;
  moves++;
  const at = (x, y) => [s.ox + x, s.oy + y];
  const gap = (b) => Math.abs((s.vertical ? b.x : b.y) - s.line);
  const near = s.bubbles.filter((b) => b.g < 3 && gap(b) < 110);
  if (s.snapReady && near.length >= 2 && moves > 12) {
    const along = near.reduce((n, b) => n + (s.vertical ? b.y : b.x), 0) / near.length;
    const [x, y] = s.vertical ? at(s.line, along) : at(along, s.line);
    await page.mouse.move(x, y); await page.mouse.down();
    await page.mouse.move(s.vertical ? x + 70 : x, s.vertical ? y : y + 70, { steps: 4 }); await page.mouse.up();
    return;
  }
  const pool = s.bubbles.filter((b) => b.g < 3);
  const b = (pool.length ? pool : s.bubbles).sort((p, q) => gap(p) - gap(q))[0];
  if (!b) return;
  const [x, y] = at(b.x, b.y);
  if (moves % 3 === 0) { await page.mouse.click(x, y); return; }
  const k = b.r * 1.7, tilt = moves % 2 ? 0.5 : -0.5;
  await page.mouse.move(x - k, y - k * tilt); await page.mouse.down();
  await page.mouse.move(x + k, y + k * tilt, { steps: 5 }); await page.mouse.up();
}

// A frame of real play with the interface hidden: the bot plays `seconds` in, then the shot.
async function rawFrame({ w, h, name, seconds = 2.6 }) {
  const { ctx, page } = await openGame({ w, h, level: LEVEL });
  await page.addStyleTag({ content: HIDE_UI });
  moves = 0;
  for (let i = 0; i < seconds * FPS; i++) { if (i % 7 === 0) await act(page); await step(page); }
  const file = join(TMP, `raw-${name}.png`);
  await page.screenshot({ path: file });
  await ctx.close();
  return file;
}

// The logo over a frame, at an exact size. Only the title (the portals' rule).
const LOGO = execFileSync('sips', ['-s', 'format', 'png', join(ROOT, 'site/art/logo.webp'), '--out', join(TMP, 'logo.png')]) && readFileSync(join(TMP, 'logo.png')).toString('base64');
async function composite({ raw, w, h, out }) {
  const img = readFileSync(raw).toString('base64');
  const portrait = h > w, square = h === w;
  const logoW = portrait ? w * 0.7 : square ? w * 0.5 : Math.min(w * 0.36, h * 0.62 * (1000 / 860));
  const html = `<!doctype html><html><head><style>
    html, body { margin: 0; width: ${w}px; height: ${h}px; overflow: hidden; background: #140a2e; }
    .bg { position: absolute; inset: 0; background: url(data:image/png;base64,${img}) center / cover no-repeat; }
    .scrim { position: absolute; inset: 0; background: radial-gradient(${portrait ? '80% 30% at 50% 23%' : square ? '60% 35% at 50% 75%' : '35% 60% at 24% 50%'}, rgba(20,10,46,.55), rgba(20,10,46,0) 70%); }
    img { position: absolute; left: ${portrait || square ? 50 : 24}%; top: ${portrait ? 23 : square ? 75 : 50}%; width: ${Math.round(logoW)}px; transform: translate(-50%, -50%); filter: drop-shadow(0 ${Math.round(logoW * 0.02)}px ${Math.round(logoW * 0.05)}px rgba(0,0,0,.45)); }
  </style></head><body><div class="bg"></div><div class="scrim"></div><img src="data:image/png;base64,${LOGO}"></body></html>`;
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
  await page.setContent(html);
  await page.evaluate(() => Promise.all([...document.images].map((i) => i.decode())));
  await page.screenshot({ path: out });
  await page.close();
  return out;
}

const raws = {};
raws.landscape = await rawFrame({ w: 1920, h: 1080, name: 'landscape' });
raws.portrait = await rawFrame({ w: 1080, h: 1620, name: 'portrait' });
if (want.covers) {
  raws.square = await rawFrame({ w: 800, h: 800, name: 'square', seconds: 1.4 });
  await composite({ raw: raws.landscape, w: 1920, h: 1080, out: join(OUT, 'cover-landscape-1920x1080.png') });
  await composite({ raw: raws.portrait, w: 800, h: 1200, out: join(OUT, 'cover-portrait-800x1200.png') });
  await composite({ raw: raws.square, w: 800, h: 800, out: join(OUT, 'cover-square-800x800.png') });
  console.log('covers →', OUT);
  // GameDistribution's dashboard asks for its own images when the game is created; these are the sizes its asset
  // template lists (not in its public docs: check them against the upload form). The same frames, the same rule.
  for (const [w, h] of [[1280, 720], [1280, 550], [512, 384], [512, 340]]) await composite({ raw: raws.landscape, w, h, out: join(GD, `image-${w}x${h}.png`) });
  await composite({ raw: raws.square, w: 512, h: 512, out: join(GD, 'image-512x512.png') });
  console.log('GameDistribution images →', GD);
}

async function video({ w, h, name, cover }) {
  const dir = join(TMP, `frames-${name}`);
  mkdirSync(dir, { recursive: true });
  let n = 0;
  const shot = (page) => page.screenshot({ path: join(dir, `f${String(n++).padStart(4, '0')}.png`) });
  // 1 s on the static cover (the docs: the first frame is the cover).
  const coverPng = await composite({ raw: cover, w, h, out: join(dir, 'cover.png') });
  for (let i = 0; i < FPS; i++) execFileSync('cp', [coverPng, join(dir, `f${String(n++).padStart(4, '0')}.png`)]);
  const { ctx, page } = await openGame({ w, h, level: LEVEL });
  moves = 0;
  for (let i = 0; n < 18 * FPS; i++) {
    if (i % 7 === 0) await act(page);
    await shot(page);
    await step(page);
  }
  await ctx.close();
  const out = join(OUT, `video-${name}.mp4`);
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', String(FPS), '-i', join(dir, 'f%04d.png'), '-vf', `scale=${w}:${h}:flags=lanczos`,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p', '-an', '-movflags', '+faststart', out]);
  console.log(`video ${name}: ${(n / FPS).toFixed(1)} s, ${(statSync(out).size / 1e6).toFixed(1)} MB → ${out}`);
}
if (want.video) {
  await video({ w: 1920, h: 1080, name: 'landscape-1920x1080', cover: raws.landscape });
  await video({ w: 1080, h: 1620, name: 'portrait-1080x1620', cover: raws.portrait });
}

await browser.close();
server.close();
