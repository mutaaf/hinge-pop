import assert from 'node:assert/strict';
import { test } from 'node:test';
import { loadSim } from './load-sim.mjs';

const { createSim, levelConfig, CFG } = loadSim();
const solo = (level = 1) => { const s = createSim({ w: 390, h: 760, top: 70, level }); s.ready = 0; return s; };
const versus = () => { const s = createSim({ w: 844, h: 390, top: 65, versus: true }); s.ready = 0; return s; };

function sendAcross(s, b) {
  b.grace = 0;
  b.vx = 0; b.vy = 0;
  if (s.vertical) { b.x = s.line() - b.side * 1; b.vx = -b.side * 600; }
  else { b.y = s.line() - b.side * 1; b.vy = -b.side * 600; }
  for (const other of s.bubbles) if (other !== b) { other.vx = 0; other.vy = 0; }
  s.step(1 / 60);
}
const makeSmallest = (b) => { b.g = 3; b.r = CFG.radii[3]; };

test('levels ramp by how much tapping they ask for, starting with one big bubble', () => {
  assert.deepEqual(Array.from(levelConfig(1).sizes), [0]);
  assert.deepEqual(Array.from(levelConfig(2).sizes), [0, 2]);
  assert.deepEqual(Array.from(levelConfig(3).sizes), [0, 1]);
  assert.ok(levelConfig(1).speed < levelConfig(2).speed);
  const work = (n) => Array.from(levelConfig(n).sizes).reduce((t, size) => t + CFG.work[size], 0);
  for (let n = 2; n <= 9; n++) assert.ok(work(n) > work(n - 1), 'level ' + n);
  for (let n = 1; n <= 300; n++) {
    assert.ok(work(n) <= CFG.maxWork, 'level ' + n + ' asks for ' + work(n));
    assert.ok(levelConfig(n).speed <= CFG.maxSpeed);
    const fresh = solo(n);
    assert.equal(fresh.bubbles.length + fresh.arrivals.length, levelConfig(n).sizes.length);
  }
});

test('one large bubble takes 15 taps to clear when nothing chains, and a clean clear earns the bonus', () => {
  const saved = CFG.chainPopRadius;
  CFG.chainPopRadius = 0;
  const s = solo(1);
  let taps = 0;
  while (s.bubbles.length) { s.tap(s.bubbles[0]); taps++; }
  CFG.chainPopRadius = saved;
  assert.equal(taps, 15);
  assert.equal(s.status, 'won');
  assert.equal(s.cleanBonus, true);
});

test('a swipe hits everything it crosses once, and leaves fresh pieces alone', () => {
  const s = solo(1);
  s.bubbles.length = 0;
  const a = s.add(1, 80, 200, 0, 0), b = s.add(1, 200, 200, 0, 0), far = s.add(1, 200, 340, 0, 0);
  for (const x of [a, b, far]) { x.vx = 0; x.vy = 0; }
  const skip = new Set();
  assert.equal(s.slice(20, 200, 300, 200, skip), 2);
  assert.ok(!s.bubbles.includes(a) && !s.bubbles.includes(b) && s.bubbles.includes(far));
  assert.equal(s.slice(20, 200, 300, 200, skip), 0);
});

test('two players: a swipe stays on its own side', () => {
  const s = versus();
  s.bubbles.length = 0;
  const r = s.add(1, s.line() + 60, 200, 0, 0);
  assert.equal(s.slice(s.line() - 100, 200, s.line() + 100, 200, new Set()), 0);
  assert.ok(s.bubbles.includes(r));
});

test('popping a tiny bubble sets off the tiny bubbles close to it, and leaves the rest', () => {
  const s = solo(1);
  s.bubbles.length = 0;
  const a = s.add(3, 100, 200, 0, 0);
  s.add(3, 140, 200, 0, 0); s.add(3, 180, 200, 0, 0);
  const big = s.add(0, 200, 330, 0, 0), far = s.add(3, 320, 320, 0, 0);
  for (const b of s.bubbles) { b.vx = 0; b.vy = 0; }
  s.tap(a);
  assert.equal(s.players[0].taps, 1);
  assert.equal(s.players[0].chained, 2);
  assert.ok(s.bubbles.includes(big) && s.bubbles.includes(far));
  assert.equal(s.bubbles.length, 2);
});

