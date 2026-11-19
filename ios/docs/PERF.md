# Performance

Measured, not guessed. No simulator is needed for any of this: a Mac Catalyst debug build runs the real
SwiftUI + SpriteKit app on the desktop, and two small Swift packages time the parts that need no screen.
Read Mac numbers for **relative** change and for CPU work: an M-series GPU hides fill-rate costs a phone pays,
and the Mac renders everything at 120 Hz without breaking a sweat, so frame times there say little. Main-thread
CPU per second is the number that carries over: on a phone the same work is 2-4x slower and has to fit in
8.3 ms at 120 Hz.

## Tools

| What | Command (from `ios/`) | Reads |
| --- | --- | --- |
| Main-thread CPU, any build | `scripts/cpu-mac.sh <app> <wait s> <measure s> [flags]` | `ps -M` from outside, so an old build measures the same way as a new one |
| Frame log | `scripts/perf-mac.sh [level] [flags]` (builds the Catalyst app; `NOBUILD=1` skips) | the app's `-perf` line: frame p50/p95/p99, late frames, update cost, effects level and fps |
| Where the time goes | `xcrun xctrace record --template 'Time Profiler' --launch -- build/cat/Build/Products/Debug-maccatalyst/HingePop.app/Contents/MacOS/HingePop -fresh -toured -level 29 -demo -demoSwipe` | call tree (export with `xctrace export --xpath '...table[@schema="time-profile"]'`) |
| The rules and the art, headless | `cd Packages/HingePopBench && swift run -c release hp-bench [sim\|art]` | `Game.step` per 120 Hz frame on the busiest levels; cold draw time of every prewarmed sprite and arena |
| Simulator (when there is one) | `scripts/perf.sh [simulator] [level]` | same `-perf` line |

The Catalyst switch (`SUPPORTS_MACCATALYST = YES`) goes only into the generated, gitignored project;
`perf-mac.sh` adds it and `make gen` puts the project back. Delete `build/cat` when done.

Debug flags that help: `-fx 0...3` pins the effects level, `-stats` turns on SpriteKit's fps/node/draw
counters, `-perf` writes the frame line to `Library/Caches/hingepop.ready`.

## Where the time went (0.5.0, before)

Time Profiler, main thread, level 29 with demo taps and slices, 15 s:

- **SwiftUI, 30-39 %.** The counting score was an `Animatable` `Text`: every frame of every 0.42 s count
  re-ran the whole `PlayView` layout (the top `GeometryReader`, 10-13 % on its own) and redrew the HUD layer,
  shadows included (Core Graphics blurs, `vSepConvolve`, the busiest single function). Scores change several
  times a second, so this was nearly continuous. The last-shield throb (`repeatForever`, with a shadow) did the
  same for as long as you were in danger.
- SpriteKit render, 24-30 %; `GameScene.update`, 12-16 % (debris loop 5 %, bubbles 4 %); `Session.tick`, 7 %
  (of which `syncHUD` building arrays, 3 %).
- Home sat at **~28 % of a Mac core doing nothing**: the logo's 1,400 particles were redrawn on the CPU at
  120 Hz forever (Canvas, 16-25 %), plus the floating bubbles' 30 Hz SwiftUI timeline.
- Hitches: full-screen arena art (about 100-150 ms at 3x) was drawn on the main thread by every
  `ArenaBackground` the first time it appeared (launch, first visit to a screen, rotation); Journey rows drew
  missing backdrops (30-60 ms each) during a scroll; a bubble size the prewarm missed (splitter boss shrinking,
  twins) was drawn mid-play.

## What changed

1. **HUD score** is a `UILabel` (`CountingLabel` in `PlayView.swift`) that steps at 30 Hz and pops in Core
   Animation; its slot is sized for the target value, so SwiftUI lays out the HUD only when the score changes.
   The **danger throb** is Core Animation (`ThrobbingShield`). HUD shadows with a clear colour are removed
   (`glow(_:radius:if:)`), since a clear shadow still costs a blur on every redraw.
2. **Home**: floating bubbles are `CALayer`s with repeating animations (zero main-thread work); the logo
   particles run at full rate only while assembling, then 30 fps, then rest after 8 s like the aurora.
3. **No art on the main thread when it can wait**: `ArenaBackground` draws off the main thread and fades in
   (`Art.arenaIfDrawn`); Journey rows show their gradient until the backdrop is ready; a bubble size the
   prewarm missed wears the nearest ready size until its art lands (`Art.bubbleIfDrawn`).
4. **Scene**: the debris loop writes each node property once and reads nothing back; per-frame `Set`/array
   allocations are reused scratch space; `Session.syncHUD` compares in place; the arena sprite applies the calm
   scrim in its own shader with blending off, which removes one full-screen blended pass per frame.
