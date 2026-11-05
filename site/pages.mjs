// The site's pages as plain template functions. scripts/build.mjs writes them to dist/.
// All visible copy lives here. House rules: plain words, no em-dashes, and no claim the game can't back up.
// Facts come from the code: ios/Packages/HingePopCore (Levels, Tuning) and ios/HingePop/Theme.swift.

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
const ORIGIN = 'https://mutaafaziz.com/hingepop/';
const ISSUES = 'https://github.com/mutaaf/hinge-pop/issues';
export const ICON = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%23140a2e'/%3E%3Cpath d='M0 32h64' stroke='%234fd8ff' stroke-width='4'/%3E%3Ccircle cx='24' cy='19' r='10' fill='%2330b6ff'/%3E%3Ccircle cx='43' cy='45' r='7' fill='%23ffc733'/%3E%3C/svg%3E";

export function linkState(url, soon, ready) {
  if (url === null || url === undefined || url === '') return { ready: false, label: soon };
  if (!/^https:\/\//.test(url)) throw new Error('site/links.json: expected an https URL or null, got ' + url);
  return { ready: true, label: ready, url };
}
// With no URL yet the button is plain text with no link, so there's nothing to tap or tab to.
function storeButton(state, cls, id) {
  if (!state.ready) return `<span class="btn off ${cls}" id="${id}" aria-disabled="true">${esc(state.label)}</span>`;
  return `<a class="btn ${cls}" id="${id}" href="${esc(state.url)}" rel="noopener">${esc(state.label)}</a>`;
}

const head = ({ title, description, path, root, css, extra = '', image = 'art/og.jpg' }) => `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${esc(title)}</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="${esc(description)}">
<meta name="theme-color" content="#140a2e">
<meta name="color-scheme" content="dark">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Hinge Pop">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${ORIGIN}${path}">
<meta property="og:image" content="${ORIGIN}${image}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="The Hinge Pop logo over a violet arena, with cartoon bubbles on both sides of a glowing line.">
<meta name="twitter:card" content="summary_large_image">
<link rel="canonical" href="${ORIGIN}${path}">
<link rel="icon" href="${ICON}">
<link rel="preload" href="${root}fonts/titan-one.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="${root}fonts/fredoka.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="${root}assets/site.css">
${css ? `<link rel="stylesheet" href="${root}assets/${css}">` : ''}
${extra}</head>`;

// A heading in the logo's sticker style. The outline is a copy of the text behind it, kept out of the reading order by CSS.
const stk = (tag, text, cls = '', attrs = '') => `<${tag} class="stk ${cls}" data-t="${esc(text)}" ${attrs}>${esc(text)}</${tag}>`;

// A moving decoration. --d is how far it runs either side of its resting place: plus runs ahead of the scroll
// (near), minus lags behind it (far). Decorations are aria-hidden and hidden entirely when far off screen.
const art = (src, w, style, cls = '', eager = false) => `<div class="l art ${cls}" style="${style}" aria-hidden="true"><img src="art/${src}.webp" alt="" width="${w}" height="${w}" decoding="async"${eager ? '' : ' loading="lazy"'}></div>`;
const bob = (src, w, style, cls = '', eager = false) => art(src, w, style, cls + ' bobs', eager);

// Small repeatable scatter, seeded so builds are stable and sections differ.
function sparkles(n, seed) {
  let x = seed * 9301 + 49297, out = '';
  const r = () => (x = (x * 9301 + 49297) % 233280) / 233280;
  for (let i = 0; i < n; i++) {
    const size = Math.round(14 + r() * 30), d = Math.round((r() * 2 - 0.6) * 26);
    out += `<div class="l art spark" style="left:${Math.round(r() * 96)}%;top:${Math.round(r() * 94)}%;--d:${d}vh;width:${size}px;height:${size}px" aria-hidden="true"><i style="animation-delay:-${(r() * 5).toFixed(1)}s"></i></div>`;
  }
  return out;
}
function backdrop(arena, style = '--d:-10vh', cls = '', eager = false) {
  return `<div class="back ${cls}" aria-hidden="true"><div class="l arena" style="${style}"><picture><source media="(min-aspect-ratio: 1/1)" srcset="art/arena-${arena}-wide.webp"><img src="art/arena-${arena}-tall.webp" alt="" width="800" height="1400" decoding="async"${eager ? ' fetchpriority="high"' : ' loading="lazy"'}></picture></div></div>`;
}
// The hinge as artwork: three strokes standing in for a blur, so moving it costs nothing to repaint.
const JAG = 'M0 20 L60 14 L110 25 L180 12 L240 27 L310 15 L370 24 L440 11 L500 28 L560 14 L630 25 L690 12 L760 27 L830 15 L890 24 L950 13 L1000 20';
const JAGV = JAG.replace(/(\d+) (\d+)/g, '$2 $1');
const strokes = (d) => `<path d="${d}" stroke="#4fd8ff" stroke-opacity=".22" stroke-width="16"/><path d="${d}" stroke="#4fd8ff" stroke-opacity=".6" stroke-width="7"/><path d="${d}" stroke="#eafcff" stroke-width="2.5"/>`;
const bolt = (cls = '') => `<svg class="bolt ${cls}" viewBox="0 0 1000 40" preserveAspectRatio="none" fill="none" stroke-linejoin="round" vector-effect="non-scaling-stroke" aria-hidden="true">${strokes(JAG)}</svg>`;
const boltV = (cls = '') => `<svg class="bolt-v ${cls}" viewBox="0 0 40 1000" preserveAspectRatio="none" fill="none" stroke-linejoin="round" aria-hidden="true">${strokes(JAGV)}</svg>`;

const CAST = [
  ['basic', 'Basic', 'Splits in two on every tap, down to the smallest size, which pops for good.', 'cy'],
  ['fast', 'Fast', 'Half again as quick, and its pieces stay fast.', 'ho'],
  ['armored', 'Armored', 'Its helmet takes the first hit. The next tap splits it.', 'si'],
  ['magnetic', 'Magnetic', 'Pulls nearby bubbles toward it and bunches them up.', 'ro'],
  ['repel', 'Repel', 'Pushes nearby bubbles away, sometimes right at the hinge.', 'gr'],
  ['golden', 'Golden', 'Worth 5 times the points. Grab it while your combo is high.', 'go'],
  ['frozen', 'Frozen', 'Slow and heavy. It gives you time, but it is hard to knock off course.', 'ic'],
  ['boss', 'Boss', 'Too big to cross. Each slam charges your meter, and each phase gets faster.', 'ro'],
];
const POWERS = [
  ['overcharge', 'Overcharge', 'Double points for 8 seconds. The risk: a crossing charges your meter twice.'],
  ['freeze', 'Freeze', 'Slows every bubble to about a third of its speed for 3 seconds.'],
  ['focus', 'Focus', 'For 4 seconds the smallest bubbles pop by themselves, then small ones split.'],
  ['shield', 'Shield', 'Gives back one shield, up to 3.'],
  ['chainBurst', 'Chain Burst', 'Pops or splits every bubble around it, right away.'],
];
const CHAPTERS = [
  ['1', 'First Contact', 'Levels 1 to 10', 'Pop and split, then faster bubbles.', 'classic'],
  ['2', 'Electric Playground', 'Levels 11 to 20', 'Armored bubbles and a touchier hinge.', 'neon'],
  ['3', 'Magnetic Storm', 'Levels 21 to 30', 'Magnetic and repel bubbles move everything around them.', 'forest'],
  ['4', 'Overload Protocol', 'Levels 31 to 40', 'Moving gates and mixed bubbles.', 'space'],
  ['5', 'Bosses & Beyond', 'Levels 41 to 50', 'Boss patterns and combos.', 'neon'],
];

export function landing(links) {
  const testflight = linkState(links.testflight, 'Coming to TestFlight soon', 'Try it on TestFlight');
  const appStore = linkState(links.appStore, 'Coming to the App Store soon', 'Get it on the App Store');
  const description = 'Pop, split, chain, clear. An arcade game about keeping bubbles off an electric hinge. Scroll down this page and you are playing. Coming to iPhone Duo, iPad and iPhone.';
  return `${head({
    title: 'Hinge Pop: pop, split, chain, clear',
    description,
    path: '',
    root: '',
    css: 'landing.css',
    extra: `<link rel="preload" href="art/logo.webp" as="image" fetchpriority="high">
<script>
// Runs before first paint: tells the CSS that scripts are on, and which parallax driver to use.
(function (r, q) {
  r.className += ' js';
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) r.className += ' calm';
  else if (q.indexOf('parallax=js') > -1 || !(window.CSS && CSS.supports && CSS.supports('animation-timeline: view()'))) r.className += ' js-par';
})(document.documentElement, location.search);
</script>
<script defer src="vendor/aurora-field.min.js"></script>
<script defer src="assets/landing.js"></script>
`,
  })}
<body>
<a class="skip" href="#play">Skip to the game</a>
<div id="sky" aria-hidden="true">
  <div class="curtain" data-tint="classic"><canvas width="480" height="260"></canvas></div>
  <div class="curtain" data-tint="neon"><canvas width="480" height="260"></canvas></div>
  <div class="curtain" data-tint="forest"><canvas width="480" height="260"></canvas></div>
  <div class="curtain" data-tint="space"><canvas width="480" height="260"></canvas></div>
</div>
<div id="field-box" aria-hidden="true"><canvas id="field"></canvas></div>

<main>
<section class="sec hero" data-shape="logo" aria-label="Hinge Pop">
  ${backdrop('neon', '--d:-16vh', 'to-night', true)}
  ${sparkles(9, 3)}
  ${bob('bubble-basic', 384, 'left:-7%;top:16%;width:clamp(96px,26vw,240px);--d:34vh;--r0:-12deg;--r1:18deg', '', true)}
  ${bob('bubble-golden', 384, 'right:-4%;top:70%;width:clamp(84px,20vw,190px);--d:60vh;--r0:14deg;--r1:-20deg', '', true)}
  ${bob('bubble-fast', 384, 'right:12%;top:7%;width:clamp(44px,9vw,88px);--d:-6vh', '', true)}
  <div class="front hero-in">
    <h1 class="l hero-logo" style="--d:26vh"><img src="art/logo.webp" alt="Hinge Pop" width="1000" height="860" fetchpriority="high"></h1>
    <p class="tag"><span class="l" style="--d:12vh">POP</span><i>·</i><span class="l" style="--d:22vh">SPLIT</span><i>·</i><span class="l" style="--d:16vh">CHAIN</span><i>·</i><span class="l" style="--d:30vh">CLEAR</span></p>
    <p class="lede l" style="--d:8vh">One finger, one electric line, and a lot of bubbles that want to cross it.</p>
    <p class="cue l" style="--d:4vh"><a href="#play" data-jump>Keep scrolling. The game is at the end of this page.</a></p>
  </div>
</section>

<section class="sec hinge" data-shape="hinge" aria-labelledby="h-hinge">
  ${sparkles(5, 11)}
  ${bob('bubble-basic', 384, 'left:60%;top:8%;width:clamp(90px,22vw,200px);--y0:-30vh;--y1:30vh;--r1:30deg')}
  <div class="hinge-pin" aria-hidden="true"><div class="l art hinge-line" style="--x0:-200vw;--x1:0vw">${bolt()}</div></div>
  ${bob('bubble-basic', 384, 'left:62%;top:64%;width:clamp(50px,12vw,110px);--x0:0vw;--x1:-22vw;--y0:-34vh;--y1:22vh')}
  ${bob('bubble-basic', 384, 'left:72%;top:66%;width:clamp(50px,12vw,110px);--x0:0vw;--x1:20vw;--y0:-34vh;--y1:30vh')}
  <div class="front hinge-in">
    ${stk('h2', 'The hinge', 'cy l', 'id="h-hinge" style="--d:14vh"')}
    <p class="big l" style="--d:6vh">An electric line runs through every arena.</p>
    <p class="l" style="--d:3vh">A big bubble that crosses it splits for free, but the crossing charges your overload meter. Fill the meter and you lose a shield. Lose all three and the level starts over.</p>
    <p class="l" style="--d:9vh">The smallest bubbles are the exception. They pop on the hinge at no cost.</p>
  </div>
</section>

<section class="sec moves" aria-labelledby="h-moves">
  ${sparkles(6, 23)}
  <div class="front blk moves-title">${stk('h2', 'Three moves', 'go l', 'id="h-moves" style="--d:10vh"')}</div>
  <div class="own move m1" data-shape="burst">
    <div class="l o art" style="--x0:-40vw;--r0:-40deg" aria-hidden="true"><img class="move-art" src="art/bubble-basic.webp" alt="" width="384" height="384" loading="lazy"></div>
    <div class="front l o" style="--x0:30vw"><h3 class="word">Tap</h3><p>Touch a bubble and it splits into two smaller ones. Tap the smallest and it pops for good.</p></div>
  </div>
  <div class="own move m2" data-shape="slice">
    <div class="l o art slash" style="--x0:-120%;--y0:40%" aria-hidden="true">${bolt()}</div>
    <div class="front l o" style="--x0:-30vw"><h3 class="word">Swipe to slice</h3><p>One stroke hits every bubble it crosses, and the pieces fly the way you swiped.</p></div>
    <div class="l o art" style="--x0:40vw;--y0:-12vh" aria-hidden="true"><img class="move-art small" src="art/bubble-fast.webp" alt="" width="384" height="384" loading="lazy"></div>
  </div>
  <div class="own move m3" data-shape="chain">
    <div class="chain-art" aria-hidden="true">
      <div class="l o art" style="--x0:-30vw;--y0:20vh"><img src="art/bubble-basic.webp" alt="" width="384" height="384" loading="lazy"></div>
      <div class="l o art" style="--x0:-10vw;--y0:40vh"><img src="art/bubble-basic.webp" alt="" width="384" height="384" loading="lazy"></div>
      <div class="l o art" style="--x0:10vw;--y0:28vh"><img src="art/bubble-basic.webp" alt="" width="384" height="384" loading="lazy"></div>
      <div class="l o art" style="--x0:30vw;--y0:50vh"><img src="art/burst.webp" alt="" width="240" height="240" loading="lazy"></div>
    </div>
    <div class="front l o" style="--y0:8vh"><h3 class="word">Chain pops</h3><p>Pop one tiny bubble and every tiny bubble close to it goes too. Each link pays more.</p></div>
  </div>
</section>

<section class="sec cast" data-shape="bubble" aria-labelledby="h-cast">
  ${sparkles(10, 41)}
  <div class="front blk cast-title">
    ${stk('h2', 'The cast', 'ro l', 'id="h-cast" style="--d:9vh"')}
    <p class="big l" style="--d:5vh">Eight bubbles, one power each.</p>
    <p class="note l" style="--d:3vh">All eight live in the app. The web game at the end of this page has only Basic.</p>
  </div>
  ${CAST.map(([id, name, line, tone], i) => {
    const side = i % 2 ? 1 : -1;
    // Each actor has its own depth: how far it flies from, how big it arrives, how hard it spins.
    const depth = [0.6, 1.3, 0.8, 1.1, 0.5, 1.4, 0.7, 1.6][i];
    return `<article class="own actor ${i % 2 ? 'alt' : ''} ${id}">
    <div class="l o art fly" style="--x0:${Math.round(side * 70 * depth)}vw;--y0:${Math.round(30 * depth)}vh;--r0:${Math.round(side * 70 * depth)}deg;--s0:${(0.45 + depth * 0.5).toFixed(2)}" aria-hidden="true"><img class="bobber" src="art/bubble-${id}.webp" alt="" width="384" height="384" loading="lazy" style="animation-delay:-${i * 0.7}s"></div>
    <div class="front l o say" style="--x0:${Math.round(-side * 8)}vw;--y0:${Math.round(6 * depth)}vh">${stk('h3', name, tone)}<p>${esc(line)}</p></div>
  </article>`;
  }).join('\n  ')}
</section>

<section class="sec powers" data-shape="star" aria-labelledby="h-powers">
  ${sparkles(8, 57)}
  <div class="front blk powers-title">
    ${stk('h2', 'Power-ups', 'go l', 'id="h-powers" style="--d:10vh"')}
    <p class="big l" style="--d:4vh">Popping bubbles sometimes drops one. Tap it before it fades.</p>
    <p class="note l" style="--d:2vh">Power-ups are in the app only.</p>
  </div>
  <div class="power-field">
  ${POWERS.map(([id, name, line], i) => `<article class="own power p${i}">
    <div class="l o art" style="--x0:${i % 2 ? 44 : -44}vw;--y0:${18 + i * 8}vh;--r0:${i % 2 ? 300 : -300}deg;--s0:.4" aria-hidden="true"><img src="art/power-${id}.webp" alt="" width="240" height="240" loading="lazy"></div>
    <div class="front l o" style="--y0:${5 + i}vh"><h3>${esc(name)}</h3><p>${esc(line)}</p></div>
  </article>`).join('\n  ')}
  </div>
</section>

<section class="sec chapters" aria-labelledby="h-chapters">
  <div class="front blk chapters-title">
    ${stk('h2', 'Five chapters, then Infinity', 'cy l', 'id="h-chapters" style="--d:9vh"')}
    <p class="big l" style="--d:5vh">Fifty levels by hand, and every chapter ends on a boss. After that the levels keep climbing.</p>
    <p class="note l" style="--d:3vh">Chapters are in the app. The web game has its own endless run of basic-bubble levels.</p>
  </div>
  ${CHAPTERS.map(([n, title, levels, teaches, arena]) => `<article class="blk chapter" data-shape="num${n}" data-tint="${arena}">
    ${backdrop(arena, '--d:-14vh', 'soft')}
    <div class="front ch-in">
      <span class="numeral l" style="--d:34vh" aria-hidden="true">${n}</span>
      <div class="l" style="--d:8vh"><p class="ch-levels">${levels}</p>${stk('h3', title, 'si')}<p>${esc(teaches)}</p></div>
    </div>
  </article>`).join('\n  ')}
  <article class="blk chapter infinity" data-shape="infinity" data-tint="space">
    ${backdrop('space', '--d:-14vh', 'soft')}
    <div class="front ch-in">
      <span class="numeral l" style="--d:34vh" aria-hidden="true">∞</span>
      <div class="l" style="--d:8vh"><p class="ch-levels">Level 51 and up</p>${stk('h3', 'Infinity', 'go')}<p>Generated levels that keep climbing. The same number always gives the same level.</p></div>
    </div>
  </article>
</section>

<section class="sec two" data-shape="two" data-tint="classic" aria-labelledby="h-two">
  ${sparkles(5, 71)}
  <div class="l art two-line" style="--y0:-66.6%;--y1:0%" aria-hidden="true">${boltV()}</div>
  <div class="two-words" aria-hidden="true">
    <span class="l w-left" style="--x0:-30vw;--x1:6vw">LEFT</span>
    <span class="l w-right" style="--x0:30vw;--x1:-6vw">RIGHT</span>
  </div>
  ${bob('bubble-basic', 384, 'left:6%;top:30%;width:clamp(70px,20vw,190px);--d:30vh;--x0:-16vw;--x1:10vw')}
  ${bob('bubble-golden', 384, 'right:6%;top:40%;width:clamp(70px,20vw,190px);--d:46vh;--x0:16vw;--x1:-10vw')}
  <div class="front two-in">
    ${stk('h2', 'Two players, one hinge', 'ho l', 'id="h-two" style="--d:8vh"')}
    <p class="l" style="--d:5vh">Each player owns one side. A touch only reaches the bubbles on the side it lands on, and you can both tap at once.</p>
    <p class="l" style="--d:3vh">Let a bubble cross and you pay the meter charge, and the pieces land on your rival. Take their last shield and you win on the spot. If every bubble is cleared first, the higher score wins.</p>
  </div>
</section>

<section class="sec devices" data-shape="duo" data-tint="neon" aria-labelledby="h-devices">
  ${sparkles(6, 83)}
  <div class="front blk devices-title">${stk('h2', 'Made for iPhone Duo, iPad and iPhone', 'cy l', 'id="h-devices" style="--d:9vh"')}</div>
  <div class="device-row">
    <article class="own device duo">
      <div class="l o art frame" style="--y0:50vh;--r0:-14deg" aria-hidden="true"><i class="fold"></i></div>
      <div class="front l o" style="--y0:6vh"><h3>iPhone Duo</h3><p>The app puts the hinge on the real fold. Hold it like a book for two players and each of you gets a panel.</p></div>
    </article>
    <article class="own device pad">
      <div class="l o art frame" style="--y0:80vh;--r0:10deg" aria-hidden="true"><i class="line"></i></div>
      <div class="front l o" style="--y0:8vh"><h3>iPad</h3><p>Room for big swipes. Lay it flat between two players.</p></div>
    </article>
    <article class="own device phone">
      <div class="l o art frame" style="--y0:110vh;--r0:-8deg" aria-hidden="true"><i class="line"></i></div>
      <div class="front l o" style="--y0:10vh"><h3>iPhone</h3><p>One thumb and a hinge across the middle of the arena.</p></div>
    </article>
  </div>
  <p class="note front l" style="--d:3vh">The web game draws its hinge on the screen. It does not detect folds, so that part is the app's alone.</p>
</section>

<section class="sec app" data-shape="logo-app" data-tint="classic" aria-labelledby="h-app" id="app">
  ${backdrop('classic', '--d:-10vh', 'soft')}
  ${sparkles(8, 97)}
  ${bob('bubble-armored', 384, 'left:-5%;top:8%;width:clamp(80px,20vw,180px);--d:28vh;--r1:-20deg')}
  ${bob('bubble-magnetic', 384, 'right:-3%;top:44%;width:clamp(70px,18vw,160px);--d:48vh;--r1:24deg')}
  <div class="front app-in">
    ${stk('h2', 'Get the app', 'go l', 'id="h-app" style="--d:10vh"')}
    <div class="buttons l" style="--d:6vh">
      ${storeButton(testflight, 'primary', 'btn-testflight')}
      ${storeButton(appStore, 'secondary', 'btn-appstore')}
    </div>
    <div class="compare l" style="--d:3vh">
      <div><h3>In the app</h3><p>All 8 bubbles, 5 power-ups, 4 arenas, 5 chapters plus Infinity, Arcade and Daily modes, and the real fold on iPhone Duo.</p></div>
      <div><h3>On this page</h3><p>Basic bubbles only, endless levels and two players on one screen. It is free to play here, right now.</p></div>
    </div>
    <p class="promise l" style="--d:2vh">No account. No ads. No analytics. Your progress stays on your device.</p>
    <p class="links l" style="--d:1vh"><a href="privacy/">Privacy</a><a href="support/">Support</a></p>
    <p class="cue"><a href="#play" data-jump>Or keep scrolling and play the web version right here.</a></p>
  </div>
</section>
</main>

<section class="arrive" id="play" data-shape="seam" aria-labelledby="h-play">
  <div class="stage" data-axis="h">
    <h2 id="h-play" class="sr">Play Hinge Pop</h2>
    <nav class="rail" aria-label="Leave the game">
      <button type="button" class="pill" id="back-top"><span aria-hidden="true">↑</span> <span class="lab">Back to top</span><span class="sr">Back to top</span></button>
      <p class="rail-note">Basic bubbles only on the web. <a href="#app" data-app>Get the app</a></p>
      <a class="pill" id="full" href="play/"><span class="lab">Full screen</span><span class="sr">Play full screen</span><span aria-hidden="true">↗</span></a>
    </nav>
    <div class="slot">
      <iframe id="game" title="Hinge Pop, the web game. Tap or swipe bubbles to split them." data-src="play/" allow="screen-wake-lock"></iframe>
      <noscript><p class="noscript-play"><a class="btn primary" href="play/">Play Hinge Pop</a></p></noscript>
    </div>
    <div class="door door-a l t" aria-hidden="true">
      <div class="door-in">
        <div class="night"></div>
        <div class="l t dl arena" style="--m:-16vh"><picture><source media="(min-aspect-ratio: 1/1)" srcset="art/arena-classic-wide.webp"><img src="art/arena-classic-tall.webp" alt="" width="800" height="1400" loading="lazy"></picture></div>
        <div class="l t dl b1" style="--m:30vh"><img src="art/bubble-basic.webp" alt="" width="384" height="384" loading="lazy"></div>
        <div class="l t dl b2" style="--m:64vh"><img src="art/bubble-golden.webp" alt="" width="384" height="384" loading="lazy"></div>
        <div class="l t dl b3" style="--m:12vh"><img src="art/bubble-fast.webp" alt="" width="384" height="384" loading="lazy"></div>
        <div class="l t dl b4" style="--m:44vh"><img src="art/bubble-frozen.webp" alt="" width="384" height="384" loading="lazy"></div>
        <div class="door-text"><span class="stk cy" data-t="The hinge">The hinge</span><span class="stk go" data-t="opens">opens</span></div>
      </div>
    </div>
    <div class="door door-b l t" aria-hidden="true"></div>
    <div class="seam l t" aria-hidden="true">
      <div class="l t seam-h">${bolt()}</div>
      <div class="l t seam-v">${boltV()}</div>
    </div>
  </div>
</section>
</body>
</html>
`;
}

