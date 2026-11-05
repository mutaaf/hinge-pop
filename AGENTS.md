# Hinge Pop

Arcade game with three parts: a parallax landing site that scrolls into the web game (https://mutaafaziz.com/hingepop/), the web game itself (`/hingepop/play/`), and a native SwiftUI + SpriteKit app for iPhone, iPad and iPhone Duo (`ios/`). The two games are separate implementations of the same core rules, so change both when a shared rule changes. The native app adds actors, power-ups, gates, chapters, Arcade and Daily.

## How it fits together

- `site/` is the landing site: copy in `pages.mjs`, store links in `links.json` (null shows a disabled button), and the real `aurora-field` library pinned in `vendor/`. `npm run sync:aurora` refreshes the pin.
- `index.html` is the whole web game. It has no doctype, html, head or body tags on purpose, because it is also published as a private preview that adds them. `scripts/build.mjs` adds them for production.
- The rules sit between `// SIM START` and `// SIM END` and touch no browser APIs. Tests and bots load that block straight from the page (`test/load-sim.mjs`).
- Tune numbers in `CFG`, then run `npm run balance` before and after. Measure with the modelled human and slicer bots, because perfect-aim bots hid that levels 6+ were impossible for people.
- Hosting is a Cloudflare Worker with static assets only, on route `mutaafaziz.com/hingepop*`. Never give it its own domain.
- Deploys are manual: `npm run deploy`. Workers Builds is not connected.

## Phone and tablet guidelines

`npm run test:devices` enforces these at 11 sizes, including iPad split view, so run it for any layout change:

- Touch targets are at least 48px (Android 48dp; Apple's minimum is 44pt). The compact two-player HUD is the one exception, with its pause button still at full size.
- No text under 11px. Text contrast is at least 4.5:1.
- Safe areas are respected in every orientation. Turning the device keeps the level and pauses it.
- Tooltips open by tap, never by hover alone. Pinch zoom stays available outside active play.

## Rules worth knowing

- Crossing cost follows weight: big fills the meter, medium adds half, small adds 1. A big bubble left alone costs all three shields, so no level can be won without touching the screen. Tests enforce this.
- Busy levels arrive in stages (`arrival*` in the tuning), and only two big bubbles come at once.
- Bosses (native only) guard briefly after each hit, don't feed the streak, and telegraph a dash that a hit can stagger. Hits per phase rise by chapter.
- Guest stars are `Visitor`s, not bubbles: they never block a clear or touch the meter, and they skip level 1, two-player and the tour. They are original genre nods. Keep them that way: no real characters, logos or names.

- Snap the Hinge is the game's signature: drag off the line and it flings nearby bubbles back, with a recharge. It's also how the game stands apart in the store (a 4.3 rejection said the first version didn't). Lead with it in store copy. The fold angle must stay effects-only, so it never triggers a snap.

## Teaching the game

Show, then tell. Lead with pictures on a bright aurora, keep each line to a few words, and put detail in a fold or behind a tap. Long explanations are what users complained about.

The first Play and the first two-player match open a guided tour using real bubbles and real input. Add a step to `SOLO_TOUR` or `TWO_TOUR` when a new rule arrives, and add its explanation to `TIPS`. Tooltip text reads live numbers from the sim.

## Environment notes

- `npm run up` is the one command for local work. It serves on port 8796.
- Tests that drive the page seed `toured` and `touredTwo` in `localStorage`, otherwise the first Play opens the tour.
- `npm run test:e2e` needs Playwright's Chromium. Run `npx playwright install chromium` if it is missing.
- Progress and settings are in `localStorage` under `hinge-pop-prefs`. There is no server state.

## Native app and App Store

- Run everything from `ios/`: `make up` generates the project and builds it. `make core` tests the rules, `make balance` measures difficulty, `make shots` screenshots screens.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` is required. The Makefile and scripts set it.
- The simulator cannot fold by script. Debug flags `-pose book|tabletop|flat` synthesize a fold, so a real fold is only proven on hardware.
- Duo simulator screenshots need `--display=1` (outer, 1398x2034). Without it `simctl` refuses to choose.
- Debug launch flags live in `Debug` in `AppModel.swift`. `-demo` keeps a game alive for captures and `-demoSwipe` holds a real slicing stroke on screen. None of this ships in Release.
- Store art: `ios/scripts/store-capture.sh` writes `store/lobby/raw`, then `node ../lobby/bin/lobby build hinge-pop` and `push hinge-pop`. Always look at `store/lobby/out/sheet.png` before pushing. It has caught system banners, end screens and missing bosses.
- Release: `ios/scripts/testflight.sh` uploads a build (`BETA_EXTERNAL=1` also starts Beta App Review). `node scripts/asc.mjs store-meta|store-rating|store-check` manage the listing. `submit --yes` submits for review.
- Browser only: creating the app record and the App Privacy label ("Data Not Collected", because the app has no network code).
- `ios/.env.testflight` holds the App Store Connect key path and is gitignored. Never print it.

## Definition of done

- `npm test`, `npm run test:e2e`, `npm run test:devices` and `npm run test:landing` pass. For native changes, `make -C ios core build` too.
- Sound is off by default everywhere, so automated runs stay silent while someone's working. Never turn it on in a script.
- Real touches: `xcodebuild test -scheme HingePop -only-testing:HingePopUITests` on an iPhone and on the Duo simulator. Run it after changing input or safe-area code.
- Do not run two web test suites at once. Each rebuilds `dist/`.
- Smoothness is measured, not guessed: `ios/scripts/perf.sh [simulator] [level]` for native, and `PERF_THROTTLE=6 node scripts/perf-web.mjs` for web. Always check web with the throttle, because desktop hides per-pixel costs.
- Native effects are pooled and art is prewarmed off the main thread. Don't create nodes or render art mid-play, and don't use `SKShapeNode` or `SKLabelNode` per frame. On web, avoid `shadowBlur`.
- The game scene fills the screen but play stays in the safe area: `world` sits at the safe corner, and touches go through `gamePoint`.
- Launcher registration, for any new public mode with a deep link: mutaafaziz-site (`public/index.html` and the docs that list apps), `@mutaaf/launcher`, and Digital Craft `/labs`.
