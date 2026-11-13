// The portal builds (CrazyGames, GameDistribution; store/portals/SUBMIT.md): the index.html edits, what the zip may
// carry, the runtime's ad rules, gameplay events and saves, and that the live build carries none of it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { EDITS, FORBIDDEN, PORTALS, editGame, portalHtml } from '../scripts/portal-html.mjs';
import { artFiles, gate } from '../scripts/portal-build.mjs';
import { GD_GAME_ID, GD_GAME_ID_PLACEHOLDER, MIDGAME_GAP_MS } from '../portal/config.js';

const src = readFileSync('index.html', 'utf8');
const cfg = { gdGameId: GD_GAME_ID_PLACEHOLDER, gdPlaceholder: GD_GAME_ID_PLACEHOLDER, sdkWaitMs: 50, midgameGapMs: MIDGAME_GAP_MS };
const hingePopPortal = new Function(`${readFileSync('portal/runtime.js', 'utf8')}\nreturn hingePopPortal;`)();

test('the GameDistribution id ships as the placeholder', () => {
  assert.equal(GD_GAME_ID, GD_GAME_ID_PLACEHOLDER);
});

test('every edit to index.html applies exactly once', () => {
  const out = editGame(src);
  for (const [what, , to] of EDITS) if (to) assert.ok(out.includes(to), what);
});

test('an edit that no longer matches fails the build loudly', () => {
  assert.throws(() => editGame(src.replace("const ART = '../art/';", "const ART = './art/';")), /art path/);
});

for (const portal of PORTALS) {
  test(`${portal}: the page carries nothing forbidden, and the game is all there`, () => {
    const html = portalHtml(src, portal, cfg);
    for (const [re, what] of FORBIDDEN) assert.doesNotMatch(html, re, what);
    assert.ok(html.includes(`data-portal="${portal}"`));
    for (const id of ['id="stage"', 'id="panel"', 'id="tour"', 'id="duel"', 'id="hp-game"', '// SIM START', '// SIM END']) assert.ok(html.includes(id), id);
    assert.equal((html.match(/__hpPortal\./g) || []).length >= 8, true);
  });
}

test('the zip carries every art file the game names, and they exist', () => {
  const art = artFiles(src);
  assert.ok(art.includes('game-bubble.webp') && art.includes('logo.webp'));
  assert.ok(art.some((f) => f.startsWith('cameo-')) && art.some((f) => f.startsWith('arena-')));
  for (const f of art) assert.ok(existsSync(join('site/art', f)), f);
});

test('the live build has no portal code in it', () => {
  assert.ok(!src.includes('__hpPortal'));
  const out = mkdtempSync(join(tmpdir(), 'hp-live-'));
  try {
    execFileSync(process.execPath, ['scripts/build.mjs'], { env: { ...process.env, HINGEPOP_OUT: out }, stdio: 'pipe' });
    const game = readFileSync(join(out, 'hingepop/play/index.html'), 'utf8');
    assert.ok(!/__hpPortal|hingePopPortal|crazygames|gamedistribution/i.test(game));
    assert.ok(game.includes("const ART = '../art/';"));
    assert.ok(!readdirSync(join(out, 'hingepop')).includes('portal'));
  } finally { rmSync(out, { recursive: true, force: true }); }
});

