// The portal build's index.html (store/portals/SUBMIT.md), made from the game's own index.html at build time. The
// game's source is never edited for a portal: every change below is an exact text edit that must match once, so the
// build fails loudly if index.html drifts from what it expects. The live build (scripts/build.mjs) never runs this.
//
// What changes on a portal:
// - art and fonts sit beside index.html (art/, fonts/), not one folder up;
// - no analytics: track() does nothing (GameDistribution 2.6.8 bans tracking; the portals bring their own);
// - no landing-page embedding (no postMessage to a parent);
// - a device name in a settings tip is dropped (the portals' terms on third-party trademarks);
// - saves go through the portal (CrazyGames' data module, localStorage as the fallback);
// - the game tells the portal when play starts and stops, when a game ends and when its result is left (the one
//   place a midgame ad may show), and the portal's mute setting silences the game's blips;
// - the game script runs only once the portal's SDK is up or has failed (portal/runtime.js boot()).
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
export const PORTALS = ['crazygames', 'gamedistribution'];

// [what it is, exact text in index.html, replacement]. Each must occur exactly once.
export const EDITS = [
  ['font paths', 'url("../fonts/titan-one.woff2")', 'url("fonts/titan-one.woff2")'],
  ['font paths', 'url("../fonts/fredoka.woff2")', 'url("fonts/fredoka.woff2")'],
  ['art path', "const ART = '../art/';", "const ART = 'art/';"],
  ['no embedding', "  // ---- Embedding. /hingepop/ carries this page in a frame at the end of its scroll. The landing page says when\n  // the game is fully in view, and until then nothing here runs, moves or makes a sound.\n  //   ?embed=scroll  shows the arena and starts playing when told to\n  //   ?embed=static  shows the normal menu, for visitors who asked for reduced motion\n  const embed = new URLSearchParams(location.search).get('embed');",
    '  // ---- Embedding: never on a portal.\n  const embed = null;'],
  ['no analytics', "  // Box Office usage analytics (mutaaf/box-office): queue-safe, a no-op without the loader, never throws. Framed in\n  // the landing page, events go to the landing page's loader (this page loads none there, so a visit counts once).\n  // Props are numbers and enums only.\n  function track(name, props) {\n    try {\n      const w = window.parent !== window ? window.parent : window;\n      (w.boxoffice ??= { q: [], track(...a) { this.q.push(a); } }).track(name, props);\n    } catch (e) { /* analytics never breaks the game */ }\n  }",
    '  // No analytics on a portal.\n  function track() {}'],
  ['wake lock only where allowed', "    try { if (navigator.wakeLock && !wake) wake = await navigator.wakeLock.request('screen'); }",
    "    // A portal's frame may not allow it (a console warning each time): ask only when its permissions policy says yes.\n    const policy = document.permissionsPolicy || document.featurePolicy;\n    if (policy && policy.allowsFeature && !policy.allowsFeature('screen-wake-lock')) return;\n    try { if (navigator.wakeLock && !wake) wake = await navigator.wakeLock.request('screen'); }"],
  ['no device names', ' On iPhone and iPad, the ring/silent switch can also mute them.', ''],
  ['saves (read)', 'try { return JSON.parse(localStorage.getItem(STORE) || \'{}\'); }', 'try { return JSON.parse(__hpPortal.getItem(STORE) || \'{}\'); }'],
  ['saves (write)', 'localStorage.setItem(STORE, JSON.stringify(', '__hpPortal.setItem(STORE, JSON.stringify('],
  ['portal mute', "    if (!audio || !$('optSound').checked) return;", "    if (!audio || !$('optSound').checked || __hpPortal.muted()) return;"],
  ['game over', "  function finish() {\n    mode = 'ended';", "  function finish() {\n    mode = 'ended';\n    __hpPortal.ran();"],
  ['leaving a result', '      btn.addEventListener(\'click\', a.run);', "      btn.addEventListener('click', mode === 'ended' ? () => __hpPortal.leave(a.run) : a.run);"],
  ['leaving a duel', "  for (const id of ['rematch', 'rematch2']) $(id).addEventListener('click', () => playVersus());\n  for (const id of ['duelMenu', 'duelMenu2']) $(id).addEventListener('click', () => menu());",
    "  for (const id of ['rematch', 'rematch2']) $(id).addEventListener('click', () => __hpPortal.leave(() => playVersus()));\n  for (const id of ['duelMenu', 'duelMenu2']) $(id).addEventListener('click', () => __hpPortal.leave(() => menu()));"],
  ['gameplay events', '  function frame(now) {\n    if (!looping) return;', "  function frame(now) {\n    if (!looping) return;\n    __hpPortal.sync(held ? 'held' : mode);"],
  ['game hooks', '  window.hingePop = {',
    "  __hpPortal.attach({\n    pauseGame: () => pause(),\n    pauseAudio: () => { if (audio && audio.state === 'running') audio.suspend(); },\n    resumeAudio: () => { if (audio && audio.state === 'suspended') audio.resume(); },\n  });\n  window.hingePop = {"],
  // No guest stars on a portal: several wink at famous films and characters (the portals' terms on third-party
  // trademarks and likeness). Guests never block a clear, never touch the meter and earn nothing that's kept, so the
  // levels play the same without them; two players never had them.
  ['no guests (list)', "  // Guest stars wander through, ignore the hinge and leave a gift if you catch them.\n  cameos: ['captainFizz', 'docFlux', 'sirGlowstick', 'chosenFizz', 'merlinFizz', 'bigBurp', 'booBubble', 'discoDot'],",
    '  // No guests in this version.\n  cameos: [],'],
  ['no guests (catch note)', '  // A touch on a guest. The Chosen Fizz sees the first one coming.', '  // A touch on a guest (none in this version).'],
  ['no guests (How to play)', '          <details class="fold" name="learn"><summary>Guest stars</summary><div class="guests" id="guestList"></div></details>\n', ''],
  ['no guests (tour)', "body: 'Catch any guest stars who drop by. Tap anything up top for details.',", "body: 'Tap anything up top for details.',"],
  ['no guests (styles)', '.guests { display: grid;', '.unused-guests { display: grid;'],
];

