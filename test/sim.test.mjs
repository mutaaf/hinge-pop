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

test('levels start with one slow bubble and add one per level up to the cap', () => {
  assert.equal(levelConfig(1).count, 1);
  assert.equal(levelConfig(2).count, 2);
  assert.equal(levelConfig(4).count, 4);
  assert.equal(levelConfig(6).count, 6);
  assert.equal(levelConfig(40).count, 6);
  assert.ok(levelConfig(1).speed < levelConfig(2).speed);
  assert.ok(levelConfig(6).speed < levelConfig(10).speed);
  assert.equal(levelConfig(99).speed, CFG.maxSpeed);
  for (const n of [1, 2, 3, 4, 5, 6, 9]) assert.equal(solo(n).bubbles.length, levelConfig(n).count);
});

test('one large bubble takes 15 taps to clear and a clean clear earns the bonus', () => {
  const s = solo(1);
  let taps = 0;
  while (s.bubbles.length) { s.tap(s.bubbles[0]); taps++; }
  assert.equal(taps, 15);
  assert.equal(s.status, 'won');
  assert.equal(s.cleanBonus, true);
});

test('a larger bubble on the hinge splits and costs the meter, streak and combo', () => {
  const s = solo(2);
  const p = s.players[0];
  p.streak = 5; p.combo = 3; p.comboT = 1;
  const before = s.bubbles.length;
  sendAcross(s, s.bubbles[0]);
  assert.equal(p.meter, 1);
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
  const s = solo(6);
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
  sendAcross(s, s.bubbles[0]);
  assert.equal(p.shields, CFG.shields - 1);
  assert.equal(p.meter, 0);
  p.shields = 1; p.meter = CFG.meterMax - 1;
  sendAcross(s, s.bubbles.find((b) => b.g < 3));
  assert.equal(s.status, 'lost');
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
  assert.deepEqual(Array.from(s.players, (p) => p.meter), [1, 0]);
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
