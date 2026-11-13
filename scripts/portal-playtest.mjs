#!/usr/bin/env node
// Plays a portal build the way a portal hosts it: the game's files on one origin, under a deep folder (relative paths
// only), inside a sandboxed <iframe> on a page from another origin. Build first (npm run build:<portal>).
//
//   node scripts/portal-playtest.mjs <crazygames|gamedistribution> [--blocked] [--phone] [--headed]
//
// --blocked  the portal's SDK host is refused (an ad blocker): the game must play exactly the same, with no ads
// --phone    390×844 touch, every input a real tap
//
// A fresh player: Play opens the tour, Skip tour starts level 1, which is cleared by real taps and swipes on the
// bubbles. Its result is left with the next level (the first game of a session never gets an ad), level 2 is cleared
// the same way, and its result is left with Menu, where the midgame ad is asked for. Then a quick two-player match is
// started and paused, and Menu. It fails on: any console or page error in the game's frame, any 404 from the game's
// folder, any request to mutaafaziz.com or for analytics, an ad before the second game's result, no gameplayStart in
// play or no gameplayStop at the result (CrazyGames, SDK up), saves that don't reach the portal's data module
// (CrazyGames, SDK up) or localStorage, or a menu that never comes back.
import http from 'node:http';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, devices } from 'playwright';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const [portal = 'crazygames', ...flags] = process.argv.slice(2);
const blocked = flags.includes('--blocked'), phone = flags.includes('--phone'), headed = flags.includes('--headed');
const GAME_DIR = join(ROOT, 'dist-portals', portal, 'game');
const GAME_PORT = Number(process.env.PT_PORT) || 4821, HOST_PORT = GAME_PORT + 1;
const DEEP = '/games/embed/hinge-pop-1/';   // a portal serves from a folder of its own: nothing may assume the root
const SDK_HOSTS = { crazygames: /(^|\.)crazygames\.com$/, gamedistribution: /(^|\.)gamedistribution\.com$/ };
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.txt': 'text/plain',
  '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.webp': 'image/webp', '.png': 'image/png' };

if (!existsSync(join(GAME_DIR, 'index.html'))) { console.error(`no build at ${GAME_DIR}: npm run build:${portal}`); process.exit(2); }

