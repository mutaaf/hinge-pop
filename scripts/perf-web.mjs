// Frame times for the web game under load, in headless Chromium. Compare runs on one machine only.
import { chromium } from 'playwright';
import { serve } from './serve.mjs';
const server = await serve(8791, process.env.PERF_ROOT || 'dist');
const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
await context.addInitScript(() => localStorage.setItem('hinge-pop-prefs', JSON.stringify({ toured: true, touredTwo: true, level: 29 })));
const page = await context.newPage();
if (process.env.PERF_THROTTLE) await (await context.newCDPSession(page)).send('Emulation.setCPUThrottlingRate', { rate: Number(process.env.PERF_THROTTLE) });
await page.goto('http://localhost:8791/hingepop/play/');
await page.waitForTimeout(300);
await page.click('#play').catch(() => {});
const result = await page.evaluate(() => new Promise((done) => {
  const times = [];
  let last = performance.now(), hits = 0;
  function frame(now) {
    times.push(now - last); last = now;
    const sim = window.hingePop.sim;
    sim.ready = 0;
    for (const p of sim.players) { p.shields = 3; p.meter = 0; }
    if (++hits % 30 === 0 && sim.bubbles.length) sim.tap(sim.bubbles[hits % sim.bubbles.length]);
    if (times.length >= 600) {
      const sorted = times.slice(30).sort((a, b) => a - b), at = (q) => sorted[Math.floor(sorted.length * q)];
      done({ p50: +at(.5).toFixed(1), p95: +at(.95).toFixed(1), p99: +at(.99).toFixed(1), max: +sorted.at(-1).toFixed(1), over25ms: sorted.filter((t) => t > 25).length });
    } else requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
}));
console.log(JSON.stringify(result));
await browser.close(); server.close(); process.exit(0);