function docPage({ title, description, path, heading, body }) {
  return `${head({ title, description, path, root: '../', image: 'art/og.jpg' })}
<body class="doc">
<header class="doc-head">
  <a href="../" class="doc-logo"><img src="../art/logo.webp" alt="Hinge Pop home" width="1000" height="860"></a>
  ${stk('h1', heading, 'cy')}
</header>
<main class="doc-body">
${body}
</main>
<footer class="doc-foot">
  <a href="../">Home</a><a href="../play/">Play</a><a href="../privacy/">Privacy</a><a href="../support/">Support</a>
</footer>
</body>
</html>
`;
}

export const privacy = () => docPage({
  title: 'Privacy: Hinge Pop',
  description: 'Hinge Pop collects nothing. No accounts, no ads and no analytics. Your progress stays on your device.',
  path: 'privacy/',
  heading: 'Privacy',
  body: `<p class="doc-lede">Hinge Pop collects nothing about you.</p>
<h2>The game</h2>
<ul>
  <li>There are no accounts, so there is nothing to sign up for or log in to.</li>
  <li>There are no ads and no analytics, in the app or on this website.</li>
  <li>The game sends nothing about you or how you play to anyone, including us.</li>
</ul>
<h2>Your progress</h2>
<p>Your levels, scores and settings are stored only on your device. In the app they stay in the app's own storage. On the web they stay in your browser's local storage. Delete the app or clear your browser's site data and they are gone, because no other copy exists.</p>
<h2>This website</h2>
<p>The site is hosted by Cloudflare. To serve a page, Cloudflare sees the standard data any web host sees, such as your IP address, your browser type and the page you asked for. We do not add tracking to it, and the fonts and images come from this site, not from other companies.</p>
<h2>Children</h2>
<p>Since the game collects nothing from anyone, it collects nothing from children either.</p>
<h2>Changes and questions</h2>
<p>If this ever changes, this page will change first. Questions are welcome at <a href="${ISSUES}" rel="noopener">GitHub issues</a>. Issues are public, so please leave out anything private.</p>`,
});