const missing = [];
function serveGame() {
  return http.createServer((req, res) => {
    const path = decodeURIComponent(req.url.split('?')[0]);
    if (!path.startsWith(DEEP)) { missing.push(path); res.writeHead(404); return res.end(); }
    let file = resolve(GAME_DIR, path.slice(DEEP.length) || 'index.html');
    if (file !== GAME_DIR && !file.startsWith(GAME_DIR + sep)) { res.writeHead(403); return res.end(); }
    if (existsSync(file) && statSync(file).isDirectory()) file = join(file, 'index.html');
    if (!existsSync(file)) { missing.push(path); res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(readFileSync(file));
  }).listen(GAME_PORT, '127.0.0.1');
}
// The portal's page: another origin (localhost, not 127.0.0.1), the game in a sandboxed frame as the portals embed it.
function serveHost() {
  return http.createServer((req, res) => {
    res.writeHead(200, { 'content-type': 'text/html' });
    res.end(`<!doctype html><html><body style="margin:0;background:#111">
<iframe id="game" src="http://127.0.0.1:${GAME_PORT}${DEEP}index.html" style="border:0;width:100vw;height:100vh;display:block"
  sandbox="allow-scripts allow-same-origin allow-pointer-lock allow-popups allow-forms" allow="autoplay; fullscreen; gamepad"></iframe>
</body></html>`);
  }).listen(HOST_PORT, 'localhost');
}

const fail = [];
const check = (ok, what) => { console.log(`${ok ? '  ok  ' : '  FAIL'} ${what}`); if (!ok) fail.push(what); };

const servers = [serveGame(), serveHost()];
const browser = await chromium.launch({ headless: !headed });
const ctx = await browser.newContext(phone ? { ...devices['iPhone 13'], viewport: { width: 390, height: 844 } } : { viewport: { width: 1280, height: 720 } });
const page = await ctx.newPage();
const errors = [], forbidden = [], sdkRequests = [], sdkLogs = [], thirdParty = [];
page.on('pageerror', (e) => (String(e.stack || '').includes(`127.0.0.1:${GAME_PORT}`) || !/https?:\/\//.test(String(e.stack || '')) ? errors : thirdParty).push(`pageerror: ${e.message}`));
page.on('console', (m) => {
  // CrazyGames' SDK logs every call in its local mode ("Requesting gameplay start", …): the proof it was called.
  if (/HTML5 SDK/.test(m.text())) sdkLogs.push(m.text().replace(/%c|background-color[^;]*;|border-radius[^;]*;|padding[^;]*;|color:[^;]*;/g, ' '));
  if (m.type() !== 'error') return;
  const where = m.location()?.url || '';
  if (where && !where.startsWith(`http://127.0.0.1:${GAME_PORT}`)) return;   // an ad network's own noise is not the game's
  if (blocked && /ERR_BLOCKED_BY_CLIENT|net::ERR_FAILED/.test(m.text())) return;   // the refused SDK itself
  errors.push(`console: ${m.text()} @ ${where}`);
});
page.on('request', (r) => {
  const u = new URL(r.url());
  if (/mutaafaziz|boxoffice|posthog/i.test(r.url()) || /\/ads\/v1/.test(u.pathname)) forbidden.push(r.url());
  if (SDK_HOSTS[portal].test(u.hostname)) sdkRequests.push(r.url());
});
if (blocked) await ctx.route((url) => SDK_HOSTS[portal].test(new URL(url).hostname), (route) => route.abort('blockedbyclient'));

console.log(`portal playtest: ${portal}${blocked ? ', SDK blocked' : ''}${phone ? ', phone' : ''}`);
await page.goto(`http://localhost:${HOST_PORT}/`);
const frame = await (await page.waitForSelector('#game')).contentFrame();
await frame.waitForFunction(() => !!window.hingePop && !!window.__hpPortal, null, { timeout: 30_000 });
const live = await frame.evaluate(() => window.__hpPortal.live);
check(blocked ? !live : true, `SDK ${live ? 'up' : 'not up'}${blocked ? ' (blocked, as asked)' : ''}`);
if (!blocked && portal === 'crazygames') check(live, 'CrazyGames SDK initialised (local mode)');

// Spy on the SDK's ad calls from here on (the runtime calls through window.CrazyGames.SDK / window.gdsdk each time).
await frame.evaluate(() => {
  window.__calls = [];
  const sdk = window.CrazyGames?.SDK;
  if (sdk?.ad?.requestAd) { const f = sdk.ad.requestAd.bind(sdk.ad); sdk.ad.requestAd = (t, cb) => { window.__calls.push(`ad:${t}`); return f(t, cb); }; }
  if (window.gdsdk?.showAd) { const f = window.gdsdk.showAd.bind(window.gdsdk); window.gdsdk.showAd = (...a) => { window.__calls.push(`ad:${a[0] || 'midgame'}`); return f(...a); }; }
});
const press = (sel) => (phone ? frame.locator(sel).tap() : frame.locator(sel).click());
const mode = () => frame.evaluate(() => window.hingePop.mode);
// The runtime hears of a mode change on the next frame: wait for it rather than sample once.
const playingIs = (want) => frame.waitForFunction((w) => window.__hpPortal.playing === w, want, { timeout: 5_000 }).then(() => true, () => false);
const adCalls = () => frame.evaluate(() => window.__calls.filter((c) => c.startsWith('ad:')));

await frame.waitForFunction(() => window.hingePop.mode === 'menu', null, { timeout: 30_000 });
check(await frame.locator('#play').isVisible(), 'menu up, Play visible');
check((await frame.locator('a').count()) === 0, 'no links anywhere in the game');
check(await frame.evaluate(() => getComputedStyle(document.body).userSelect === 'none'), 'user-select: none');

// Clears the level in play with real input: taps on the bubbles, and a swipe through one now and then.
async function clearLevel(n) {
  const box = await frame.locator('canvas#game').boundingBox();
  const fb = await (await page.$('#game')).boundingBox();
  const at = (x, y) => ({ x: fb.x + box.x + x, y: fb.y + box.y + y });
  let i = 0;
  const end = Date.now() + 90_000;
  while (Date.now() < end) {
    const s = await frame.evaluate(() => {
      const sim = window.hingePop.sim;
      if (window.hingePop.mode !== 'play') return null;
      const b = sim.bubbles.slice().sort((p, q) => q.r - p.r)[0];
      return b ? { x: b.x, y: b.y, r: b.r } : { none: true };
    });
    if (!s) break;
    if (s.none) { await page.waitForTimeout(100); continue; }
    const p = at(s.x, s.y);
    if (phone) await page.touchscreen.tap(p.x, p.y);
    else if (++i % 5 === 0) {
      await page.mouse.move(p.x - s.r * 1.5, p.y - 4); await page.mouse.down();
      await page.mouse.move(p.x, p.y, { steps: 3 }); await page.mouse.move(p.x + s.r * 1.5, p.y + 4, { steps: 3 }); await page.mouse.up();
    } else await page.mouse.click(p.x, p.y);
    await page.waitForTimeout(40);
  }
  await frame.waitForFunction(() => window.hingePop.mode === 'ended', null, { timeout: 30_000 }).catch(() => {});
  const r = await frame.evaluate(() => ({ mode: window.hingePop.mode, status: window.hingePop.sim.status, heading: document.getElementById('heading').textContent }));
  check(r.mode === 'ended', `game ${n}: reached its result (${r.heading})`);
  if (live && portal === 'crazygames') check(await playingIs(false), `game ${n}: gameplay stopped on the result`);
  return r;
}

// Game 1: Play opens the tour for a fresh player; skip it into level 1.
await press('#play');
await frame.waitForFunction(() => window.hingePop.mode === 'tour', null, { timeout: 10_000 }).then(() => check(true, 'first Play opens the tour'), () => check(false, 'first Play opens the tour'));
if (live && portal === 'crazygames') check(await playingIs(true), 'tour counts as gameplay');
await press('#tourSkip');
await frame.waitForFunction(() => window.hingePop.mode === 'play', null, { timeout: 10_000 });
await page.waitForTimeout(300);
if (live && portal === 'crazygames') {
  check(await playingIs(true), 'game 1: gameplay started (runtime)');
  check(sdkLogs.some((t) => /gameplay\s*start/i.test(t)), 'game 1: SDK gameplayStart fired (its own log)');
}
await clearLevel(1);
check((await adCalls()).length === 0, 'no ad before or after the first game');
// Leave the first result with the next level: never an ad here.
await press('#play');
await frame.waitForFunction(() => window.hingePop.mode === 'play', null, { timeout: 10_000 });
check((await adCalls()).length === 0, 'no ad when leaving the first result');
// Pause and resume mid-game: a break, then play again.
await press('#pause');
await frame.waitForFunction(() => window.hingePop.mode === 'paused', null, { timeout: 5_000 });
if (live && portal === 'crazygames') check(await playingIs(false), 'pause: gameplay stopped');
check((await adCalls()).length === 0, 'no ad on pause');
await press('#play');
await clearLevel(2);
// Leave the second result with Menu: the midgame ad is due. The menu must come back, ad or no ad.
await press('#menu');
await frame.waitForFunction(() => window.hingePop.mode === 'menu', null, { timeout: 60_000 }).then(() => check(true, 'back on the menu after the break'), () => check(false, 'back on the menu after the break'));
const calls = await adCalls();
if (live) check(calls.includes('ad:midgame'), `midgame ad asked for at the break (${calls.join(', ') || 'none'})`);
else check(calls.length === 0, 'no ad calls with the SDK down');
check(!calls.some((c) => /rewarded/.test(c)), 'no rewarded ad');

// Saves: the level reached is kept, in the data module on CrazyGames (SDK up), in localStorage everywhere.
const saved = await frame.evaluate(() => {
  const read = (s) => { try { return JSON.parse(s.getItem('hinge-pop-prefs') || '{}'); } catch { return {}; } };
  return { ls: read(localStorage), data: window.CrazyGames?.SDK?.data ? read(window.CrazyGames.SDK.data) : null, toured: read(localStorage).toured };
});
check(saved.ls.level === 3 && saved.toured === true, `saved in localStorage (level ${saved.ls.level})`);
if (live && portal === 'crazygames') check(saved.data?.level === 3, `saved in the CrazyGames data module (level ${saved.data?.level})`);

// Two players: the tour opens first; skip it, pause, back to the menu.
await press('#two');
await frame.waitForFunction(() => window.hingePop.mode === 'tour', null, { timeout: 10_000 });
await press('#tourSkip');
await frame.waitForFunction(() => window.hingePop.mode === 'play' && window.hingePop.sim.versus, null, { timeout: 10_000 }).then(() => check(true, 'two-player match starts'), () => check(false, 'two-player match starts'));
await press('#pause');
await frame.waitForFunction(() => window.hingePop.mode === 'paused', null, { timeout: 5_000 });
await press('#menu');
await frame.waitForFunction(() => window.hingePop.mode === 'menu', null, { timeout: 10_000 }).then(() => check(true, 'back on the menu'), () => check(false, 'back on the menu'));

if (portal === 'crazygames' && live) {
  check(sdkLogs.some((t) => /gameplay\s*stop/i.test(t)), 'SDK gameplayStop fired (its own log)');
  check(sdkLogs.some((t) => /loading\s*stop/i.test(t)), 'SDK loadingStop fired (its own log)');
}
if (blocked) check(sdkRequests.length > 0, `the SDK was asked for and refused (${sdkRequests.length} request(s))`);
check(forbidden.length === 0, `no request to mutaafaziz.com or for analytics${forbidden.length ? `: ${forbidden.slice(0, 5).join(' ')}` : ''}`);
check(missing.length === 0, `no missing files${missing.length ? `: ${missing.slice(0, 5).join(' ')}` : ''}`);
check(errors.length === 0, `no console errors in the game${errors.length ? `:\n      ${errors.slice(0, 8).join('\n      ')}` : ''}`);
if (thirdParty.length) console.log(`  note: the portal's own scripts threw (not the game): ${thirdParty.slice(0, 3).join(' | ')}`);

await browser.close();
for (const s of servers) s.close();
console.log(fail.length ? `\n${fail.length} check(s) failed` : '\nall checks passed');
process.exit(fail.length ? 1 : 0);
