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
- Worlds (native): 80 worlds in 10 realms (`Worlds.swift`), 10 levels each, 800 in all; "Infinity" generates from 801. Realm 1 is the hand-built original eight chapters. Worlds 9–80 come from `Campaign.worldLevel` recipes.
  - Worlds (`Worlds.swift`) are 80 entries over 16 biomes; each picks a biome and a `variant` 0–3 (a time of day or weather take on it). A new world that reuses a biome needs only its row there.
  - A new **biome** needs: a case in `Arena` and `ArenaKind`; a painter in `HingePopArt` (`Biomes*.swift`, using `Scenery.swift`) that paints all four variants from one `Look` each, keeps busy detail at the edges and the play band calm, and draws its landmark at `landmarkSpot` (`Moods.swift`); the same formula in `Secrets.spot`; a bubble skin in `Skins.swift`; four curtain rows in `Aurora.swift`; and an entry in `scripts/art.mjs` plus the web's `ARENAS` list.
  - Look before you ship art: `swift run render-assets <dir> --worlds [biome...] --rings` (in `ios/Packages/HingePopArt`) writes each biome's four variants with the landmark circled, `skins.png` and `worlds-sheet.png`. `WorldsArtTests` checks every biome × variant renders, differs, stays darker than the bubbles, and that landmarks and skins stay in bounds.
  - In play, a scrim darkens the art toward the hinge and the sky curtains hang either side of it, never on it. Keep shader phase speeds multiples of 0.1: the sky clock wraps at 20π, and big sine arguments posterize on the GPU.
  - Each world has one or two `Twist`s, a level-wide rule that never changes what a tap does to a bubble's size. Their numbers live in `Tuning` and scale with `LevelSpec.intensity`. The sim exposes what the renderer needs (`wind`, `gustIn`, `tideOffset`, `wells`, `beatPhase`, `lantern`, per-bubble `presence`/`spring`/`regrow`/`lit`) and emits events for juice (`gust`, `beat`, `beatPop`, `portal`, `spring`, `regrow`, `untouchable`).
  - Twists with stakes: fogged, dark or out-of-phase bubbles can't be touched (`canTouch`). A touch in the dark leaves a lantern (`illuminate`), and the scene calls it after every touch and stroke segment. A phased ghost can't cross; it glances off the line. The tide's moving line can cross a bubble that holds still. Triple pieces are `light` (a medium costs one less).
  - Recipes: levels 1–2 run the twist gently with plain bubbles, then its own kinds (`Campaign.recipe(for:)`) arrive, level 5 spikes, 9 is the hardest, 10 is the boss. Realms climb gently. Each realm's last world is its hardest, with a short meter from level 5. Every world level keeps a big bubble, so watching never wins (tested over 81–800).
  - Boss styles change the pattern, never the hit rules (guard after hits, phases, staggerable wind-up). Twins share one bar and a slam cooldown. The shield blocks touches on its side (`tap(_:atX:atY:)`; swipes meet it from the side they came from). The splitter sheds a fast medium and shrinks. The blinker teleports, then dashes after a short echo. The summoner calls basics from its wall.
  - Drawing: all twist and boss-style visuals live in `TwistLayer.swift`, built once per level, mostly shaders. The world card and twist pictures live in `WorldIntro.swift` (shown once per world, keyed `world-N` in `taught`; `-demo` skips it).
  - Balance: `swift run -c release hp-balance --range 81-800 --realms` sweeps a range in parallel and prints a per-realm table; `--bots idle,h2`, `--runs N` and `--why` (what cost the meter) help when tuning.
  - Coral Drift's current (`LevelSpec.current`) carries bubbles along the hinge and turns around every `currentPeriod` seconds; drifting motes show it.
- Journey (native `Journey.swift`, route `.map`): one lazy row per realm card, world banner and level, over each world's backdrop, with a path whose swing is a function of the row's slot so rows join seamlessly. Keep it one row per level, so `scrollTo` is exact and 800 levels stay cheap. No `AuroraField` per row; use `AuroraTint`. Backdrops go through `Backdrop.image` (biome and variant, cached at scale 1). Phone: realms in a sheet; iPad ≥900pt wide: realms sidebar; Duo: realms on one page, path on the other.
  - Gates (`Progress.swift`, `Gates`): realm 2+ opens with 100 stars from the realm before (80 come from clearing it). `isOpen` checks gates, `nextUp` is what Play starts. `adoptGates()` runs on load: old saves keep every level reached (`gateFloor`) and skip parties for worlds already done. Infinity opens after level 800.
  - World and realm complete moments (`pendingCheer`, `CheerView`) show once, outside play.
  - Debug: `-unlock N` seeds progress (`-starsEach 1` shows a gate, `-cheer` keeps the latest moment), `-realms` opens the realm sheet, `-realm R` jumps there.
