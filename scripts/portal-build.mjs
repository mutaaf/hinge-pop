#!/usr/bin/env node
// npm run build:crazygames | build:gamedistribution: a portal build (store/portals/SUBMIT.md).
//
//   node scripts/portal-build.mjs <crazygames|gamedistribution> [--no-zip]
//
// 1. index.html for the portal (scripts/portal-html.mjs): relative paths, the portal's SDK, no analytics, no
//    embedding, saves through the portal. The live build (npm run build, dist/) is not touched.
// 2. Beside it only the art the game loads and its two fonts, with their licence (SIL OFL 1.1 asks that it travels
//    with the fonts). No landing page, privacy or support page, no store links.
// 3. Gates the result: no forbidden text in any text file (portal-html.mjs FORBIDDEN), every art file the game names
//    is present, and the size and file count inside the portals' limits.
// 4. Zips it: dist-portals/hinge-pop-<portal>.zip, index.html at the zip's root.
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { FORBIDDEN, PORTALS, editGame, portalHtml } from './portal-html.mjs';
import { GD_GAME_ID, GD_GAME_ID_PLACEHOLDER, MIDGAME_GAP_MS, SDK_WAIT_MS } from '../portal/config.js';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
// CrazyGames' technical requirements: 250 MB and 1,500 files in all, the initial download within 20 MB for mobile.
export const MAX_FILES = 1500, MAX_BYTES = 20e6;

/** The art files the portal page can ask for (pass it the edited source): its sprites, any guests, each chapter's arena. */
export function artFiles(src) {
  const arenas = JSON.parse(src.match(/const ARENAS = (\[[^\]]*\]);/)[1].replace(/'/g, '"'));
  const cameos = JSON.parse(src.match(/cameos: (\[[^\]]*\]),/)[1].replace(/'/g, '"'));
  const files = new Set(['game-bubble.webp', 'logo.webp']);
  for (const a of arenas) for (const o of ['tall', 'wide']) files.add(`arena-${a}-${o}.webp`);
  for (const c of cameos) files.add(`cameo-${c}.webp`);
  return [...files].sort();
}
export const FONTS = ['titan-one.woff2', 'fredoka.woff2'];

function walk(dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...walk(p)); else out.push(p);
  }
  return out;
}

export function gate(dir, art) {
  const problems = [];
  if (!existsSync(join(dir, 'index.html'))) problems.push('no index.html at the top');
  for (const f of art) if (!existsSync(join(dir, 'art', f))) problems.push(`art/${f} missing`);
  if (existsSync(join(dir, 'art'))) for (const f of readdirSync(join(dir, 'art'))) if (/^cameo-/.test(f)) problems.push(`art/${f}: a guest star`);
  const files = walk(dir);
  let bytes = 0;
  for (const f of files) {
    bytes += statSync(f).size;
    if (!/\.(html|js|css|json|txt|svg)$/.test(f)) continue;
    const text = readFileSync(f, 'utf8');
    for (const [re, what] of FORBIDDEN) {
      if (f.endsWith('OFL.txt') && /outbound|device/.test(what)) continue;   // the licence text names its own site
      const m = text.match(re);
      if (m) problems.push(`${relative(dir, f)}: ${what} (${m[0]})`);
    }
  }
  if (files.length > MAX_FILES) problems.push(`${files.length} files (max ${MAX_FILES})`);
  if (bytes > MAX_BYTES) problems.push(`${(bytes / 1e6).toFixed(1)} MB (max 20 for the initial download)`);
  return { problems, files: files.length, bytes };
}

export function licence() {
  const ofl = readFileSync(join(ROOT, 'portal/OFL-1.1.txt'), 'utf8');
  return `The two fonts in this folder are licensed under the SIL Open Font License, Version 1.1 (below).

titan-one.woff2 (Titan One): Copyright (c) 2011 Rodrigo Fuenzalida, with Reserved Font Name "Titan One".
fredoka.woff2 (Fredoka): Copyright 2016 The Fredoka Project Authors.

${ofl}`;
}

const mb = (n) => `${(n / 1e6).toFixed(2)} MB`;

function main() {
  const [portal, ...flags] = process.argv.slice(2);
  if (!PORTALS.includes(portal)) { console.error(`usage: node scripts/portal-build.mjs <${PORTALS.join('|')}> [--no-zip]`); process.exit(2); }
  const gdGameId = process.env.HP_GD_GAME_ID || GD_GAME_ID;
  const src = readFileSync(join(ROOT, 'index.html'), 'utf8');
  const out = join(ROOT, 'dist-portals', portal);
  const game = join(out, 'game');
  rmSync(out, { recursive: true, force: true });
  mkdirSync(join(game, 'art'), { recursive: true });
  mkdirSync(join(game, 'fonts'), { recursive: true });
  writeFileSync(join(game, 'index.html'), portalHtml(src, portal, { gdGameId, gdPlaceholder: GD_GAME_ID_PLACEHOLDER, sdkWaitMs: SDK_WAIT_MS, midgameGapMs: MIDGAME_GAP_MS }));
  const art = artFiles(editGame(src));
  for (const f of art) copyFileSync(join(ROOT, 'site/art', f), join(game, 'art', f));
  for (const f of FONTS) copyFileSync(join(ROOT, 'site/fonts', f), join(game, 'fonts', f));
  writeFileSync(join(game, 'fonts', 'OFL.txt'), licence());
  const { problems, files, bytes } = gate(game, art);
  if (problems.length) { console.error(`portal build ${portal}: ${problems.length} problem(s)\n  ${problems.join('\n  ')}`); process.exit(1); }
  console.log(`portal build ${portal}: ${files} files, ${mb(bytes)} unzipped → ${relative(ROOT, game)}`);
  if (portal === 'gamedistribution' && gdGameId === GD_GAME_ID_PLACEHOLDER) {
    console.warn('\n  WARNING: no GameDistribution game id yet: this build loads no SDK and shows no ads.\n  Paste the id into portal/config.js (GD_GAME_ID) and run this again before uploading (store/portals/SUBMIT.md).\n');
  }
  if (flags.includes('--no-zip')) return;
  const zip = join(ROOT, 'dist-portals', `hinge-pop-${portal}.zip`);
  rmSync(zip, { force: true });
  execFileSync('zip', ['-q', '-r', '-X', '-9', zip, '.'], { cwd: game, stdio: 'inherit' });
  console.log(`  zip: ${relative(ROOT, zip)} (${mb(statSync(zip).size)})`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
