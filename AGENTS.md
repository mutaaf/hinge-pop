# Hinge Pop

Arcade game with three parts: a parallax landing site that scrolls into the web game (https://mutaafaziz.com/hingepop/), the web game itself (`/hingepop/play/`), and a native SwiftUI + SpriteKit app for iPhone, iPad and iPhone Duo (`ios/`). The two games are separate implementations of the same core rules, so change both when a shared rule changes. The native app adds actors, power-ups, gates, chapters, Arcade and Daily.

## How it fits together

- `site/` is the landing site: copy in `pages.mjs`, store links in `links.json` (null shows a disabled button), and the real `aurora-field` library pinned in `vendor/`. `npm run sync:aurora` refreshes the pin.
- `index.html` is the whole web game. It has no doctype, html, head or body tags on purpose, because it is also published as a private preview that adds them. `scripts/build.mjs` adds them for production.
- The rules sit between `// SIM START` and `// SIM END` and touch no browser APIs. Tests and bots load that block straight from the page (`test/load-sim.mjs`).
- Tune numbers in `CFG`, then run `npm run balance` before and after. Measure with the modelled human and slicer bots, because perfect-aim bots hid that levels 6+ were impossible for people.
- Hosting is a Cloudflare Worker with static assets only, on route `mutaafaziz.com/hingepop*`. Never give it its own domain.
- Deploys are manual: `npm run deploy`. Workers Builds is not connected.
- Analytics (web only, the owner's call 2026-11-12): every page ends its `<body>` with `BOX_OFFICE` (`site/pages.mjs`), which loads Box Office's same-origin loader `/boxoffice/v1/insights.js` on https at the top level only (mutaaf/box-office; PostHog via a mutaafaziz.com relay, IPs truncated, GPC/DNT honoured, inputs masked). The game names events with `track()` in `index.html` (`game_start`, `game_over`, `tour_end`; numbers and enums only), which goes to the landing page's loader when framed. The privacy page says so. The native app has none, and its App Privacy label stays "Data Not Collected".

## Phone and tablet guidelines

`npm run test:devices` enforces these at 11 sizes, including iPad split view, so run it for any layout change:

- Touch targets are at least 48px (Android 48dp; Apple's minimum is 44pt). The two-player scoreboards are the one exception, with the shared pause button still at full size.
- No text under 11px. Text contrast is at least 4.5:1.
- Safe areas are respected in every orientation. Turning the device keeps the level and pauses it.
- Tooltips open by tap, never by hover alone. Pinch zoom stays available outside active play.

## Rules worth knowing

- Crossing cost follows weight: big fills the meter, medium adds half, small adds 1. A big bubble left alone costs all three shields, so no level can be won without touching the screen. Tests enforce this.
- Busy levels arrive in stages (`arrival*` in the tuning), and only two big bubbles come at once.
- Bosses (native only) guard briefly after each hit, don't feed the streak, and telegraph a dash that a hit can stagger. Hits per phase rise by chapter, then one more every third realm (four-phase finales take 3/4 as many per phase). In its last phase a boss sheds a small piece toward the line every `bossShedEvery` seconds (`bossShed`).
- Two players (0.3.2) is a face-off: the device lies flat between two people at opposite ends, so the hinge splits the **long** axis (`vertical = width > height`, the same rule as solo; versus no longer forces a vertical line). Phone portrait: top and bottom halves. Wide screens (landscape, iPad landscape, desktop web): left and right, players at the short ends. On iPhone Duo a real fold wins, whichever way it runs (`FoldLayout.resolve` no longer refuses a horizontal fold in versus): each page is a player.
  - Indices: `players[0]` owns the near half (top, or left), `players[1]` the far half (bottom, or right). Readouts call `players[1]` "Player 1" and `players[0]` "Player 2" (`Seat.name`); never "left"/"right".
  - Each player keeps a scoreboard band at their own edge (`Seat.band`), so the arena sits between the bands with `top = 0` and both halves are equal. Native: `Session.playRect` (the scene's `world` and `gamePoint` follow it); web: the page cuts the bands and passes the rest to the SIM (`left` wall).
  - Facing: everything a player owns turns to read from their seat (`Seat.degrees`/`Seat.radians`: 0 bottom, 180 top, 90 left, -90 right; `SeatTurn` in `FaceOff.swift`). Scoreboards, tips, toasts, the pause and result cards, the tour card, callouts (combo words, SNAP!, SHIELD DOWN!, FEVER!, the YOU WIN!/SO CLOSE! verdicts), score fly-ups and pickups. Bubbles face whoever's half they're on and spin round (0.3 s, pooled, render state only) when they cross; Reduce Motion turns them instantly. Debug: `-flipTime s` slows the spin, `-freezeOn flip` catches one; `-versus -win` ends a match with Player 1 ahead.
  - One shared pause sits at the hinge's end (off the crease on a fold). The end card is split: a result facing each player and one Rematch on the hinge. Turning the device mid-match pauses it, since the seats move.
  - `GameTests` cover face-off ownership, crossings, snaps, pickups and a fairness check (the same bot wins 35–65% from either seat in both orientations; measured about 45% for Player 1).
- Guest stars are `Visitor`s, not bubbles: they never block a clear or touch the meter, and they skip level 1, two-player and the tour. They are original genre nods. Keep them that way: no real characters, logos or names.

- Snap the Hinge is the game's signature: drag off the line and it flings nearby bubbles back, with a recharge. It's also how the game stands apart in the store (a 4.3 rejection said the first version didn't). Lead with it in store copy. The fold angle must stay effects-only, so it never triggers a snap.
- Worlds (native): 80 worlds in 10 realms (`Worlds.swift`), 10 levels each, 800 in all; "Infinity" generates from 801. Realm 1 is the hand-built original eight chapters. Worlds 9–80 come from `Campaign.worldLevel` recipes.
  - Worlds (`Worlds.swift`) are 80 entries over 16 biomes; each picks a biome and a `variant` 0–3 (a time of day or weather take on it). A new world that reuses a biome needs only its row there.
  - A new **biome** needs: a case in `Arena` and `ArenaKind`; a painter in `HingePopArt` (`Biomes*.swift`, using `Scenery.swift`) that paints all four variants from one `Look` each, keeps busy detail at the edges and the play band calm, and draws its landmark at `landmarkSpot` (`Moods.swift`); the same formula in `Secrets.spot`; a bubble skin in `Skins.swift`; four curtain rows in `Aurora.swift`; and an entry in `scripts/art.mjs` plus the web's `ARENAS` list.
  - Look before you ship art: `swift run render-assets <dir> --worlds [biome...] --rings` (in `ios/Packages/HingePopArt`) writes each biome's four variants with the landmark circled, `skins.png` and `worlds-sheet.png`. `WorldsArtTests` checks every biome × variant renders, differs, stays darker than the bubbles, and that landmarks and skins stay in bounds.
  - In play, a scrim darkens the art toward the hinge and the sky curtains hang either side of it, never on it. Keep shader phase speeds multiples of 0.1: the sky clock wraps at 20π, and big sine arguments posterize on the GPU.
  - Each world has one or two `Twist`s, a level-wide rule that never changes what a tap does to a bubble's size. Their numbers live in `Tuning` and scale with `LevelSpec.intensity`. The sim exposes what the renderer needs (`wind`, `gustIn`, `tideOffset`, `wells`, `beatPhase`, `lantern`, per-bubble `presence`/`spring`/`regrow`/`lit`) and emits events for juice (`gust`, `beat`, `beatPop`, `portal`, `spring`, `regrow`, `untouchable`).
  - Twists with stakes: fogged, dark or out-of-phase bubbles can't be touched (`canTouch`). A touch in the dark leaves a lantern (`illuminate`), and the scene calls it after every touch and stroke segment. A phased ghost can't cross; it glances off the line. The tide's moving line can cross a bubble that holds still. Triple pieces are `light` (a medium costs one less).
  - Recipes: levels 1–2 run the twist gently with plain bubbles, then its own kinds (`Campaign.recipe(for:)`) arrive, level 5 spikes, 9 is the hardest, 10 is the boss. Realms climb gently. Each realm's last world is its hardest: it starts faster and climbs less, so its end is a test, not a wall. The whole curve lives in `Pressure` (worlds 9–80) and `HomePressure` (realm 1) in `Levels.swift`. Every world level keeps a big bubble, so watching never wins (tested over 81–800).
  - Boss styles change the pattern, never the hit rules (guard after hits, phases, staggerable wind-up). Twins share one bar and a slam cooldown. The shield blocks touches on its side (`tap(_:atX:atY:)`; swipes meet it from the side they came from). The splitter sheds a fast medium and shrinks. The blinker teleports, then dashes after a short echo. The summoner calls basics from its wall.
  - Drawing: all twist and boss-style visuals live in `TwistLayer.swift`, built once per level, mostly shaders. The world card and twist pictures live in `WorldIntro.swift` (shown once per world, keyed `world-N` in `taught`; `-demo` skips it).
  - Balance: `swift run -c release hp-balance --range 81-800 --realms` sweeps a range in parallel and prints a per-realm table (h2 by k1, k2, k3–8, k9, boss and last world, plus the expert on each last world); `--bots idle,h2,e3.5`, `--runs N` and `--why` (what cost the meter, plus overtime, fever, surge, shed and champion counts) help when tuning. Per-level rows show par, the h2 3-star and overtime rates and the expert's 3-star rate.
  - Coral Drift's current (`LevelSpec.current`) carries bubbles along the hinge and turns around every `currentPeriod` seconds; drifting motes show it.
- Journey (native `Journey.swift`, route `.map`): one lazy row per realm card, world banner and level, over each world's backdrop, with a path whose swing is a function of the row's slot so rows join seamlessly. Keep it one row per level, so `scrollTo` is exact and 800 levels stay cheap. No `AuroraField` per row; use `AuroraTint`. Backdrops go through `Backdrop.image` (biome and variant, cached at scale 1). Phone: realms in a sheet; iPad ≥900pt wide: realms sidebar; Duo: realms on one page, path on the other.
  - Gates (`Progress.swift`, `Gates`): realm 2+ opens with 100 stars from the realm before (80 come from clearing it). `isOpen` checks gates, `nextUp` is what Play starts. `adoptGates()` runs on load: old saves keep every level reached (`gateFloor`) and skip parties for worlds already done. Infinity opens after level 800.
  - World and realm complete moments (`pendingCheer`, `CheerView`) show once, outside play.
  - Mastery (`Challenges.swift`): every campaign level has 3 challenges from its spec (`Challenges.for(level:)`: hold the line, pace, flair; the flair is the world twist's own when it has one) and an S–D grade from its own points against `Par.score(spec)`. The session fills a `RunLog` from `GameEvent`s; `GameProgress.record(level:stars:score:grade:earned:)` keeps the best grade, earned challenges (a bitmask per level) and reports news for the end card (`EndCard.swift`). All 30 in a world wins its medal and that biome's swipe trail (`Trails`, cosmetic only). Gates stay star-based. Calibrate with `swift run -c release hp-balance --meta --range 1-800 --bots h3,s2` (earn rates per challenge, grade shares, par ratio).
  - Debug: `-endCard win|lose` (with `-level N`) plays a level to its end card by itself; `-mastery` with `-unlock N` seeds grades and challenges.
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
- Difficulty (hard pass, Nov 2026): the default is the hard game; there is no easy mode. Targets for the 2 taps/s human bot (`h2`), per world in every realm including the hand-built first: levels 1–2 ≥90% (the tutorial, slow and with no surge), then world 1 bites from level 3 (about 85%, 75%, then 65% by levels 5–6; its hand-built sizes, paces and surges are `firstChapter`, `HomePressure.firstPaces` and `firstSurges`) and is no softer than any other world; world openers (k1) 75–90%; mid-world (k3–8) 45–70%; each world's level 9 25–45%; bosses 25–50%; each realm's last world 15–35%; level 800 8–20%. The `expert` bot (3.5 taps/s, 8% miss, sees most wind-ups) must keep ≥50% on every last world, so it's hard, not impossible. Idle stays 0% everywhere. Measure with `swift run -c release hp-balance --range 1-800 --realms --runs 32`; `--duo <levels>` plays a book-held Duo with page play on, which runs about 10 points harder. Bots aim only at bubbles they can see, tap blind in the dark (which lights it) and aim at a shield's open side 80% of the time.
  - Meter 3 is a cliff for a 2 taps/s player (about −40 points), so it's used sparingly: Frost Fair's level 9 and late-realm bosses (`bossShortMeterTier`). Pressure comes from pace, budget, surges and champions instead.
  - **Overtime:** each campaign or daily level has a par (`overtimeAt`: `overtimeBase` + `overtimePerWork` per tap of work + `overtimePerHit` per boss hit). Past it, everything speeds up `overtimeGain` every `overtimeEvery` s, up to `overtimeSteps`, and waiting arrivals come in at each step. State: `overtime`, `overtimeIn`, `overtimeSpeed`; event `overtime(step:)`. Arcade, versus and the tour have none.
  - **Fever:** a combo filled to `comboMax` starts a fever for `feverTime` s: pops score `feverPoints`×, that player's bubbles slow to `feverSlow`, and the combo holds, then it's spent (combo back to 1). A crossing ends it early. State: `Game.feverLeft`, `Player.fever`, `Player.fevers`; events `feverStart(player:)` and `feverEnd(player:)`. Never in the tour.
  - **Surge:** `LevelSpec.surge` small bubbles rush in from both walls as a level's last push, once the arrivals are in and the arena has thinned. `surgeWarning(count:)` comes `surgeWarn` s before `surge(count:)` (`Game.surgeIn` counts down). A level can't be won before its surge, and a surge never brings a big one.
  - **Champions:** crowned bubbles (`Spawn.champion`, `Bubble.champion`) from a world's 6th–7th level. Each takes `championArmor` extra hits (in `armor`) and moves `championSpeed`× faster; a crack emits `championCrack(… armorLeft:)` and never changes its size. Never on a big bubble, never in world 1.
  - **Stars** (`Game.stars`, the one rule): 3 = no shield lost, at most two crossings and cleared inside par (before overtime); 2 = at most one shield lost; 1 = any clear. Three stars is a near-flawless run: the h2 bot gets it under 5% of the time past level 5, the expert 15–70%.
- Difficulty modes (0.3.1): **Normal** is the hard curve above, unchanged; its targets and tests are the ones above. **Overdrive** is the same 800 levels run hotter, for experts: the `h2` bot wins about 70% less on every level (Overdrive ÷ Normal ≈ 0.30, per level 0.22–0.38, average 0.27–0.33). Arcade, Daily, Versus and the tour have no difficulty.
  - One place: `Difficulty.swift` (`Difficulty`, `Overdrive`). `Campaign.level(n, difficulty:)` and `Game(…, difficulty:)` apply it; only `.campaign` runs hot, and `Game.difficulty` says which. The app reads `GameProgress.difficulty` (optional in the save, so old saves load as Normal).
  - Levers: every Overdrive level gets the same flavour (`Overdrive.spec`/`Overdrive.tuning`: surge +1, one more crown where the world already crowns, combo window ×0.85, overtime base ×0.75 and gain +0.03, +1 boss hit per phase, wind-ups ×0.9 apart, surge warning ×0.8), then its pace is multiplied by `1 + heat`. Heat is per level (`Overdrive.calibration`, hundredths, one byte per level; Infinity uses the last world's average). Levels 1–2 can't be rushed (one big bubble), so on Overdrive they play level 3's crowd, pace and surge.
  - Calibrate after any change to Normal's curve or to the flavour: `swift run -c release hp-balance --calibrate --range 1-800 --runs 200 --want 150` (bisects each level's heat on its own seeds, from 1,000,001; prints the table to paste into `calibration`). A few levels (some bosses) don't lose wins smoothly as pace rises, so re-run any level the check puts outside 0.24–0.36 with `--calibrate --grid <levels>` (scans 0.02–2.5), then `--fine` (±0.12 in hundredths; add `--raw` where neighbouring heats jump) and patch those entries. Then check on independent seeds with `swift run -c release hp-balance --ratio --range 1-800 --runs 200 --want 150 --quiet` (per-realm Normal h2, Overdrive h2, ratio and range, Overdrive e3.5, then the levels furthest from 0.30). Runs adapt so each level sees about `--want` Overdrive wins; `--difficulty overdrive` runs any other mode of the tool on Overdrive, and `--heat H` probes one heat everywhere. The expert must stay beatable on Overdrive (non-zero everywhere).
  - Progress is shared: one unlock path, stars, gates, best score, best grade and challenges, whichever mode cleared it. An Overdrive clear also marks the level (`clearedOnOverdrive`, a flame on the journey stop and on the end card; `RunNews.firstOverdrive`). Challenges are the level's Normal list in both modes; par (`Par.score(spec, tuning:)`) is taken from the level as played, so an Overdrive grade is fair against its bigger crowd and tougher boss.
  - UI: the Normal / Overdrive switch (`DifficultySwitch`, `OverdriveUI.swift`) sits under Play on Home and first in Settings; the journey's top bar has a flame flip (`OverdriveFlip`). In play, the HUD shows an `OVERDRIVE` tag with a warm edge and the hinge runs amber while calm. Debug: `-overdrive` / `-normal` set the mode; `-mastery` marks every third seeded level as an Overdrive clear.
  - Tests: `DifficultyTests` (Overdrive strictly harder and deterministic on 1–800, only the campaign runs hot, a fixed-seed ratio check, save migration and shared progress); UI: `OverdriveTests`.

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