test('a larger bubble on the hinge splits and costs the meter, streak and combo', () => {
  const s = solo(2);
  const p = s.players[0];
  p.streak = 5; p.combo = 3; p.comboT = 1;
  const before = s.bubbles.length;
  sendAcross(s, s.bubbles[0]);
  assert.equal(p.shields, CFG.shields - 1, 'a big bubble fills the meter by itself');
  assert.equal(p.meter, 0);
  assert.equal(p.crossings, 1);
  assert.equal(p.streak, 0);
  assert.equal(p.combo, 1);
  assert.equal(s.bubbles.length, before + 1);
});

test('the smallest bubble on the hinge only helps', () => {
  const s = solo(2);
  const p = s.players[0];
  p.streak = 5; p.combo = 3; p.comboT = 1; p.meter = 2;
  const b = s.bubbles[0];
  makeSmallest(b);
  sendAcross(s, b);
  assert.equal(p.meter, 2);
  assert.equal(p.crossings, 0);
  assert.equal(p.zaps, 1);
  assert.equal(p.streak, 5);
  assert.equal(p.combo, 3);
  assert.equal(p.score, CFG.points[3]);
  assert.equal(s.bubbles.length, 1);
});

test('grace time lets larger bubbles pass quietly, but the smallest still pops', () => {
  const s = solo(2);
  const [big, small] = s.bubbles;
  makeSmallest(small);
  for (const b of [big, small]) {
    b.vx = 0; b.vy = 0;
    b.y = s.line() - b.side * 1;
    b.vy = -b.side * 600;
    b.grace = 0.5;
  }
  s.step(1 / 60);
  assert.equal(s.players[0].crossings, 0);
  assert.equal(s.players[0].zaps, 1);
  assert.ok(s.bubbles.includes(big));
});

test('a hinge pop on the last bubble wins and keeps the no-crossing bonus', () => {
  const s = solo(1);
  makeSmallest(s.bubbles[0]);
  sendAcross(s, s.bubbles[0]);
  assert.equal(s.status, 'won');
  assert.equal(s.cleanBonus, true);
});

test('a full streak restores a shield, and clears the meter at full shields', () => {
  const s = solo(9);
  const p = s.players[0];
  p.shields = 2;
  for (const b of s.bubbles) { b.vx = 0; b.vy = 0; }
  for (let i = 0; i < CFG.rechargeStreak; i++) s.tap(s.bubbles[0]);
  assert.equal(p.shields, 3);
  assert.equal(p.recharges, 1);
  assert.equal(p.streak, 0);
  p.meter = 2;
  for (let i = 0; i < CFG.rechargeStreak; i++) s.tap(s.bubbles[0]);
  assert.equal(p.shields, 3);
  assert.equal(p.meter, 0);
});

test('filling the meter takes a shield, and the last shield ends the level', () => {
  const s = solo(6);
  const p = s.players[0];
  p.meter = CFG.meterMax - 1;
  s.bubbles[0].g = 2; s.bubbles[0].r = CFG.radii[2];
  sendAcross(s, s.bubbles[0]);
  assert.equal(p.shields, CFG.shields - 1);
  assert.equal(p.meter, 0);
  p.shields = 1; p.meter = CFG.meterMax - 1;
  s.bubbles[0].g = 2; s.bubbles[0].r = CFG.radii[2];
  sendAcross(s, s.bubbles.find((b) => b.g < 3));
  assert.equal(s.status, 'lost');
});

test('turning the device keeps every bubble on its side of the hinge, with no crossing', () => {
  const s = solo(6);
  s.tap(s.bubbles[0]);
  const sides = Array.from(s.bubbles, (b) => b.side).join();
  const speeds = Array.from(s.bubbles, (b) => Math.hypot(b.vx, b.vy));
  assert.equal(s.resize(760, 390, 70), true);
  assert.equal(s.vertical, true);
  assert.equal(Array.from(s.bubbles, (b) => b.side).join(), sides);
  // The bubbles shrink with the shorter arena, and their speed scales with them.
  const ratio = 0.85 / (390 / 400);
  s.bubbles.forEach((b, i) => assert.ok(Math.abs(Math.hypot(b.vx, b.vy) - speeds[i] * ratio) < 1e-6));
  s.bubbles.forEach((b) => assert.ok(b.x >= 0 && b.x <= s.w && b.y >= s.top && b.y <= s.h));
  s.step(1 / 120);
  assert.equal(s.players[0].crossings, 0);
  assert.equal(s.resize(800, 390, 70), false);
  assert.equal(s.resize(390, 760, 70), true);
  assert.equal(s.vertical, false);
});

