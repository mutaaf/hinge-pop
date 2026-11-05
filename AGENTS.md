# Hinge Pop

Arcade prototype at https://mutaafaziz.com/hingepop/. The question it answers is whether the game is fun with plain circles, so keep art out until that is settled.

## How it fits together

- `index.html` is the whole game. It has no doctype, html, head or body tags on purpose, because it is also published as a private preview that adds them. `scripts/build.mjs` adds them for production.
- The rules sit between `// SIM START` and `// SIM END` and touch no browser APIs. Tests and bots load that block straight from the page (`test/load-sim.mjs`).
- Tune numbers in `CFG`, then run `npm run balance` before and after. Bots aim perfectly, so real players do worse than their win rates.
- Hosting is a Cloudflare Worker with static assets only, on route `mutaafaziz.com/hingepop*`. Never give it its own domain.
- Deploys are manual: `npm run deploy`. Workers Builds is not connected.

## Phone and tablet guidelines

`npm run test:devices` enforces these at 11 sizes, including iPad split view, so run it for any layout change:

- Touch targets are at least 48px (Android 48dp; Apple's minimum is 44pt). The compact two-player HUD is the one exception, with its pause button still at full size.
- No text under 11px. Text contrast is at least 4.5:1.
- Safe areas are respected in every orientation. Turning the device keeps the level and pauses it.
- Tooltips open by tap, never by hover alone. Pinch zoom stays available outside active play.

## Teaching the game

The first Play and the first two-player match open a guided tour using real bubbles and real input. Add a step to `SOLO_TOUR` or `TWO_TOUR` when a new rule arrives, and add its explanation to `TIPS`. Tooltip text reads live numbers from the sim.

## Environment notes

- `npm run up` is the one command for local work. It serves on port 8796.
- Tests that drive the page seed `toured` and `touredTwo` in `localStorage`, otherwise the first Play opens the tour.
- `npm run test:e2e` needs Playwright's Chromium. Run `npx playwright install chromium` if it is missing.
- Progress and settings are in `localStorage` under `hinge-pop-prefs`. There is no server state.

## Definition of done

- `npm test`, `npm run test:e2e` and `npm run test:devices` pass.
- Launcher registration, for any new public mode with a deep link: mutaafaziz-site (`public/index.html` and the docs that list apps), `@mutaaf/launcher`, and Digital Craft `/labs`.
