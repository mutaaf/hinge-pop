// Loads the real game rules out of index.html, so tests and bots never drift from the page.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

export function loadSim(overrides = {}) {
  const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
  const src = html.split('// SIM START')[1].split('// SIM END')[0];
  const ctx = {};
  vm.createContext(ctx);
  vm.runInContext(`${src};this.createSim=createSim;this.CFG=CFG;this.levelConfig=levelConfig;`, ctx);
  Object.assign(ctx.CFG, overrides);
  return ctx;
}
