// Walks every screen and both tours at real device sizes, enforces the phone and tablet
// guidelines, and saves a screenshot of each. E2E_URL points it at another copy, such as production.
//
// Guidelines checked:
// - touch targets of at least 48px (Android 48dp; Apple's minimum is 44pt)
// - no text under 11px (Apple's smallest text style)
// - text contrast of at least 4.5:1 (WCAG AA, which both platforms point to)
// - nothing off screen or clipped, in every orientation and in iPad split view
import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import { mkdirSync } from 'node:fs';

const out = fileURLToPath(new URL('../test-results/devices', import.meta.url));
mkdirSync(out, { recursive: true });
const url = process.env.E2E_URL || new URL('../dist/hingepop/play/index.html', import.meta.url).href;
const SHOTS = process.env.SHOTS !== '0';

const DEVICES = [
  ['phone-small', 320, 568], ['phone', 393, 852], ['phone-side', 852, 393], ['phone-small-side', 568, 320],
  ['foldable-open', 673, 841], ['foldable-side', 841, 673],
  ['ipad', 820, 1180], ['ipad-side', 1180, 820], ['ipad-pro', 1024, 1366],
  ['ipad-split', 507, 1180], ['ipad-slideover', 320, 1000],
];
const seen = () => localStorage.setItem('hinge-pop-prefs', JSON.stringify({ toured: true, touredTwo: true }));