- Easter eggs (`Secrets.swift`) are original winks at pop-culture genres. Never use real franchise names, characters, logos or quotes; a test bans the obvious ones.
  - Each world hides a spot that wakes on three taps. Every campaign level from 2 hides one twinkling secret bubble that reveals a genre nod. The nods cycle, so endless levels never run out.
  - Other secrets come from a level, the old arcade code swiped on the logo, the clock, the calendar or milestones.
  - Add more by appending to `Secrets.named` or `Secrets.nods`.
- Page play (iPhone Duo, native only) turns on when the hinge sits on a real fold (`Game.foldPlay`, set from the fold's reserved region, never its angle). Solo games from level 2 only:
  - **Rush page:** every 13 s the busier page glows gold for 6 s. Its bubbles move 1.2× faster and score double.
  - **Crossfold:** a pop on the other page from the last one, inside the combo window, adds an extra combo step.
  - **Crease Clap:** one finger on each page beside the fold at once sweeps the whole line. It reaches further than a snap and shares its recharge.
  - The angle only brightens the rush glow and the sky.
- Difficulty (Nov 2026 pass): a 2 taps/s human bot wins about 70–95% of mid-game levels and 30–60% late, while levels 1–4 stay at 100% and idle at 0%. Measure with `make balance`. `swift run -c release hp-balance --duo <levels>` plays a book-held Duo with page play on, which runs about 10–20% harder. In worlds 9–80 the targets are per world: 70–95% mid-world, 30–60% across each realm's last world, levels 1–2 easier than 9, idle 0%. Bots aim only at bubbles they can see, tap blind in the dark (which lights it) and aim at a shield's open side 80% of the time.

## Teaching the game

Show, then tell. Lead with pictures on a bright aurora, keep each line to a few words, and put detail in a fold or behind a tap. Long explanations are what users complained about.

The first Play and the first two-player match open a guided tour using real bubbles and real input. Add a step to `SOLO_TOUR` or `TWO_TOUR` when a new rule arrives, and add its explanation to `TIPS`. Tooltip text reads live numbers from the sim.

## Environment notes

- `npm run up` is the one command for local work. It serves on port 8796.
- Tests that drive the page seed `toured` and `touredTwo` in `localStorage`, otherwise the first Play opens the tour.
- `npm run test:e2e` needs Playwright's Chromium. Run `npx playwright install chromium` if it is missing.
- Progress and settings are in `localStorage` under `hinge-pop-prefs`. There is no server state.

## Native app and App Store

- Every version needs `ios/release-notes/<version>.md`. Put the `# Hinge Pop <v>: Headline` line first, then `## Bubble news` with 1–4 `- [sf.symbol] line` callouts, an optional `## More`, then the tester notes.
  - A callout can end with `{destination}` (`{guide/duo}`, `{map}`, `{play}`…): it becomes a tap that closes the card and opens that place. Leave it off when the news has no screen. Tokens are listed in `ios/release-notes/README.md`.
  - The app bundles the file and shows it once per version as the update card (`WhatsNew.swift`, `UpdateNotes` in the core). The card never shows on a fresh install or under debug flags; `-whatsNew` forces it (debug builds) without recording the version.
  - TestFlight gets the same file minus the Bubble news.
  - Nods are original only: no real titles, characters or quotes.

- Run everything from `ios/`: `make up` generates the project and builds it. `make core` tests the rules, `make balance` measures difficulty, `make shots` screenshots screens.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` is required. The Makefile and scripts set it.
- The simulator cannot fold by script. Debug flags `-pose book|tabletop|flat` synthesize a fold, so a real fold is only proven on hardware.
- Duo simulator screenshots need `--display=1` (outer, 1398x2034). Without it `simctl` refuses to choose.
- Debug launch flags live in `Debug` in `AppModel.swift`. `-demo` keeps a game alive for captures and `-demoSwipe` holds a real slicing stroke on screen. None of this ships in Release.
- Store art: `ios/scripts/store-capture.sh` writes `store/lobby/raw`, then `node ../lobby/bin/lobby build hinge-pop` and `push hinge-pop`. Always look at `store/lobby/out/sheet.png` before pushing. It has caught system banners, end screens and missing bosses.
- Release: `ios/scripts/testflight.sh` uploads a build (`BETA_EXTERNAL=1` also starts Beta App Review). `node scripts/asc.mjs store-meta|store-rating|store-check` manage the listing. `submit --yes` submits for review.
- After a rejection, the API keeps refusing with "not ready to be submitted". In App Store Connect, open the version, click Update Review, then Resubmit to App Review. Wait for preview videos to finish processing first.
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

## Shipping: main requires green CI

`main` is protected, with no admin bypass, so a direct push is rejected. Commit and push without asking, the same as always, but through a branch:

```sh
git switch -c <what-it-does> origin/main
git push -u origin HEAD
gh pr create --fill
gh pr merge --auto --squash --delete-branch
```

It lands by itself once CI is green. If `git push` says a required status check is expected, this is why. If CI is red, fix the code. Never remove the protection to get something through.