// Two bubbles on the same side, about to touch, with everything else out of the way.
function pair(gA, gB, va = 100, vb = -100) {
  const s = solo(1);
  s.bubbles.length = 0;
  const a = s.add(gA, 100, 200, 0, 0), b = s.add(gB, 100 + CFG.radii[gA] * 0.85 + CFG.radii[gB] * 0.85 + 0.2, 200, 0, 0);
  a.vx = va; a.vy = 0; b.vx = vb; b.vy = 0;
  return { s, a, b };
}
const momentum = (a, b) => CFG.matter[a.g].mass * a.vx + CFG.matter[b.g].mass * b.vx;

test('every size has its own matter, heavier and less bouncy as it grows', () => {
  for (let g = 1; g < 4; g++) {
    assert.ok(CFG.matter[g].mass < CFG.matter[g - 1].mass);
    assert.ok(CFG.matter[g].bounce > CFG.matter[g - 1].bounce);
    assert.ok(CFG.matter[g].recover > CFG.matter[g - 1].recover);
  }
});

test('a collision conserves momentum and the lighter bubble takes the hit', () => {
  const { s, a, b } = pair(0, 3, 100, 0);
  CFG.matter.forEach((m) => { m.savedRecover = m.recover; m.recover = 0; });
  const before = momentum(a, b);
  const av = a.vx;
  s.step(1 / 120);
  CFG.matter.forEach((m) => { m.recover = m.savedRecover; delete m.savedRecover; });
  assert.ok(Math.abs(momentum(a, b) - before) < 1e-6);
  assert.ok(b.vx > 150, 'light bubble should fly: ' + b.vx);
  assert.ok(av - a.vx < 30, 'heavy bubble should barely slow: ' + (av - a.vx));
});

test('equal bubbles trade speed, and impacts squash both', () => {
  const { s, a, b } = pair(1, 1);
  s.step(1 / 120);
  assert.ok(a.vx < 0 && b.vx > 0);
  assert.ok(a.sq > 0 && b.sq > 0);
  for (let i = 0; i < 240; i++) { a.vx = -1; b.vx = 1; s.step(1 / 120); }
  assert.ok(a.sq < 0.01, 'squash should settle: ' + a.sq);
});

test('fresh pieces pass through each other, and the hinge keeps the sides apart', () => {
  const fresh = pair(1, 1);
  fresh.a.grace = 0.5;
  fresh.s.step(1 / 120);
  assert.equal(fresh.a.sq, 0);
  const across = pair(1, 1);
  across.b.side = -across.a.side;
  across.s.step(1 / 120);
  assert.ok(across.a.vx > 0, 'bubbles on opposite sides should not collide');
});

test('bubbles swim back to their own cruising speed, and stopped ones stay stopped', () => {
  const s = solo(6);
  s.bubbles.length = 0;
  // On opposite sides of the hinge, so they cannot touch.
  const slow = s.add(3, 100, 120, 0, 0), still = s.add(0, 200, 640, 0, 0);
  slow.vx = 10; slow.vy = 0; still.vx = 0; still.vy = 0;
  for (let i = 0; i < 180; i++) s.step(1 / 120);
  const cruise = CFG.speeds[3] * (390 / 400) * s.speedMul;
  assert.ok(Math.abs(Math.hypot(slow.vx, slow.vy) - cruise) < cruise * 0.1, 'speed ' + Math.hypot(slow.vx, slow.vy));
  assert.equal(still.vx, 0);
});

test('a bubble gliding parallel to the hinge is drawn back, so no level stalls', () => {
  const s = solo(1);
  s.bubbles.length = 0;
  const b = s.add(3, 60, 200, 0, 0);
  const startSide = b.side;
  for (let i = 0; i < 120 * 30 && s.bubbles.includes(b); i++) s.step(1 / 120);
  assert.equal(s.bubbles.includes(b), false, 'still gliding on side ' + startSide);
  assert.equal(s.players[0].zaps, 1);
});

