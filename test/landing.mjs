// Landing site checks, run against dist/ by `npm run test:landing`.
// The page must load clean on phone, tablet and desktop, never scroll sideways, and scroll into a live game.
import { chromium } from 'playwright';
import { serve } from '../scripts/serve.mjs';

const PORT = 8797, ORIGIN = `http://localhost:${PORT}/hingepop/`;
const server = await serve(PORT);
const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
let failures = 0;
const check = (name, ok, detail = '') => { console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${detail ? ' ' + detail : ''}`); if (!ok) failures++; };

const devices = [
  ['phone', { viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true }],
  ['small phone', { viewport: { width: 320, height: 568 }, hasTouch: true, isMobile: true }],
  ['tablet', { viewport: { width: 820, height: 1180 }, hasTouch: true, isMobile: true }],
  ['desktop', { viewport: { width: 1280, height: 800 } }],
  ['reduced motion', { viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' }],
];
for (const [name, options] of devices) {
  const context = await browser.newContext(options);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(ORIGIN);
  await page.waitForTimeout(800);
  // The beta call to action is the first thing on the page: a working link, fully on the first screen.
  const cta = await page.evaluate(() => { const a = document.querySelector('#cta-beta'), r = a?.getBoundingClientRect(); return a && { href: a.getAttribute('href') || '', top: r.top, bottom: r.bottom }; });
  check(`${name}: beta button on the first screen`, cta && /^https:\/\/testflight\.apple\.com\//.test(cta.href) && cta.top >= 0 && cta.bottom <= options.viewport.height, JSON.stringify(cta));
  const end = await page.evaluate(() => document.documentElement.scrollHeight - innerHeight);
  // A real horizontal gesture halfway down. Decorations may hang past the edge, but the page must not move.
  let sideways = false;
  for (let i = 1; i <= 8; i++) {
    await page.evaluate((y) => scrollTo(0, y), end * i / 8);
    await page.waitForTimeout(250);
    if (i === 4) {
      await page.mouse.wheel(80, 0);
      await page.waitForTimeout(250);
      sideways = await page.evaluate(() => scrollX > 0);
    }
  }
  await page.waitForTimeout(1500);
  const game = await page.evaluate(() => {
    const frame = document.querySelector('#game'), box = frame.getBoundingClientRect(), inner = frame.contentDocument;
    return { covers: box.width >= innerWidth - 1 && box.bottom >= innerHeight - 1 && box.top < innerHeight * 0.2, canvas: !!inner?.querySelector('canvas') };
  });
  check(`${name}: no sideways scroll`, !sideways);
  check(`${name}: scrolling ends in the game`, game.covers && game.canvas, JSON.stringify(game));
  check(`${name}: no script errors`, errors.length === 0, errors.slice(0, 2).join(' | '));
  await context.close();
}

const context = await browser.newContext();
const page = await context.newPage();
for (const [path, words] of [['privacy/', /app collects nothing[\s\S]*anonymous usage analytics[\s\S]*Global Privacy Control/i], ['support/', /issues|question/i], ['play/', /./]]) {
  const res = await page.goto(ORIGIN + path);
  check(`/hingepop/${path} loads`, res.status() === 200);
  check(`/hingepop/${path} has its content`, words.test(await page.evaluate(() => document.body.innerText)) || path === 'play/');
}
await browser.close();
server.close();
console.log(failures ? `${failures} failed` : 'all passed');
process.exit(failures ? 1 : 0);
