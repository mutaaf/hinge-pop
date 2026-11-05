# Hinge Pop

Arcade prototype at https://mutaafaziz.com/hingepop/. The question it answers is whether the game is fun with plain circles, so keep art out until that is settled.

## How it fits together

- `index.html` is the whole game. It has no doctype, html, head or body tags on purpose, because it is also published as a private preview that adds them. `scripts/build.mjs` adds them for production.
- The rules sit between `// SIM START` and `// SIM END` and touch no browser APIs. Tests and bots load that block straight from the page (`test/load-sim.mjs`).
- Tune numbers in `CFG`, then run `npm run balance` before and after. Bots aim perfectly, so real players do worse than their win rates.
- Hosting is a Cloudflare Worker with static assets only, on route `mutaafaziz.com/hingepop*`. Never give it its own domain.
- Deploys are manual: `npm run deploy`. Workers Builds is not connected.

## Environment notes

- `npm run up` is the one command for local work. It serves on port 8796.
- `npm run test:e2e` needs Playwright's Chromium. Run `npx playwright install chromium` if it is missing.
- Progress and settings are in `localStorage` under `hinge-pop-prefs`. There is no server state.

## Definition of done

- `npm test` and `npm run test:e2e` pass.
- Launcher registration, for any new public mode with a deep link: mutaafaziz-site (`public/index.html` and the docs that list apps), `@mutaaf/launcher`, and Digital Craft `/labs`.
