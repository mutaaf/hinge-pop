import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import { mkdirSync } from 'node:fs';
const out = fileURLToPath(new URL('../test-results', import.meta.url));
mkdirSync(out, { recursive: true });
const url = process.env.E2E_URL || new URL('../dist/hingepop/index.html', import.meta.url).href;
const clearAll = (page) => page.evaluate(() => { const s = window.hingePop.sim; s.ready = 0; let guard = 0; while (s.bubbles.length && guard++ < 500) s.tap(s.bubbles[0]); });
(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' && !/fonts\.g|ERR_/.test(m.text())) errors.push(m.text()); });
  await page.goto(url);
  await page.waitForTimeout(250);
  await page.screenshot({ path: out + '/m1-menu.png' });
  const r = {};
  const info = () => page.evaluate(() => { const s = window.hingePop.sim; return { level: s.level, n: s.bubbles.length, speedMul: s.speedMul, vertical: s.vertical, status: s.status, players: s.players.map(p => ({ score: p.score, taps: p.taps, meter: p.meter, crossings: p.crossings, zaps: p.zaps, shields: p.shields })) }; });

  // Levels through the real buttons.
  await page.tap('#play');
  await page.waitForTimeout(100);
  r.level1 = await info();
  r.levelsSeen = [];
  let carried = [];
  for (let i = 0; i < 7; i++) {
    const st = await info();
    r.levelsSeen.push([st.level, st.n, st.speedMul]);
    await clearAll(page);
    await page.waitForTimeout(800);
    carried.push((await info()).players[0].score);
    if (i === 0) r.level1Panel = await page.textContent('#sub');
    await page.tap('#play');
    await page.waitForTimeout(80);
  }
  r.scoreCarries = (await info()).players[0].score === carried[carried.length - 1] && carried[carried.length - 1] > carried[0];
  await page.screenshot({ path: out + '/m2-level8.png' });

  // Lose on the current level: same level again, score back to the level's start.
  const beforeLoss = await info();
  await page.evaluate(() => { const s = window.hingePop.sim; s.ready = 0; s.players[0].score += 999; s.players[0].shields = 1; s.players[0].meter = 3; const b = s.bubbles[0]; b.vx = 0; b.vy = 0; if (s.vertical) { b.x = s.line() - 2; b.vx = 300; } else { b.y = s.line() - 2; b.vy = 300; } b.side = -1; b.grace = 0; });
  await page.waitForTimeout(900);
  r.lossHeading = await page.textContent('#heading');
  await page.tap('#play');
  await page.waitForTimeout(80);
  const afterRetry = await info();
  r.retry = { sameLevel: afterRetry.level === beforeLoss.level, scoreRestored: afterRetry.players[0].score === beforeLoss.players[0].score, shields: afterRetry.players[0].shields };

  // Progress survives a reload, and Back to level 1 works.
  await page.reload();
  await page.waitForTimeout(250);
  r.afterReload = { playLabel: await page.textContent('#play'), hasBack: await page.isVisible('#levelOne') };
  await page.tap('#levelOne');
  await page.waitForTimeout(80);
  r.backToOne = (await info()).level;
  await page.tap('#pause');
  await page.tap('#menu');
  await page.waitForTimeout(100);

  // Two players, landscape.
  await page.setViewportSize({ width: 844, height: 390 });
  await page.waitForTimeout(200);
  r.landscapeMenu = await page.evaluate(() => { const b = document.getElementById('play').getBoundingClientRect(); return { bottom: Math.round(b.bottom), vh: innerHeight }; });
  await page.screenshot({ path: out + '/m3-menu-landscape.png' });
  await page.tap('#two');
  await page.waitForTimeout(1000);
  r.versusStart = await info();
  await page.evaluate(() => { for (const b of window.hingePop.sim.bubbles) { b.vx = 0; b.vy = 0; } });
  const pos = () => page.evaluate(() => { const s = window.hingePop.sim; const L = s.bubbles.find(b => b.side < 0 && b.g === 0), R = s.bubbles.find(b => b.side > 0 && b.g === 0); return { L: { x: L.x, y: L.y }, R: { x: R.x, y: R.y } }; });

  // Each finger scores for its own side.
  let p = await pos();
  await page.touchscreen.tap(p.L.x, p.L.y); await page.waitForTimeout(40);
  await page.evaluate(() => { for (const b of window.hingePop.sim.bubbles) { b.vx = 0; b.vy = 0; } });
  r.afterLeftTap = (await info()).players.map(x => x.taps);
  p = await pos();
  await page.touchscreen.tap(p.R.x, p.R.y); await page.waitForTimeout(40);
  await page.evaluate(() => { for (const b of window.hingePop.sim.bubbles) { b.vx = 0; b.vy = 0; } });
  r.afterRightTap = (await info()).players.map(x => x.taps);

  // Two fingers down at the same moment.
  p = await pos();
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: p.L.x, y: p.L.y, id: 1 }, { x: p.R.x, y: p.R.y, id: 2 }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForTimeout(60);
  await page.evaluate(() => { for (const b of window.hingePop.sim.bubbles) { b.vx = 0; b.vy = 0; } });
  r.afterBothFingers = (await info()).players.map(x => x.taps);

  // A touch on the far side of the hinge cannot take the other player's bubble.
  r.reach = await page.evaluate(() => { const s = window.hingePop.sim; const b = s.bubbles.find(x => x.side > 0); b.x = s.line() + 4; const hit = s.hit(s.line() - 4, b.y); return hit === b ? 'took it' : 'blocked'; });
  await page.evaluate(() => { const s = window.hingePop.sim; const b = s.bubbles.find(x => x.side > 0); b.x = s.w * 0.8; });
  await page.screenshot({ path: out + '/m4-versus.png' });

  // A crossing charges the sender and lands on the other side.
  const before = await info();
  r.crossing = await page.evaluate(() => { const s = window.hingePop.sim; const b = s.bubbles.find(x => x.side < 0 && x.g < 3); window.__g = b.g; b.x = s.line() - 2; b.vx = 300; b.vy = 0; b.grace = 0; const n = s.bubbles.filter(x => x.side > 0).length; return { rightBefore: n }; });
  await page.waitForTimeout(100);
  await page.evaluate(() => { for (const b of window.hingePop.sim.bubbles) { b.vx = 0; b.vy = 0; } });
  const after = await info();
  r.crossing.leftMeter = [before.players[0].meter, after.players[0].meter];
  r.crossing.rightMeter = [before.players[1].meter, after.players[1].meter];
  r.crossing.rightAfter = await page.evaluate(() => window.hingePop.sim.bubbles.filter(x => x.side > 0).length);

  // A free pop credits the sender.
  const z0 = await info();
  const had = await page.evaluate(() => { const s = window.hingePop.sim; let b = s.bubbles.find(x => x.side > 0 && x.g === 3); if (!b) { b = s.bubbles.find(x => x.side > 0); b.g = 3; b.r = 14; } b.x = s.line() + 2; b.vx = -300; b.vy = 0; b.grace = 0; return true; });
  await page.waitForTimeout(100);
  const z1 = await info();
  r.freePop = { rightZaps: [z0.players[1].zaps, z1.players[1].zaps], rightMeter: [z0.players[1].meter, z1.players[1].meter], rightScoreGain: z1.players[1].score - z0.players[1].score, leftZaps: z1.players[0].zaps };

  // Knock out the left player: right wins.
  await page.evaluate(() => { const s = window.hingePop.sim; s.players[0].shields = 1; s.players[0].meter = 3; const b = s.bubbles.find(x => x.side < 0 && x.g < 3); b.x = s.line() - 2; b.vx = 300; b.vy = 0; b.grace = 0; });
  await page.waitForTimeout(900);
  r.knockout = await page.textContent('#heading');
  r.knockoutPanel = await page.evaluate(() => { const b = document.getElementById('play').getBoundingClientRect(); return { bottom: Math.round(b.bottom), vh: innerHeight }; });
  await page.screenshot({ path: out + '/m5-result.png' });

  // Rematch resets, then clearing every bubble decides by score.
  await page.tap('#play');
  await page.waitForTimeout(100);
  r.rematch = (await info()).players.map(x => [x.score, x.shields]);
  await page.evaluate(() => { const s = window.hingePop.sim; s.ready = 0; let g = 0; while (s.bubbles.length && g++ < 500) s.tap(s.bubbles[0]); });
  await page.waitForTimeout(800);
  r.clearedHeading = await page.textContent('#heading');
  await page.tap('#menu');
  await page.waitForTimeout(100);
  r.menuHudSolo = await page.evaluate(() => document.getElementById('p1').hidden);

  // Portrait two players: HUD fits with no page overflow.
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(200);
  await page.tap('#two');
  await page.waitForTimeout(1000);
  r.portrait = await page.evaluate(() => { const s = window.hingePop.sim; const a = document.getElementById('p0').getBoundingClientRect(), b = document.getElementById('p1').getBoundingClientRect(), hud = document.getElementById('hud'); return { vertical: s.vertical, overflow: document.documentElement.scrollWidth > innerWidth, hudOverflow: hud.scrollWidth > hud.clientWidth, p0: [Math.round(a.left), Math.round(a.right)], p1: [Math.round(b.left), Math.round(b.right)] }; });
  await page.screenshot({ path: out + '/m6-versus-portrait.png' });
  r.errors = errors;
  console.log(JSON.stringify(r, null, 1));
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