test('a harder flick launches the pieces faster', () => {
  const launched = (len) => {
    const s = solo(6);
    for (const b of s.bubbles) { b.vx = 0; b.vy = 0; }
    const target = s.bubbles[0];
    s.tap(target, { x: len, y: 0 });
    const piece = s.bubbles[s.bubbles.length - 1];
    return Math.hypot(piece.vx, piece.vy);
  };
  assert.ok(launched(120) > launched(20) * 1.4);
});

test('the carried score starts the next level', () => {
  assert.equal(createSim({ w: 390, h: 760, top: 70, level: 3, score: 1234 }).players[0].score, 1234);
});

test('two players: the hinge is always vertical and the sides are mirrored', () => {
  for (const [w, h] of [[844, 390], [390, 844]]) {
    const s = createSim({ w, h, top: 65, versus: true });
    assert.equal(s.vertical, true);
    const left = s.bubbles.filter((b) => b.side < 0), right = s.bubbles.filter((b) => b.side > 0);
    assert.equal(left.length, CFG.versusPerSide);
    assert.equal(right.length, CFG.versusPerSide);
    left.forEach((b, i) => {
      assert.ok(Math.abs(b.x - (w - right[i].x)) < 1e-6);
      assert.ok(Math.abs(b.y - right[i].y) < 1e-6);
      assert.ok(Math.abs(b.vx + right[i].vx) < 1e-6);
      assert.ok(Math.abs(b.vy - right[i].vy) < 1e-6);
    });
  }
});

test('two players: a tap credits the side the bubble is on', () => {
  const s = versus();
  s.tap(s.bubbles.find((b) => b.side > 0));
  assert.deepEqual(Array.from(s.players, (p) => p.taps), [0, 1]);
  s.tap(s.bubbles.find((b) => b.side < 0));
  assert.deepEqual(Array.from(s.players, (p) => p.taps), [1, 1]);
});

test('two players: a touch cannot reach across the hinge', () => {
  const s = versus();
  const b = s.bubbles.find((x) => x.side > 0);
  b.x = s.line() + 4;
  assert.notEqual(s.hit(s.line() - 4, b.y), b);
  assert.equal(s.hit(s.line() + 8, b.y), b);
});

test('two players: a crossing costs the sender and lands on the other side', () => {
  const s = versus();
  const right = s.bubbles.filter((b) => b.side > 0).length;
  sendAcross(s, s.bubbles.find((b) => b.side < 0));
  assert.deepEqual(Array.from(s.players, (p) => p.shields), [CFG.shields - 1, CFG.shields]);
  assert.equal(s.bubbles.filter((b) => b.side > 0).length, right + 2);
});

test('two players: a free hinge pop credits the sender', () => {
  const s = versus();
  const b = s.bubbles.find((x) => x.side > 0);
  makeSmallest(b);
  sendAcross(s, b);
  assert.deepEqual(Array.from(s.players, (p) => p.zaps), [0, 1]);
  assert.deepEqual(Array.from(s.players, (p) => p.meter), [0, 0]);
  assert.equal(s.players[1].score, CFG.points[3]);
});

test('two players: losing the last shield hands the win to the other side', () => {
  const s = versus();
  s.players[1].shields = 1; s.players[1].meter = CFG.meterMax - 1;
  sendAcross(s, s.bubbles.find((b) => b.side > 0));
  assert.equal(s.status, 'ended');
  assert.equal(s.winner, 0);
});

test('two players: a cleared arena goes to the higher score, or a draw', () => {
  const finish = (leftScore, rightScore) => {
    const s = versus();
    const last = s.bubbles[0];
    makeSmallest(last);
    s.bubbles.splice(0, s.bubbles.length, last);
    s.players[0].score = leftScore - CFG.points[3];
    s.players[1].score = rightScore;
    s.tap(last);
    return s;
  };
  assert.equal(finish(900, 100).status, 'ended');
  assert.equal(finish(900, 100).winner, 0);
  assert.equal(finish(100, 900).winner, 1);
  assert.equal(finish(500, 500).winner, null);
});

// ---- Nobody wins by watching

test('no level can be won without touching the screen', () => {
  for (const n of [...Array(40).keys()].map((i) => i + 1)) {
    const s = createSim({ w: 390, h: 760, top: 70, level: n });
    while (s.status === 'playing' && s.t < 300) { s.step(1 / 30); s.events.length = 0; }
    assert.notEqual(s.status, 'won', 'level ' + n + ' cleared itself');
  }
});