5. **Frame rate**: 120 Hz only while the effects budget is healthy; 60 behind the end card, 30 behind pause,
   tips and teaching cards; 60 in Low Power Mode or when the device runs hot.
6. **Adaptive effects budget** (`FXBudget.swift`), below.

## The effects budget

`FXBudget.shared.level` is 3 (full) down to 0. Each rendered frame reports its interval; if more than a fifth
of the last two seconds' frames ran late (over 1.5x the target interval) it steps down, and after clean play
(8 s, doubling each time a step up doesn't hold, up to 64 s) it steps back up.

| Level | Debris (shards, halos, glints) | Emitter sparks | Frame rate |
| --- | --- | --- | --- |
| 3 | 100 % | 100 % | screen max (120 on ProMotion) |
| 2 | 75 % | 80 % | screen max |
| 1 | 50 % | 55 % | 60 |
| 0 | 30 % | 35 % | 60 |

Thermal state `serious` caps it at 1, `critical` at 0; Low Power Mode caps it at 2 and 60 Hz. Debris is
thinned evenly; stars flying to the score always fly. The budget never touches the rules, so the simulation
stays deterministic, and Reduce Motion behaves as before (those effects are already off). Telemetry can read
`level`, `cappedBy` and `changes`.

## Numbers

Mac Catalyst debug build on an M-series MacBook (120 Hz), `scripts/cpu-mac.sh`, main-thread CPU as a share of
one core, two rounds each (before = 0.5.0 at `c7966a3`, after = this branch). Play runs `-demo -demoSwipe`
(automatic taps and slices) from 5 s to 20 s; Home from 14 s to 24 s after launch.

| Screen | Before | After | Change |
| --- | --- | --- | --- |
| Home, settled | 18.6 / 18.5 % | 12.7 / 12.0 % | -33 % |
| Home, first 9 s (logo assembling) | 23.1 / 22.9 % | 20.1 / 19.0 % | -15 % |
| Play, level 29 (busy) | 25.0 / 23.7 % | 18.8 / 18.1 % | -24 % |
| Play, level 45 (Void) | 11.8 / 12.5 % | 10.3 / 10.0 % | -17 % |
| Play, level 80 (boss) | 21.8 / 16.3 % | 11.7 / 8.9 % | -45 % |
| Journey | 14.3 / 14.8 % | 14.4 / 16.1 % | no change (not targeted) |

These include the 120 Hz SpriteKit render on a Mac, which a phone pays far more for; the budget's drop to
60 Hz (when frames run late, hot, or Low Power) halves the scene's share on top of this.

Time Profiler, level 29, 15 s, main thread: SwiftUI's frame update went from 1,500-1,560 ms (30-39 %) to
about 250 ms (8 %), and the per-frame layout pass from 10-13 % to about 6 %. The remaining main-thread time is
SpriteKit's own render and encode (about a third), `GameScene.update` (about a sixth; the debris loop and
bubbles), and Core Animation commits.

Frame log (`scripts/perf-mac.sh 29`): p50/p95/p99 8.3 ms on the Mac both before and after; `GameScene.update`
p50 0.32 ms, p95 0.53 ms. The Mac hides frame-time differences; read the CPU numbers above instead.

Headless (`hp-bench`, release, same Mac):

- `Game.step` at 120 Hz is cheap everywhere: mean 0.8-7 us per step (level 29 the busiest at 7.2 us, p99 23 us;
  arcade 1.7 us; Infinity 0.8 us). The rules are not a frame-time problem. Rare single steps spike to 2-12 ms
  (level 45 once at 12.5 ms); worth a look in `HingePopCore` (not changed here).
- Art, drawn cold at 3x: one biome's sprite prewarm 149 ms (bubbles 108 ms of it); a full-screen arena
  83-149 ms (mean 117 ms); a Journey backdrop band 6 ms at 1x; the logo 66 ms. All of these now happen off the
  main thread, or behind a stand-in, during play and scrolling.

## Not done yet (next candidates)

- Journey: the current stop's pulse and the "Play" tag's bob are `repeatForever` SwiftUI animations (the tag
  with a shadow), so the screen redraws at the display rate while it's open. Core Animation versions, as for the
  danger throb, would take it to near zero.
- Home still runs a few always-on 30 fps aurora spots (`AuroraSpot`), the logo bob and, on Overdrive, the
  flame flicker (`repeatForever` with shadows). The end card's `Beckon` animates a shadow radius forever.
- SpriteKit draw calls: debris, sparks and glints use separate textures and two blend modes; one atlas for the
  FX sprites would let more of them batch. `-stats` shows the counts on screen (drawHierarchy snapshots don't
  capture them).
- `Art`'s cache allows 384 MB of decoded images; on 4 GB phones a lower cap may be kinder (watch for jetsam).