export const support = () => docPage({
  title: 'Support: Hinge Pop',
  description: 'How to play Hinge Pop, answers to common questions, and how to get in touch.',
  path: 'support/',
  heading: 'Support',
  body: `<h2>How to play</h2>
<ul>
  <li><strong>Tap</strong> a bubble to split it into two smaller ones. Tap the smallest size and it pops for good.</li>
  <li><strong>Swipe</strong> to slice. One stroke hits every bubble it crosses, and the pieces fly the way you swiped.</li>
  <li><strong>Chain pops.</strong> Popping a tiny bubble sets off every tiny bubble close to it.</li>
  <li><strong>Watch the hinge.</strong> A larger bubble that crosses it splits for free but charges your overload meter. The smallest bubbles pop on it at no cost.</li>
  <li><strong>Keep your shields.</strong> A full meter costs one of your 3 shields. Tap 8 times in a row with no crossing to win one back.</li>
</ul>
<p>The first time you play, a short guided tour teaches all of this with real bubbles.</p>
<h2>Questions</h2>
<h3>How do you win?</h3>
<p>Clear every bubble in the level. Clear it with no crossings for a 25% score bonus. In the app, a clean run earns three stars.</p>
<h3>How do you lose?</h3>
<p>Each crossing charges the overload meter, and a full meter costs a shield. Lose your last shield and the level starts again, with your score back where it began. Nothing else is lost. In a two-player match, losing your last shield loses the match.</p>
<h3>Are the levels infinite?</h3>
<p>Yes. The app has 50 levels in five chapters, each ending on a boss, and then Infinity, which generates levels that keep climbing. It also has Arcade and Daily modes. The web game has its own endless run of levels with basic bubbles.</p>
<h3>Is it family friendly?</h3>
<p>It is cartoon bubbles with faces, and nothing worse than a pop. There are no accounts, ads, chat or links to strangers, and the game collects nothing. It does not have an age rating of its own yet, so please judge it for your family by playing a level.</p>
<h3>Can I customize it?</h3>
<p>In settings you can turn Swipe to slice, Hinge grace and Sound on or off, on both the app and the web. The app adds Haptics, and four arena backdrops to choose from once you reach their chapters.</p>
<h3>Does the web game use the fold on my foldable?</h3>
<p>No. The web game draws its hinge on the screen and does not detect folds. On iPhone Duo, the app puts the hinge on the real fold.</p>
<h3>Where did my progress go?</h3>
<p>Progress is stored only on your device, so it does not move between devices, and clearing the browser's site data or deleting the app removes it.</p>
<h2>Contact</h2>
<p>Report a problem or ask a question at <a href="${ISSUES}" rel="noopener">GitHub issues</a>. Issues are public, so please leave out anything private. Including your device and whether you were playing in the app or on the web helps a lot.</p>`,
});
