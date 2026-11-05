// Level curve and two-player fairness, using the real sim code.
import { loadSim } from '../test/load-sim.mjs';
const { createSim, levelConfig } = loadSim();
const rngOf = (a) => () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
const tth = (s, b) => { const p = s.vertical ? b.x : b.y, v = s.vertical ? b.vx : b.vy, g = s.line() - p; return g * v > 0 ? g / v : Infinity; };
const urgent = (s, l) => l.reduce((a, b) => tth(s, a) <= tth(s, b) ? a : b);
const jitter = (s, r) => { for (const b of s.bubbles) { const a = Math.atan2(b.vy, b.vx) + (r() - .5) * .5, sp = Math.hypot(b.vx, b.vy); b.vx = Math.cos(a) * sp; b.vy = Math.sin(a) * sp; } };
const P = {
  idle: null,
  random: (s, r, l) => l[Math.floor(r() * l.length)],
  nearest: (s, r, l) => urgent(s, l),
};
function solo(level, k, rate, seed) {
  const r = rngOf(seed), s = createSim({ w: 390, h: 760, top: 70, level });
  jitter(s, r);
  let next = 0;
  while (s.status === 'playing' && s.t < 400) {
    s.step(1 / 120);
    if (P[k] && s.status === 'playing' && s.ready <= 0 && s.t >= next && s.bubbles.length) { s.tap(P[k](s, r, s.bubbles)); next = s.t + (1 / rate) * (.75 + r() * .5); }
  }
  return { won: s.status === 'won', t: s.t, cross: s.players[0].crossings, stuck: s.status === 'playing', shields: s.players[0].shields };
}
const bots = [['idle', 0], ['random', 1], ['random', 2], ['random', 3], ['random', 4], ['nearest', 1], ['nearest', 1.5], ['nearest', 2], ['nearest', 3]];
console.log('level balls speed |', bots.map(b => (b[0][0] + (b[1] || '')).padStart(5)).join(''), '| nearest2 time');
for (const lv of [1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 16]) {
  const cf = levelConfig(lv);
  const cells = bots.map(([k, rate]) => { const rs = [...Array(200)].map((_, i) => solo(lv, k, rate, i + 1)); if (rs.some(x => x.stuck)) throw new Error('stuck'); return String(Math.round(rs.filter(x => x.won).length / 2)).padStart(5); });
  const t = [...Array(200)].map((_, i) => solo(lv, 'nearest', 2, i + 1)).reduce((a, x) => a + x.t, 0) / 200;
  console.log(String(lv).padStart(5), String(cf.count).padStart(5), cf.speed.toFixed(2).padStart(5), '|', cells.join(''), '|', t.toFixed(0) + 's');
}

function duel(ka, ra, kb, rb, seed, w = 844, h = 390) {
  const r = rngOf(seed), s = createSim({ w, h, top: 65, versus: true });
  jitter(s, r);
  const next = [0, 0], cfg = [[ka, ra], [kb, rb]];
  while (s.status === 'playing' && s.t < 400) {
    s.step(1 / 120);
    for (const i of [0, 1]) {
      if (s.status !== 'playing' || s.ready > 0 || s.t < next[i]) continue;
      const mine = s.bubbles.filter(b => b.side === (i ? 1 : -1));
      if (!mine.length) continue;
      if (!P[cfg[i][0]]) continue;
      s.tap(P[cfg[i][0]](s, r, mine));
      next[i] = s.t + (1 / cfg[i][1]) * (.75 + r() * .5);
    }
  }
  return { w: s.winner, t: s.t, stuck: s.status === 'playing', out: s.players.some(p => p.shields <= 0) };
}
console.log('\n2 players, 400 matches: left% right% draw% | avg time | ended by shields');
for (const [n, a, ra, b, rb, w, h] of [['equal 2/s v 2/s landscape', 'nearest', 2, 'nearest', 2], ['equal 3/s v 3/s landscape', 'nearest', 3, 'nearest', 3], ['equal 2/s v 2/s portrait', 'nearest', 2, 'nearest', 2, 390, 844], ['stronger left 3/s v 2/s', 'nearest', 3, 'nearest', 2], ['stronger right 2/s v 3/s', 'nearest', 2, 'nearest', 3], ['nobody plays', 'idle', 1, 'idle', 1]]) {
  const rs = [...Array(400)].map((_, i) => duel(a, ra, b, rb, i + 1, w, h));
  if (rs.some(x => x.stuck)) throw new Error('stuck ' + n);
  const pct = (f) => Math.round(rs.filter(f).length / 4);
  console.log(n.padEnd(28), pct(x => x.w === 0), pct(x => x.w === 1), pct(x => x.w === null), '|', (rs.reduce((q, x) => q + x.t, 0) / 400).toFixed(0) + 's', '|', pct(x => x.out) + '%');
}