test('heavier bubbles cost more to let through', () => {
  const s = solo(1);
  assert.deepEqual([0, 1, 2].map((g) => s.crossingCost(g)), [CFG.meterMax, 2, 1]);
});

test('busy levels arrive in stages and cannot be won early', () => {
  const s = solo(39);
  assert.ok(s.arrivals.length > 0);
  const waiting = s.arrivals.length;
  while (s.bubbles.length && s.status === 'playing' && s.arrivals.length === waiting) s.tap(s.bubbles[0]);
  assert.equal(s.status, 'playing');
  assert.ok(s.arrivals.length < waiting);
});

// ---- Guest stars

const meet = (s) => {
  while (!s.visitors.length && s.t < 40 && s.status === 'playing') {
    s.step(1 / 60);
    for (const p of s.players) { p.meter = 0; p.shields = CFG.shields; }
  }
  return s.visitors[0];
};

test('every guest comes around, and level one stays simple', () => {
  const seen = new Set();
  for (let n = 2; n <= 9; n++) { const v = meet(solo(n)); if (v) seen.add(v.cameo); }
  assert.equal(seen.size, CFG.cameos.length);
  assert.equal(meet(solo(1)), undefined);
});

test('two players get no guests, so nobody gets lucky', () => {
  assert.equal(meet(versus()), undefined);
});

test('catching a guest scores and gives its gift', () => {
  const s = solo(2);
  const v = s.summon('docFlux');
  s.players[0].meter = 3;
  const before = s.players[0].score;
  assert.ok(s.catchVisitor(v));
  assert.equal(s.visitors.length, 0);
  assert.ok(s.players[0].score > before);
  assert.equal(s.players[0].meter, 0);
  assert.equal(s.players[0].cameos, 1);
});

test('the Chosen Fizz dodges the first touch', () => {
  const s = solo(2);
  const v = s.summon('chosenFizz');
  s.catchVisitor(v);
  assert.equal(s.visitors.length, 1);
  s.catchVisitor(v);
  assert.equal(s.visitors.length, 0);
});

test('guests never block a clear, and they leave by themselves', () => {
  const s = solo(2);
  s.summon('captainFizz');
  let guard = 0;
  while (s.bubbles.length && s.status === 'playing' && guard++ < 500) s.tap(s.bubbles[0]);
  assert.equal(s.status, 'won');
  const t = solo(2);
  t.summon('captainFizz');
  for (let i = 0; i < 60 * 6; i++) { t.step(1 / 60); t.players[0].meter = 0; t.players[0].shields = CFG.shields; if (!t.visitors.length) break; }
  assert.equal(t.visitors.length, 0);
});

// ---- Snap the Hinge

test('a snap flings nearby bubbles away, then has to recharge', () => {
  const s = solo(1), b = s.bubbles[0];
  b.y = s.line() - 40; b.vx = 0; b.vy = 0;
  assert.ok(s.snap(100, 0));
  assert.ok(b.vy < -100);
  assert.equal(s.players[0].snaps, 1);
  assert.equal(s.snap(100, 0), false);
  s.players[0].snapLeft = 0.01;
  s.step(1 / 60);
  assert.ok(s.snap(100, 0));
});

test('tiny bubbles are left for the line, and lighter ones fly harder', () => {
  const s = solo(1), big = s.bubbles[0];
  const mid = s.add(2, 300, s.line() - 40, 0, 0), tiny = s.add(3, 200, s.line() - 40, 0, 0);
  big.y = s.line() - 40;
  for (const b of [big, mid, tiny]) { b.vx = 0; b.vy = 0; }
  s.snap(100, 0);
  assert.ok(Math.abs(mid.vy) > Math.abs(big.vy));
  assert.equal(tiny.vy, 0);
});

test('in two players a snap only moves your own side', () => {
  const s = versus();
  for (const b of s.bubbles) { b.vx = 0; b.vy = 0; b.x = s.line() + b.side * 30; }
  s.snap(200, 0);
  assert.ok(s.bubbles.filter((b) => b.side < 0).every((b) => b.vx < -100));
  assert.ok(s.bubbles.filter((b) => b.side > 0).every((b) => b.vx === 0));
});

