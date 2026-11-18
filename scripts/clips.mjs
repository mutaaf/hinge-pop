#!/usr/bin/env node
// npm run clips: short-form vertical clips (TikTok, Shorts, Reels) of the Hinge Pop web game.
//
//   npm run clips                         capture every take, cut every clip in store/clips/clips.json
//   npm run clips -- --skip-capture       re-cut from the takes already in dist-clips/raw/ (caption or edit changes)
//   npm run clips -- --only=hp-chain      one clip (no contact sheet)
//   npm run clips -- --takes=snap         capture only these takes
//
// The page is the portal build's game: index.html through editGame() (scripts/portal-html.mjs), the same exact text
// edits and cuts, so no guest star (the film and character winks) is in it, and nothing reaches analytics. It is
// served from dist-clips/site/ with art/ and fonts/ beside it, and the run fails if any guest name or cameo art
// reaches the page. A small stand-in for the portal runtime (__hpPortal) keeps saves in localStorage.
//
// Each take is a scripted player: a bot in the page reads the sim each frame and plays with real pointer events on
// the canvas (taps, swipes, a drag off the hinge), so the game draws its own trails, splits, chain pops and snap
// flares. A soft finger dot shows where the touch is. Levels are the game's own fixed layouts (createSim places a
// level's bubbles the same way every time), and the bot's choices follow the sim, so a take replays the same way.
// Marks are stamped in the page the frame they happen. scripts/clips-lib.mjs does the cutting.
import http from 'node:http';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { FORBIDDEN, editGame } from './portal-html.mjs';
import { FONTS, artFiles } from './portal-build.mjs';
import { main } from './clips-lib.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SITE = join(ROOT, 'dist-clips', 'site');
const PORT = Number(process.env.CLIPS_PORT) || 4796;
const URL = `http://127.0.0.1:${PORT}/index.html`;

// The portal runtime's surface, minus the portal: saves in localStorage, never muted, no ads, no events.
const PORTAL_STUB = `window.__hpPortal = { getItem: (k) => localStorage.getItem(k), setItem: (k, v) => localStorage.setItem(k, v),
  muted: () => false, ran() {}, leave(f) { f(); }, sync() {}, attach() {}, ready() {} };`;