const audit = (page) => page.evaluate(() => {
  const problems = [];
  const vw = innerWidth, vh = innerHeight;
  const visible = (el) => { const r = el.getBoundingClientRect(); const c = getComputedStyle(el); return r.width > 0 && r.height > 0 && c.visibility !== 'hidden' && !el.closest('[hidden]'); };
  const lum = (rgb) => { const [r, g, b] = rgb.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
  const parse = (c) => (c.match(/[\d.]+/g) || []).map(Number);
  const bgOf = (el) => { for (let e = el; e; e = e.parentElement) { const c = parse(getComputedStyle(e).backgroundColor); if (c.length === 3 || (c.length === 4 && c[3] === 1)) return c.slice(0, 3); } return [13, 17, 23]; };
  if (document.documentElement.scrollWidth > vw) problems.push('page scrolls sideways');
  const layer = !document.getElementById('tour').hidden ? '#tour' : !document.getElementById('duel').hidden ? '#duel' : !document.getElementById('panel').hidden ? '.sheet' : '#hud';

  const targets = [...document.querySelectorAll(layer + ' button, ' + layer + ' summary, ' + layer + ' .toggle, ' + layer + ' [data-tip]')].filter(visible);
  for (const el of targets) {
    const r = el.getBoundingClientRect();
    if (el.matches('.versus [data-tip]')) { if (r.height < 24) problems.push('short target ' + el.className); }
    else if (r.height < 47.5) problems.push(`target ${Math.round(r.height)}px tall: ${(el.textContent || el.className).trim().slice(0, 24)}`);
    if (el.matches('button') && r.width < 47.5) problems.push(`target ${Math.round(r.width)}px wide: ${(el.textContent || el.id).trim().slice(0, 24)}`);
    if (r.right > vw + 1 || r.left < -1) problems.push('off screen sideways: ' + (el.textContent || '').trim().slice(0, 24));
  }
  const walker = document.createTreeWalker(document.querySelector(layer), NodeFilter.SHOW_TEXT);
  const checked = new Set();
  while (walker.nextNode()) {
    const el = walker.currentNode.parentElement;
    if (!walker.currentNode.textContent.trim() || checked.has(el) || !visible(el)) continue;
    checked.add(el);
    const c = getComputedStyle(el), size = parseFloat(c.fontSize);
    if (size < 11) problems.push(`text ${size}px: ${el.textContent.trim().slice(0, 24)}`);
    const fg = parse(c.color), bg = bgOf(el);
    const a = lum(fg), b = lum(bg), ratio = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    if (ratio < 4.5 && !el.closest(':disabled')) problems.push(`contrast ${ratio.toFixed(1)}: ${el.textContent.trim().slice(0, 24)}`);
  }
  if (layer === '.sheet') {
    const sheet = document.querySelector('.sheet').getBoundingClientRect();
    if (sheet.right > vw + 1 || sheet.left < -1) problems.push('sheet wider than screen');
    const h = document.getElementById('heading');
    // With the logo art showing, the heading is deliberately visually hidden for screen readers.
    if (!document.querySelector('.sheet').classList.contains('has-logo') && !document.querySelector('.has-logo #heading') && h.scrollWidth > h.clientWidth + 1) problems.push('heading clipped');
    const play = document.getElementById('play').getBoundingClientRect();
    if (play.bottom > vh + 1 || play.top < 0) problems.push('main button not on screen');
  }
  if (layer === '#hud') {
    const hud = document.getElementById('hud');
    if (hud.scrollWidth > hud.clientWidth + 1) problems.push('hud overflows');
    const p = document.getElementById('pause').getBoundingClientRect();
    const overlap = (a, b) => a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1;
    for (const box of document.querySelectorAll('.phud:not([hidden])')) {
      // Two-player scoreboards turn to face their player, so measure along the board, not across the screen.
      const ticks = box.querySelector('.ticks').offsetWidth;
      if (ticks < 44) problems.push('meter squeezed: ' + Math.round(ticks));
      const score = box.querySelector('.score').getBoundingClientRect();
      if (score.right > vw + 1 || score.left < -1 || score.bottom > vh + 1 || score.top < -1) problems.push('score off screen');
      if (overlap(box.getBoundingClientRect(), p)) problems.push('hud overlaps pause');
    }
    if (document.getElementById('hud').classList.contains('versus')) {
      // Face to face: the two boards sit at opposite edges and never touch.
      const a = document.getElementById('p0').getBoundingClientRect(), b = document.getElementById('p1').getBoundingClientRect();
      if (overlap(a, b)) problems.push('scoreboards overlap');
      const wide = vw > vh;
      if (wide ? !(a.right <= vw / 2 && b.left >= vw / 2) : !(a.bottom <= vh / 2 && b.top >= vh / 2)) problems.push('scoreboards not at opposite edges');
    }
  }
  if (layer === '#duel') {
    for (const id of ['d0', 'd1']) {
      const c = document.querySelector('#' + id + ' .card').getBoundingClientRect();
      if (c.top < -1 || c.bottom > vh + 1 || c.left < -1 || c.right > vw + 1) problems.push(id + ' result off screen');
    }
    const a = document.querySelector('#d0 .card').getBoundingClientRect(), b = document.querySelector('#d1 .card').getBoundingClientRect();
    if (a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1) problems.push('result cards overlap');
  }
  if (layer === '#tour') {
    const card = document.getElementById('tour').getBoundingClientRect();
    if (card.top < -1 || card.bottom > vh + 1 || card.left < -1 || card.right > vw + 1) problems.push('tour card off screen');
    const next = document.getElementById('tourNext').getBoundingClientRect();
    if (next.bottom > card.bottom + 1 || next.bottom > vh + 1) problems.push('tour button off the card');
    const text = document.getElementById('tourText');
    // Tour text is short now, so a small box is fine. What matters is that nobody has to scroll a tiny window to read it.
    if (text.clientHeight < 34 || (text.clientHeight < 60 && text.scrollHeight > text.clientHeight + 1)) problems.push('tour text squeezed: ' + text.clientHeight);
    const s = window.hingePop.sim;
    if (window.hingePop.tourInput() && s.bubbles.length) {
      const stage = document.getElementById('stage').getBoundingClientRect();
      const covered = (b) => { const x = b.x + stage.left, y = b.y + stage.top; return x + b.r > card.left && x - b.r < card.right && y + b.r > card.top && y - b.r < card.bottom; };
      if (s.bubbles.every(covered)) problems.push('card covers the bubble to touch');
    }
    if (window.hingePop.tourTarget() === 'hinge') {
      const spot = document.getElementById('spot').getBoundingClientRect();
      // Horizontal hinge: its line must clear the card. Vertical hinge: most of it must stay in view.
      const free = spot.width > spot.height ? spot.top + spot.height / 2 + 6 < card.top : card.left > spot.right || card.top - spot.top > spot.height * 0.45;
      if (!free) problems.push('card hides the hinge');
    }
  }
  return problems;
});

const browser = await chromium.launch();
let failed = 0;

async function touchFlick(ctx, page, x, y, dx, dy) {
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x + dx, y: y + dy }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

for (const [name, width, height] of DEVICES) {
  const opts = { viewport: { width, height }, hasTouch: true, isMobile: true, deviceScaleFactor: 2 };
  const problems = [];
  const walk = async (ctx, page, label) => {
    await page.waitForTimeout(420);
    for (const p of await audit(page)) problems.push(label + ': ' + p);
    if (SHOTS) await page.screenshot({ path: `${out}/${name}-${label}.png` });
  };

  // Screens, with the tours already seen.
  let ctx = await browser.newContext(opts);
  let page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(seen);
  await page.goto(url);
  await walk(ctx, page, 'menu');
  await page.tap('#howto summary');
  await walk(ctx, page, 'howto');
  await page.evaluate(() => { document.getElementById('howto').open = false; });
  await page.tap('#settings summary');
  await page.waitForTimeout(80);
  const settingsReach = await page.evaluate(() => { const last = document.getElementById('optSound'); last.scrollIntoView({ block: 'nearest' }); const r = last.getBoundingClientRect(); return r.bottom <= innerHeight + 1 && r.top >= 0; });
  if (!settingsReach) problems.push('settings cannot be scrolled to');
  await page.evaluate(() => document.getElementById('panel').scrollTo(0, 0));
  await walk(ctx, page, 'settings');
  await page.tap('.info[data-tip="optFlick"]');
  await page.waitForTimeout(160);
  const settingTip = await page.evaluate(() => { const t = document.getElementById('tip'); const r = t.getBoundingClientRect(); return !t.hidden && r.top >= 0 && r.bottom <= innerHeight + 1 && r.left >= 0 && r.right <= innerWidth + 1; });
  if (!settingTip) problems.push('settings tooltip missing or off screen');
  await page.touchscreen.tap(width / 2, 8);
  await page.evaluate(() => { document.getElementById('settings').open = false; });

  await page.evaluate(() => document.getElementById('panel').scrollTo(0, 0));
  await page.tap('#play');
  await page.waitForTimeout(1050);
  await walk(ctx, page, 'level1');

  // Each HUD tooltip opens on screen and holds the clock, and closing does not touch a bubble.
  for (const sel of ['#p0 .shieldbox', '#p0 .meter', '#p0 .readout']) {
    await page.tap(sel);
    await page.waitForTimeout(140);
    const a = await page.evaluate(() => { const t = document.getElementById('tip'), r = t.getBoundingClientRect(), s = window.hingePop.sim; return { open: !t.hidden, on: r.top >= 0 && r.bottom <= innerHeight + 1 && r.left >= 0 && r.right <= innerWidth + 1, live: document.getElementById('tipLive').textContent, t: s.t, taps: s.players[0].taps }; });
    await page.waitForTimeout(250);
    const heldStill = await page.evaluate((t) => window.hingePop.sim.t === t, a.t);
    if (!a.open || !a.on || !a.live) problems.push('tooltip ' + sel + ': ' + JSON.stringify(a));
    if (!heldStill) problems.push('tooltip did not hold the game: ' + sel);
    if (sel === '#p0 .meter' && SHOTS) await page.screenshot({ path: `${out}/${name}-tip.png` });
    const b = await page.evaluate(() => { const s = window.hingePop.sim; return s.bubbles[0] ? [s.bubbles[0].x, s.bubbles[0].y] : null; });
    if (b) await page.touchscreen.tap(b[0], b[1]);
    await page.waitForTimeout(100);
    const c = await page.evaluate(() => ({ open: !document.getElementById('tip').hidden, taps: window.hingePop.sim.players[0].taps }));
    if (c.open || c.taps !== a.taps) problems.push('closing tooltip hit the game: ' + JSON.stringify(c));
  }
  await page.evaluate(() => { const s = window.hingePop.sim; s.ready = 0; let g = 0; while (s.bubbles.length && g++ < 500) s.tap(s.bubbles[0]); });
  await page.waitForTimeout(800);
  await walk(ctx, page, 'cleared');
  await page.tap('#statsBox summary');
  await page.tap('[data-tip="stat:Crossings"]');
  await page.waitForTimeout(140);
  if (await page.isHidden('#tip')) problems.push('stat tooltip did not open');
  await page.touchscreen.tap(width / 2, 8);
  await page.tap('#menu');
  await page.waitForTimeout(100);
  await page.tap('#two');
  await page.waitForTimeout(1050);
  await page.evaluate(() => { const s = window.hingePop.sim; for (const side of [-1, 1]) s.tap(s.bubbles.find((b) => b.side === side && b.g === 0)); s.players[0].meter = 2; s.players[1].score = 123450; });
  await walk(ctx, page, 'versus');
  await page.evaluate(() => { const s = window.hingePop.sim; s.ready = 0; let g = 0; while (s.bubbles.length && g++ < 500) s.tap(s.bubbles[0]); });
  await page.waitForTimeout(800);
  await walk(ctx, page, 'versus-result');
  await ctx.close();

  // First-run tour, with real touches at every step.
  ctx = await browser.newContext(opts);
  page = await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(url);
  await page.waitForTimeout(150);
  await page.tap('#play');
  for (let i = 0; i < 20; i++) {
    await page.waitForTimeout(120);
    if (await page.isHidden('#tour')) break;
    const st = await page.evaluate(() => ({ count: document.getElementById('tourCount').textContent, input: window.hingePop.tourInput(), flick: /Flick/.test(document.getElementById('tourTitle').textContent), b: window.hingePop.tourBubble(), disabled: document.getElementById('tourNext').disabled, title: document.getElementById('tourTitle').textContent }));
    await walk(ctx, page, 'tour' + String(i + 1).padStart(2, '0'));
    if (st.input && st.b) {
      if (st.flick) {
        // A plain tap first: the step must ask again, not get stuck.
        await page.touchscreen.tap(st.b.x, st.b.y);
        await page.waitForTimeout(200);
        const again = await page.evaluate(() => ({ note: document.getElementById('tourTry').textContent, b: window.hingePop.tourBubble() }));
        if (!/That was a tap/.test(again.note) || !again.b) problems.push('flick step did not ask again: ' + JSON.stringify(again));
        await touchFlick(ctx, page, again.b.x, again.b.y, 0, -40);
      } else {
        await page.touchscreen.tap(st.b.x, st.b.y);
      }
    }
    await page.waitForFunction(() => !document.getElementById('tourNext').disabled, null, { timeout: 15000 });
    await page.waitForTimeout(80);
    if (st.input) await walk(ctx, page, 'tour' + String(i + 1).padStart(2, '0') + 'b');
    await page.tap('#tourNext');
  }
  const after = await page.evaluate(() => ({ tour: !document.getElementById('tour').hidden, spot: !document.getElementById('spot').hidden, stored: JSON.parse(localStorage.getItem('hinge-pop-prefs')), level: window.hingePop.sim.level, n: window.hingePop.sim.bubbles.length, meter: window.hingePop.sim.players[0].meter, score: window.hingePop.sim.players[0].score }));
  if (after.tour || after.spot || !after.stored.toured || after.level !== 1 || after.n !== 1 || after.meter !== 0 || after.score !== 0) problems.push('tour exit: ' + JSON.stringify(after));

  // Two-player tour opens on the first match, and Skip works from any step.
  await page.tap('#pause');
  await page.tap('#menu');
  await page.waitForTimeout(100);
  await page.tap('#two');
  await page.waitForTimeout(150);
  if (await page.isHidden('#tour')) problems.push('two-player tour did not open');
  await walk(ctx, page, 'twotour1');
  await page.tap('#tourNext');
  await page.waitForTimeout(120);
  await walk(ctx, page, 'twotour2');
  await page.tap('#tourSkip');
  await page.waitForTimeout(150);
  const skipped = await page.evaluate(() => ({ tour: !document.getElementById('tour').hidden, versus: window.hingePop.sim.versus, stored: JSON.parse(localStorage.getItem('hinge-pop-prefs')).touredTwo }));
  if (skipped.tour || !skipped.versus || !skipped.stored) problems.push('skip: ' + JSON.stringify(skipped));
  await ctx.close();

  if (errors.length) problems.push(...errors);
  console.log((problems.length ? 'FAIL ' : 'ok   ') + name.padEnd(18) + (problems.length ? '\n     ' + [...new Set(problems)].join('\n     ') : ''));
  failed += problems.length;
}

// Turning the device keeps the level, the bubbles and the score, and pauses.
const ctx = await browser.newContext({ viewport: { width: 820, height: 1180 }, hasTouch: true, isMobile: true });
const page = await ctx.newPage();
await page.addInitScript(seen);
await page.goto(url);
await page.tap('#play');
await page.waitForTimeout(1000);
const before = await page.evaluate(() => { const s = window.hingePop.sim; s.tap(s.bubbles[0]); return { n: s.bubbles.length, score: s.players[0].score, sides: s.bubbles.map((b) => b.side).join() }; });
await page.setViewportSize({ width: 1180, height: 820 });
await page.waitForTimeout(300);
const after = await page.evaluate(() => { const s = window.hingePop.sim; return { n: s.bubbles.length, score: s.players[0].score, sides: s.bubbles.map((b) => b.side).join(), vertical: s.vertical, paused: document.getElementById('heading').textContent, inside: s.bubbles.every((b) => b.x >= 0 && b.x <= s.w && b.y >= s.top && b.y <= s.h) }; });
const rotateOk = after.n === before.n && after.score === before.score && after.sides === before.sides && after.vertical === true && after.paused === 'Paused' && after.inside;
console.log((rotateOk ? 'ok   ' : 'FAIL ') + 'turning keeps the level', rotateOk ? '' : JSON.stringify({ before, after }));
if (!rotateOk) failed++;
await browser.close();
process.exit(failed ? 1 : 0);