// Ranges cut out whole: [what, start text, end text (kept), replacement]. Each anchor must occur exactly once.
export const CUTS = [
  ['no guests (gifts)', '  function gift(v) {', '  const onHinge = ', '  function gift() {}\n'],
  ['no guests (spawning and moves)', '  function spawnVisitor(cameo) {', '  // Squash is plain data for the renderer',
    '  function spawnVisitor() { return null; }\n  function summon() { return null; }\n  function stepVisitors() {}\n\n'],
  ['no guests (arrivals and catches)', "      if (e.type === 'cameoArrive') {", "      if (e.type === 'split' || e.type === 'pop') {", ''],
  ['no guests (list in How to play)', '      const met = new Set(readStore().cameos || []);', "    $('settings').hidden = !o.toggles;", '    }\n'],
  ['no guests (art and drawing)', '  // Guests use the same art as the app.', '  // Which way each bubble faces, kept beside the rules.', '  function drawVisitors() {}\n\n'],
];

// Nothing a portal build may carry, in any text file of it (scripts/portal-build.mjs checks every file).
export const FORBIDDEN = [
  [/captain ?fizz|doc ?flux|sir ?glowstick|chosen ?fizz|merlin ?fizz|big ?burp|boo ?bubble|disco ?dot|guest stars?|cameo-/i, 'a guest star'],
  [/mutaafaziz/i, 'the mutaafaziz.com address'],
  [/box ?office/i, 'Box Office analytics'],
  [/\/ads\/v1|marquee/i, 'Marquee ads'],
  [/\/hingepop/, 'a /hingepop/ path'],
  [/(?:src|href)=["']?\/(?!\/)|url\(["']?\/(?!\/)/, 'a root-absolute path'],
  [/\.\.\//, 'a path above the game folder'],
  [/serviceWorker|beforeinstallprompt|manifest\.webmanifest/, 'a service worker or install prompt'],
  [/requestFullscreen/, 'an in-game fullscreen button'],
  [/<a\s/i, 'a link'],
  [/\b(?:iPhone|iPad|App Store|TestFlight|Apple|Android|Google Play|Microsoft|Surface|Duo|Samsung|Galaxy)\b/, 'a third-party device or store name'],
  [/https?:\/\/(?!sdk\.crazygames\.com\/|html5\.api\.gamedistribution\.com\/|scripts\.sil\.org\/OFL|www\.w3\.org\/)[^\s"'`)]+/, 'an outbound address'],
];

const PORTAL_CSS = `.hp-portal-busy { position: fixed; inset: 0; z-index: 1000; display: grid; place-items: center; background: rgba(20, 10, 46, .72); }
.hp-portal-busy i { width: 40px; height: 40px; border-radius: 50%; border: 4px solid rgba(247, 245, 255, .25); border-top-color: #4fd8ff; animation: hp-spin .8s linear infinite; }
@keyframes hp-spin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) { .hp-portal-busy i { animation-duration: 3s; } }`;

/** Applies EDITS to the game's index.html source; throws naming the edit that no longer matches once. */
export function editGame(src) {
  let out = src;
  for (const [what, from, to] of EDITS) {
    const n = out.split(from).length - 1;
    if (n !== 1) throw new Error(`portal edit "${what}": expected its text once in index.html, found ${n}. Update scripts/portal-html.mjs.`);
    out = out.replace(from, () => to);
  }
  for (const [what, start, end, to] of CUTS) {
    const a = out.split(start).length - 1, b = out.split(end).length - 1;
    if (a !== 1 || b !== 1) throw new Error(`portal cut "${what}": expected its start and end once in index.html, found ${a} and ${b}. Update scripts/portal-html.mjs.`);
    const i = out.indexOf(start), j = out.indexOf(end);
    if (j < i) throw new Error(`portal cut "${what}": its end comes before its start`);
    out = out.slice(0, i) + to + out.slice(j);
  }
  return out;
}

/** The whole portal index.html for one portal, from index.html's source and portal/config.js's values. */
export function portalHtml(src, portal, cfg) {
  if (!PORTALS.includes(portal)) throw new Error(`unknown portal ${portal}`);
  const edited = editGame(src);
  const split = edited.indexOf('<div id="stage">');
  const scriptAt = edited.indexOf('<script>');
  const scriptEnd = edited.lastIndexOf('</script>');
  if (split < 0 || scriptAt < split || scriptEnd < scriptAt) throw new Error('index.html: could not find the stage element and the game script');
  const head = edited.slice(0, split).trim();
  const body = edited.slice(split, scriptAt).trim();
  const game = edited.slice(scriptAt + '<script>'.length, scriptEnd);
  if (game.includes('</script')) throw new Error('index.html: the game script must be the only script');
  const runtime = readFileSync(join(ROOT, 'portal/runtime.js'), 'utf8');
  const config = JSON.stringify({ portal, gdGameId: cfg.gdGameId, gdPlaceholder: cfg.gdPlaceholder, sdkWaitMs: cfg.sdkWaitMs, midgameGapMs: cfg.midgameGapMs });
  // The game is held as text and run as a classic script once boot() is done, so its saves are read through the
  // portal's data module and its top-level names stay global, exactly as on the web.
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="description" content="Split bubbles and keep them off the hinge. Snap the hinge to fling them back. Endless levels and a two-player mode on one screen.">
<meta name="theme-color" content="#140a2e">
${head}
<style>${PORTAL_CSS}</style>
</head>
<body data-portal="${portal}">
${body}
<script type="text/plain" id="hp-game">${game}</script>
<script>
${runtime}
window.__hpPortal = hingePopPortal(${config});
window.__hpPortal.boot().then(() => {
  const s = document.createElement('script');
  s.textContent = document.getElementById('hp-game').textContent;
  document.body.appendChild(s);
  const done = () => window.__hpPortal.ready();
  (document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve()).then(() => requestAnimationFrame(done), done);
});
</script>
</body>
</html>
`;
}