function buildSite() {
  const edited = editGame(readFileSync(join(ROOT, 'index.html'), 'utf8'));
  const split = edited.indexOf('<div id="stage">');
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
${edited.slice(0, split).trim()}
</head>
<body>
<script>${PORTAL_STUB}</script>
${edited.slice(split).trim()}
</body>
</html>
`;
  rmSync(SITE, { recursive: true, force: true });
  mkdirSync(join(SITE, 'art'), { recursive: true });
  mkdirSync(join(SITE, 'fonts'), { recursive: true });
  writeFileSync(join(SITE, 'index.html'), html);
  for (const f of artFiles(edited)) cpSync(join(ROOT, 'site/art', f), join(SITE, 'art', f));
  for (const f of FONTS) cpSync(join(ROOT, 'site/fonts', f), join(SITE, 'fonts', f));
  // No guest star may reach the page: the same check the portal build makes, on what the clips will show.
  const guest = FORBIDDEN.find(([, what]) => what === 'a guest star')[0];
  const m = html.match(guest);
  if (m) throw new Error(`clip page: a guest star is still in it (${m[0]})`);
  if (readdirSync(join(SITE, 'art')).some((f) => /^cameo-/.test(f))) throw new Error('clip page: cameo art copied');
  if (/boxoffice|mutaafaziz\.com\/boxoffice/i.test(html)) throw new Error('clip page: analytics loader present');
  console.log(`clip page: ${readdirSync(join(SITE, 'art')).length} art files, no guests`);
}

const TYPES = { '.html': 'text/html', '.webp': 'image/webp', '.woff2': 'font/woff2', '.txt': 'text/plain' };
function serve() {
  return http.createServer((req, res) => {
    const path = decodeURIComponent(req.url.split('?')[0]);
    const file = resolve(SITE, '.' + (path === '/' ? '/index.html' : path));
    if (!file.startsWith(SITE + sep) || !existsSync(file) || statSync(file).isDirectory()) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(readFileSync(file));
  }).listen(PORT, '127.0.0.1');
}

// ---- The player, in the page. ----
// Pointer events go to the canvas exactly as a finger's would. The finger dot is a DOM overlay above the canvas.
function installBot() {
  const canvas = document.getElementById('game');
  const dot = document.createElement('div');
  dot.style.cssText = 'position:fixed;z-index:50;width:86px;height:86px;margin:-43px 0 0 -43px;border-radius:50%;pointer-events:none;'
    + 'background:radial-gradient(circle,rgba(255,255,255,.75) 0 28%,rgba(255,255,255,.28) 30% 56%,rgba(255,255,255,0) 58%);'
    + 'box-shadow:0 0 0 4px rgba(255,255,255,.55);opacity:0;transition:opacity .12s,transform .12s;transform:scale(.8)';
  document.body.appendChild(dot);
  const marks = (window.__marks = {});
  const mark = (k) => { if (!(k in marks)) marks[k] = Date.now(); };
  let id = 10;
  const fire = (type, x, y, pid) => {
    const r = canvas.getBoundingClientRect();
    canvas.dispatchEvent(new PointerEvent(type, { bubbles: true, cancelable: true, pointerId: pid, pointerType: 'touch', isPrimary: true, clientX: r.left + x, clientY: r.top + y }));
  };
  const show = (x, y, on) => { const r = canvas.getBoundingClientRect(); dot.style.left = r.left + x + 'px'; dot.style.top = r.top + y + 'px'; dot.style.opacity = on ? '1' : '0'; dot.style.transform = on ? 'scale(1)' : 'scale(.8)'; };
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const frame = () => new Promise((r) => requestAnimationFrame(r));
  async function tap(x, y) {
    const pid = ++id;
    show(x, y, true); fire('pointerdown', x, y, pid); await wait(70); fire('pointerup', x, y, pid); await wait(60); show(x, y, false);
  }
  // A stroke from (x0,y0) to (x1,y1) over ms, one move a frame, like a finger.
  async function swipe(x0, y0, x1, y1, ms = 160) {
    const pid = ++id, t0 = performance.now();
    show(x0, y0, true); fire('pointerdown', x0, y0, pid);
    for (;;) {
      await frame();
      const k = Math.min(1, (performance.now() - t0) / ms), e = 1 - (1 - k) * (1 - k);
      const x = x0 + (x1 - x0) * e, y = y0 + (y1 - y0) * e;
      show(x, y, true); fire('pointermove', x, y, pid);
      if (k >= 1) break;
    }
    fire('pointerup', x1, y1, pid); await wait(40); show(x1, y1, false);
  }
  const hp = () => window.hingePop;
  const sim = () => hp().sim;
  window.__bot = { tap, swipe, wait, frame, mark, sim, hp, show };
}

// Waits for play to be live (past the READY beat).
const live = (page) => page.waitForFunction(() => window.hingePop?.mode === 'play' && window.hingePop.sim.ready <= 0, null, { timeout: 20000 });

// Stamps level-wide events (splits, chain pops, snaps, a won level) from the sim's own event list, the frame they
// happen. Runs beside whatever the take's player does.
function watchEvents() {
  const { mark } = window.__bot;
  let chained = 0, snaps = 0, n = 0;
  const tick = () => {
    const s = window.hingePop.sim, p = s.players[0], q = s.players[1] || p;
    if (p.combo >= 5) mark('combo5');
    if (p.combo >= 10) mark('combo10');
    // A chain: four or more tiny bubbles gone in one frame from one touch.
    const c = p.chained + (s.players[1] ? s.players[1].chained : 0);
    if (c - chained >= 3) { n++; mark('chain' + n); mark('chain'); window.__chains = (window.__chains || []).concat(c - chained); }
    chained = c;
    const k = p.snaps + (s.players[1] ? q.snaps : 0);
    if (k > snaps) { snaps = k; mark('snap' + k); }
    if (s.status !== 'playing') mark(s.status);
    requestAnimationFrame(tick);
  };
  tick();
}

// Solo: clear a level the way a good player does. Big and medium bubbles get swiped (one stroke through as many as
// line up), the closest threat to the hinge first; small ones are tapped; tiny ones are left to gather, then one tap
// sets them off together (a chain pop) unless one is about to reach the line.
async function soloPlayer({ chainAt = 6, pace = 230, snap = false, snapMin = 2, snapGap = 170, hold = 0 } = {}) {
  {
    const { tap, swipe, wait, mark, sim, frame } = window.__bot;
    const W = innerWidth;
    for (let guard = 0; guard < 400; guard++) {
      const s = sim();
      if (s.status !== 'playing') break;
      const line = s.line();
      const ready = s.bubbles.filter((b) => b.grace <= 0);
      const gap = (b) => Math.abs(b.y - line) - b.r;
      const tiny = ready.filter((b) => b.g === 3);
      const big = ready.filter((b) => b.g < 3).sort((a, b) => gap(a) - gap(b));
      // Snap the hinge when several bubbles are bearing down on it: a drag off the line, from a spot on it no bubble
      // covers, flings every one near the line back. `hold` lets the first ones come in close before the bot plays.
      const near = s.bubbles.filter((b) => b.g < 3 && gap(b) < snapGap);
      if (snap && s.players[0].snapLeft <= 0 && near.length >= snapMin) {
        const cx = near.reduce((a, b) => a + b.x, 0) / near.length;
        let x = null;
        for (let d = 0; d < W; d += 20) for (const c of [cx + d, cx - d]) if (x === null && c > 80 && c < W - 80 && !s.hit(c, line)) x = c;
        if (x !== null) { mark('snapGo'); await swipe(x, line, x + 40, line - 190, 130); await wait(pace); continue; }
      }
      if (hold && s.t < hold && s.players[0].snaps === 0) { await frame(); continue; }
      if (tiny.length >= chainAt || (tiny.length && !big.length) || tiny.some((b) => gap(b) < 40 && big.length === 0)) {
        // The tiny one with the most neighbours sets off the biggest chain.
        const near = (b) => tiny.filter((o) => Math.hypot(o.x - b.x, o.y - b.y) < 300).length;
        const t = tiny.sort((a, b) => near(b) - near(a))[0];
        if (tiny.length >= chainAt) mark('chainTap');
        await tap(t.x, t.y);
      } else if (big.length) {
        const b = big[0];
        if (b.g <= 1) {
          // A stroke across the bubble, aimed away from the hinge so the pieces fly back.
          const away = b.y < line ? -1 : 1, len = Math.max(180, b.r * 2.4);
          const dx = (b.x < W / 2 ? 1 : -1) * len * 0.6;
          mark('swipe');
          await swipe(b.x - dx / 2, b.y - away * len * 0.35, b.x + dx / 2, b.y + away * len * 0.65, 150);
        } else {
          await tap(b.x, b.y);
        }
      }
      await wait(pace + (guard % 3) * 50);
    }
  }
}

// One take: a level (or two players) from the menu, played by `player` (a page function and its options).
function take(name, level, player, opts = {}, { tail = 1400, versus = false } = {}) {
  const prefs = { toured: true, touredTwo: true, flick: true, grace: true, soundOn: false, level,
    taught: { combo: 1, cross: 1, nearfull: 1, recharge: 1, shield: 1, small: 1, snapped: 1, tap: 1 } };
  return {
    name,
    context: { deviceScaleFactor: 1, hasTouch: true },
    init: `try { localStorage.setItem('hinge-pop-prefs', ${JSON.stringify(JSON.stringify(prefs))}); } catch (e) {}`,
    drive: async (page, mark) => {
      await page.goto(URL);
      await page.waitForFunction(() => window.hingePop && window.hingePop.usingSprites && document.fonts.status === 'loaded', null, { timeout: 20000 });
      await page.waitForTimeout(500);
      await page.evaluate(installBot);
      mark('menu');
      await page.click(versus ? '#two' : '#play');
      await live(page);
      mark('live');
      await page.evaluate(watchEvents);
      await page.evaluate(player, opts);
      mark('played');
      await page.waitForTimeout(tail);
      mark('end');
      console.log(`    ${name}: chains ${JSON.stringify(await page.evaluate(() => window.__chains || []))}`);
      for (const [k, at] of Object.entries(await page.evaluate(() => window.__marks))) mark(k, at);
    },
  };
}

const TAKES = [
  take('chain', 8, soloPlayer, { chainAt: 12 }),
  take('snap', 14, soloPlayer, { snap: true, hold: 9, snapGap: 70, chainAt: 6 }),
  take('swipe', 35, soloPlayer, { chainAt: 6, pace: 200 }),
  take('versus', 1, soloPlayer, { chainAt: 5, pace: 260 }, { versus: true, tail: 2600 }),
  take('frost', 55, soloPlayer, { chainAt: 6, snap: true }),
  take('magma', 75, soloPlayer, { chainAt: 6, snap: true }),
];

let server;
await main({
  chromium,
  root: ROOT,
  title: 'Hinge Pop: short-form clips',
  takes: TAKES,
  before: async () => { if (!process.argv.includes('--skip-capture')) { buildSite(); server = serve(); } return {}; },
  after: async () => { server?.close(); },
});