test('the gate refuses links, the home address and store names', () => {
  const dir = mkdtempSync(join(tmpdir(), 'hp-gate-'));
  try {
    execFileSync('sh', ['-c', `printf '%s' '<a href="https://mutaafaziz.com/hingepop/">Get it on the App Store</a>' > "${dir}/index.html"`]);
    const { problems } = gate(dir, []);
    for (const what of ['mutaafaziz', 'a link', 'store name', '/hingepop/', 'outbound']) assert.ok(problems.some((p) => p.includes(what)), what);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

// --- The runtime, against stand-in SDKs ----------------------------------------------------------------------------
function memStorage() {
  const m = new Map();
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k), m };
}
function fakeCrazy({ environment = 'local', mute = false } = {}) {
  const log = [];
  const data = memStorage();
  const sdk = {
    environment,
    init: async () => {},
    game: { settings: { muteAudio: mute }, addSettingsChangeListener: () => {}, loadingStart: () => log.push('loadingStart'), loadingStop: () => log.push('loadingStop'), gameplayStart: () => log.push('start'), gameplayStop: () => log.push('stop') },
    ad: { requestAd: (type, cb) => { log.push(`ad:${type}`); cb.adStarted(); setTimeout(() => cb.adFinished(), 0); } },
    data,
  };
  return { sdk, log, data };
}
function env({ crazy, gd, clock } = {}) {
  const ls = memStorage();
  const body = { appended: [], appendChild(el) { this.appended.push(el); } };
  const doc = { body, addEventListener() {}, createElement: () => ({ setAttribute() {}, appendChild() {}, remove() { body.appended = []; } }) };
  const win = { localStorage: ls, CrazyGames: crazy ? { SDK: crazy.sdk } : undefined, gdsdk: gd };
  const t = clock || { now: 1_000_000 };
  return { win, doc, ls, t, now: () => t.now, load: async () => !!(crazy || gd) };
}

test('CrazyGames: no ad after the first game, one after the second, then none for 3 minutes', async () => {
  const crazy = fakeCrazy();
  const e = env({ crazy });
  const p = hingePopPortal({ ...cfg, portal: 'crazygames' }, e);
  assert.equal(await p.boot(), true);
  const audio = [];
  p.attach({ pauseAudio: () => audio.push('pause'), resumeAudio: () => audio.push('resume') });
  let went = 0;
  p.ran(); p.leave(() => went++);
  assert.equal(went, 1, 'the first result is left at once');
  p.ran();
  await new Promise((r) => p.leave(() => { went++; r(); }));
  assert.equal(went, 2);
  assert.deepEqual(crazy.log.filter((l) => l.startsWith('ad:')), ['ad:midgame']);
  assert.deepEqual(audio, ['pause', 'resume'], 'the game is muted for the ad and back after');
  p.ran(); e.t.now += MIDGAME_GAP_MS - 1; p.leave(() => went++);
  assert.equal(went, 3, 'inside 3 minutes: no ad');
  assert.equal(crazy.log.filter((l) => l.startsWith('ad:')).length, 1);
  e.t.now += 2;
  await new Promise((r) => p.leave(() => { went++; r(); }));
  assert.equal(crazy.log.filter((l) => l.startsWith('ad:')).length, 2, 'after 3 minutes: the next one');
});

test('CrazyGames: gameplay events only on a change, never during an ad, loading once', async () => {
  const crazy = fakeCrazy();
  const p = hingePopPortal({ ...cfg, portal: 'crazygames' }, env({ crazy }));
  await p.boot();
  for (const m of ['menu', 'tour', 'tour', 'play', 'play', 'held', 'play', 'paused', 'ended', 'menu']) p.sync(m);
  p.ready(); p.ready();
  assert.deepEqual(crazy.log, ['loadingStart', 'start', 'stop', 'start', 'stop', 'loadingStop']);
});

test('CrazyGames: saves go to the data module first, localStorage too; mute comes from the portal', async () => {
  const crazy = fakeCrazy({ mute: true });
  const e = env({ crazy });
  const p = hingePopPortal({ ...cfg, portal: 'crazygames' }, e);
  await p.boot();
  p.setItem('hinge-pop-prefs', '{"level":4}');
  assert.equal(crazy.data.getItem('hinge-pop-prefs'), '{"level":4}');
  assert.equal(e.ls.getItem('hinge-pop-prefs'), '{"level":4}');
  crazy.data.setItem('hinge-pop-prefs', '{"level":9}');   // a signed-in player's progress from another device wins
  assert.equal(p.getItem('hinge-pop-prefs'), '{"level":9}');
  assert.equal(p.muted(), true);
});

test('with the SDK blocked or on another domain: no ads, no events, saves in localStorage', async () => {
  for (const crazy of [null, fakeCrazy({ environment: 'disabled' })]) {
    const e = env({ crazy });
    const p = hingePopPortal({ ...cfg, portal: 'crazygames' }, e);
    assert.equal(await p.boot(), false);
    let went = 0;
    p.ran(); p.ran(); p.leave(() => went++);
    assert.equal(went, 1);
    p.sync('play');
    assert.equal(p.playing, true);   // its own record only; nothing reaches an SDK
    if (crazy) assert.deepEqual(crazy.log, []);
    p.setItem('hinge-pop-prefs', '{"level":2}');
    assert.equal(e.ls.getItem('hinge-pop-prefs'), '{"level":2}');
    assert.equal(p.muted(), false);
  }
});

test('GameDistribution: no SDK until the game id is pasted; with one, a midgame through showAd', async () => {
  const shown = [];
  const gd = { showAd: async (t) => { shown.push(t || 'midgame'); } };
  const e = env({ gd });
  e.load = async () => { setTimeout(() => e.win.GD_OPTIONS.onEvent({ name: 'SDK_READY' }), 0); return true; };
  const none = hingePopPortal({ ...cfg, portal: 'gamedistribution' }, e);
  assert.equal(await none.boot(), false);
  const p = hingePopPortal({ ...cfg, portal: 'gamedistribution', gdGameId: 'abc123' }, e);
  assert.equal(await p.boot(), true);
  assert.equal(e.win.GD_OPTIONS.advertisementSettings.autoplay, false, 'no pre-roll');
  p.ran(); p.ran();
  await new Promise((r) => p.leave(r));
  assert.deepEqual(shown, ['midgame']);
});

test('an SDK that throws never reaches the game', async () => {
  const crazy = fakeCrazy();
  crazy.sdk.ad.requestAd = () => { throw new Error('boom'); };
  crazy.sdk.game.gameplayStart = () => { throw new Error('boom'); };
  crazy.data.setItem = () => { throw new Error('full'); };
  const e = env({ crazy });
  const p = hingePopPortal({ ...cfg, portal: 'crazygames' }, e);
  await p.boot();
  p.sync('play');
  p.ran(); p.ran();
  await new Promise((r) => p.leave(r));
  p.setItem('hinge-pop-prefs', '{}');
  assert.equal(e.ls.getItem('hinge-pop-prefs'), '{}');
});
