import CoreGraphics
import Foundation
import HingePopArt
import HingePopCore

// hp-bench: what a frame costs before SpriteKit sees it.
//   sim  - `Game.step` at the app's 120 Hz on the busiest levels, played by a 2 taps/s bot so they stay busy
//   art  - each piece of art the scene prewarms, drawn cold, at an iPhone's 3x scale
// Usage: swift run -c release hp-bench [sim|art]

func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

func sim() {
  print("sim: Game.step(1/120) on a 430x932 phone, 2 taps/s bot, 6 seeds x up to 90 s of play each")
  print("level            steps   mean_us  p99_us   max_us  peak_bubbles")
  let cases: [(String, GameMode)] = [
    ("1", .campaign(1)), ("29", .campaign(29)), ("45 void", .campaign(45)), ("79", .campaign(79)),
    ("80 boss", .campaign(80)), ("300", .campaign(300)), ("790", .campaign(790)), ("800 boss", .campaign(800)),
    ("850 infinity", .campaign(850)), ("arcade", .arcade(seed: 7)), ("versus", .versus),
  ]
  for (name, mode) in cases {
    var times: [Double] = []
    var peak = 0
    for seed in 1...6 {
      let g = Game(mode: mode, width: 430, height: 932 - 70, top: 70, seed: UInt64(seed))
      var tapIn = 0.5
      var t = 0.0
      let dt = 1.0 / 120
      while g.status == .playing, t < 90 {
        tapIn -= dt
        if tapIn <= 0 {
          tapIn = 0.5
          // The bubble nearest the hinge, the way a person defends the line.
          if let b = g.bubbles.min(by: { abs($0.y - g.hinge) < abs($1.y - g.hinge) }) { _ = g.tap(b) }
        }
        let a = now()
        g.step(dt)
        times.append(Double(now() - a) / 1000)
        g.events.removeAll(keepingCapacity: true)
        peak = max(peak, g.bubbles.count + g.villains.count)
        t += dt
      }
    }
    times.sort()
    let mean = times.reduce(0, +) / Double(max(1, times.count))
    let p99 = times[min(times.count - 1, Int(Double(times.count) * 0.99))]
    print(String(format: "%-14@ %7d %9.2f %7.2f %8.1f %6d", name as NSString, times.count, mean, p99, times.last ?? 0, peak))
  }
}

func art() {
  let scale: CGFloat = 3
  func time(_ label: String, _ body: () -> Void) -> Double {
    let a = now()
    body()
    let ms = Double(now() - a) / 1e6
    print(String(format: "  %-34@ %8.1f ms", label as NSString, ms))
    return ms
  }
  print("art: drawn cold at 3x (Art caches, so each line is a first draw)")
  var total = 0.0
  total += time("bubbles 10 kinds x 4 sizes") {
    for k in BubbleKind.allCases { for px in [40.0, 62, 96, 140] as [CGFloat] { _ = Art.bubble(k, size: px, scale: scale, biome: .forest) } }
  }
  total += time("cameos 8") { for k in CameoKind.allCases { _ = Art.cameo(k, size: 90, scale: scale) } }
  total += time("villains 6") { for k in VillainSprite.allCases { _ = Art.villain(k, size: 110, scale: scale) } }
  total += time("powers 5") { for k in PowerKind.allCases { _ = Art.power(k, size: 54, scale: scale) } }
  total += time("fx (burst, star, ring, shard, glint)") {
    for k in [FXKind.popBurst, .particleStar] { _ = Art.fx(k, size: 96, scale: scale) }
    _ = Art.fx(.shockwave, size: 128, scale: scale)
    for k in [FXKind.shard, .glint] { _ = Art.fx(k, size: 64, scale: scale) }
  }
  total += time("fx crack 512") { _ = Art.fx(.crack, size: 512, scale: scale) }
  print(String(format: "  %-34@ %8.1f ms", "= scene prewarm (per biome)" as NSString, total))
  var arenas = 0.0
  for k in [ArenaKind.classic, .forest, .space, .reef, .circuit, .clockwork] {
    arenas += time("arena \(k.rawValue) 430x932") { _ = Art.arena(k, variant: 1, size: CGSize(width: 430, height: 932), scale: scale) }
  }
  print(String(format: "  %-34@ %8.1f ms", "= mean arena (full screen)" as NSString, arenas / 6))
  _ = time("arena forest 430x150 (journey row, 1x)") { _ = Art.arena(.forest, variant: 2, size: CGSize(width: 430, height: 150), scale: 1) }
  _ = time("logo 380 wide") { _ = Art.logo(width: 380, scale: scale) }
}

let what = CommandLine.arguments.dropFirst().first ?? "all"
if what == "sim" || what == "all" { sim() }
if what == "art" || what == "all" { art() }
