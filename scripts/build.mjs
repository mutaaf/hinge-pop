// Writes the deployable site to dist/hingepop/:
//   /hingepop/          landing page (site/pages.mjs, site/landing.css, site/landing.js)
//   /hingepop/play/     the game: index.html wrapped in a full document
//   /hingepop/privacy/  /hingepop/support/
// index.html stays a bare page body so it can also be published as a private preview.
// HINGEPOP_LINKS (a JSON string) and HINGEPOP_OUT override site/links.json and dist/ for tests.
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { ICON, landing, privacy, support } from '../site/pages.mjs';

const outDir = process.env.HINGEPOP_OUT || 'dist';
const site = join(outDir, 'hingepop');
const links = JSON.parse(process.env.HINGEPOP_LINKS || readFileSync('site/links.json', 'utf8'));

// The vendored library must be exactly the file its pin names.
const pin = JSON.parse(readFileSync('site/vendor/aurora-field.json', 'utf8'));
const vendored = readFileSync('site/vendor/aurora-field.min.js');
const actual = createHash('sha256').update(vendored).digest('hex');
if (actual !== pin.sha256) throw new Error(`site/vendor/aurora-field.min.js does not match its pin. Run npm run sync:aurora. (${actual})`);

const src = readFileSync('index.html', 'utf8');
const split = src.indexOf('<div id="stage">');
if (split < 0) throw new Error('index.html: could not find the stage element');
const head = src.slice(0, split).trim();
const body = src.slice(split).trim();

const description = 'Play Hinge Pop in your browser. Split bubbles and keep them off the hinge, with levels and a two-player mode on one screen.';
const game = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="description" content="${description}">
<meta name="theme-color" content="#140a2e">
<meta property="og:title" content="Play Hinge Pop">
<meta property="og:description" content="${description}">
<meta property="og:url" content="https://mutaafaziz.com/hingepop/play/">
<meta property="og:image" content="https://mutaafaziz.com/hingepop/art/og.jpg">
<meta name="twitter:card" content="summary_large_image">
<link rel="canonical" href="https://mutaafaziz.com/hingepop/play/">
<link rel="icon" href="${ICON}">
${head}
</head>
<body>
${body}
</body>
</html>
`;

rmSync(outDir, { recursive: true, force: true });
mkdirSync(join(site, 'assets'), { recursive: true });
const page = (path, html) => {
  mkdirSync(join(site, path), { recursive: true });
  writeFileSync(join(site, path, 'index.html'), html);
};
page('', landing(links));
page('play', game);
page('privacy', privacy());
page('support', support());
for (const dir of ['art', 'fonts']) cpSync(join('site', dir), join(site, dir), { recursive: true });
mkdirSync(join(site, 'vendor'));
writeFileSync(join(site, 'vendor/aurora-field.min.js'), vendored);
for (const f of ['site.css', 'landing.css', 'landing.js']) cpSync(join('site', f), join(site, 'assets', f));
for (const need of ['art/og.jpg', 'art/game-bubble.webp', 'fonts/titan-one.woff2']) if (!existsSync(join(site, need))) throw new Error('missing ' + need);

// no-transform keeps Cloudflare from injecting analytics into any page, which the privacy page promises.
const html = 'Cache-Control: public, max-age=0, must-revalidate, no-transform';
const routes = ['/hingepop/', '/hingepop/index.html', '/hingepop/play/', '/hingepop/play/index.html', '/hingepop/privacy/', '/hingepop/privacy/index.html', '/hingepop/support/', '/hingepop/support/index.html'];
writeFileSync(join(outDir, '_headers'), routes.map((r) => `${r}\n  ${html}\n`).join(''));
console.log('built', site, Math.round(Buffer.byteLength(game) / 1024) + ' KB game');
