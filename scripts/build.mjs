// Wraps the page in a full document and writes the deployable site to dist/hingepop/.
// index.html stays a bare page body so it can also be published as a private preview.
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';

const src = readFileSync('index.html', 'utf8');
const split = src.indexOf('<div id="stage">');
if (split < 0) throw new Error('index.html: could not find the stage element');
const head = src.slice(0, split).trim();
const body = src.slice(split).trim();

const description = 'Split bubbles and keep them off the hinge. A one-finger arcade prototype with levels and a two-player mode on one screen.';
const icon = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%230d1117'/%3E%3Cpath d='M0 32h64' stroke='%234fd8ff' stroke-width='4'/%3E%3Ccircle cx='24' cy='19' r='10' fill='%23cfe3f5'/%3E%3Ccircle cx='43' cy='45' r='7' fill='%23f2dd8f'/%3E%3C/svg%3E";

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="description" content="${description}">
<meta name="theme-color" content="#0d1117">
<meta property="og:title" content="Hinge Pop">
<meta property="og:description" content="${description}">
<meta property="og:url" content="https://mutaafaziz.com/hingepop/">
<link rel="canonical" href="https://mutaafaziz.com/hingepop/">
<link rel="icon" href="${icon}">
${head}
</head>
<body>
${body}
</body>
</html>
`;

rmSync('dist', { recursive: true, force: true });
mkdirSync('dist/hingepop', { recursive: true });
writeFileSync('dist/hingepop/index.html', html);
// no-transform keeps Cloudflare from injecting analytics into the game page, as on the other games.
writeFileSync('dist/_headers', '/hingepop/\n  Cache-Control: public, max-age=0, must-revalidate, no-transform\n/hingepop/index.html\n  Cache-Control: public, max-age=0, must-revalidate, no-transform\n');
console.log('built dist/hingepop/index.html', Buffer.byteLength(html), 'bytes');
