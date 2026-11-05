import Foundation
import HingePopCore

// Bots that play like people. Humans miss, react late and don't always see the most urgent bubble:
// "human" makes `rate` touches a second, 15% miss and a third go to a random bubble. "slicer" is the same
// person swiping, with each stroke a straight line through their target.
func timeToHinge(_ g: Game, _ b: Bubble) -> Double {
  let pos = g.vertical ? b.x : b.y, v = g.vertical ? b.vx : b.vy, gap = g.hinge - pos
  return gap * v > 0 ? gap / v : .infinity
}
func play(_ n: Int, kind: String, rate: Double, seed: UInt64, w: Double = 390, h: Double = 760) -> Game {
  var r = SplitMix(seed: seed)
  let g = Game(mode: .campaign(n), width: w, height: h, top: 70, seed: seed)
  var next = 0.8 + 0.4 * r.unit()
  while g.status == .playing && g.time < 300 {
    g.step(1.0 / 60)
    g.events.removeAll(keepingCapacity: true)
    guard kind != "idle", g.status == .playing, g.ready <= 0, g.time >= next else { continue }
    next = g.time + (1 / rate) * (0.7 + r.unit() * 0.6)
    if r.unit() < 0.15 { continue }
    if let p = g.pickups.first, r.unit() < 0.5 { g.collect(p); continue }
    // A person sees a guest about half the time, and sees a boss winding up about half the time.
    if let v = g.visitors.first(where: { $0.presence > 0.35 && $0.x > 0 && $0.x < g.w }), r.unit() < 0.25 { g.catchVisitor(v.id); continue }
    if let boss = g.bubbles.first(where: { $0.bossWindup > 0 }), r.unit() < 0.5 { g.tap(boss); continue }
    guard !g.bubbles.isEmpty else { continue }
    let target: Bubble = r.unit() < 0.33 ? g.bubbles[r.int(g.bubbles.count)] : g.bubbles.min { timeToHinge(g, $0) < timeToHinge(g, $1) }!
    if kind == "slicer" {
      let a = r.unit() * 6.283, len = 120 * g.scale
      var skip = Set<Int>()
      g.slice(fromX: target.x - cos(a) * len, fromY: target.y - sin(a) * len, toX: target.x + cos(a) * len, toY: target.y + sin(a) * len, skip: &skip)
    } else {
      g.tap(target)
    }
  }
  return g
}
let bots: [(String, Double)] = [("idle", 0), ("human", 1), ("human", 1.5), ("human", 2), ("human", 3), ("slicer", 1), ("slicer", 1.5), ("slicer", 2)]
let args = CommandLine.arguments.dropFirst().compactMap { Int($0) }
let levels = args.isEmpty ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 20, 21, 23, 25, 27, 29, 30, 31, 33, 35, 37, 39, 40, 41, 43, 45, 47, 49, 50, 55, 60, 75, 100, 150] : args
print("win% over 40 runs    lv  spec                       " + bots.map { "\($0.0.prefix(1))\($0.1 == 0 ? "" : String(format: "%g", $0.1))".padding(toLength: 6, withPad: " ", startingAt: 0) }.joined() + "time stuck")
for lv in levels {
  let spec = Campaign.level(lv)
  var cells = "", stuck = 0, t = 0.0
  for (kind, rate) in bots {
    var wins = 0
    for s in 1...40 {
      let g = play(lv, kind: kind, rate: rate, seed: UInt64(s))
      if g.status == .won { wins += 1 }
      if g.status == .playing { stuck += 1 }
      if kind == "human" && rate == 2 { t += g.time }
    }
    cells += String(format: "%-6d", Int((Double(wins) / 40 * 100).rounded()))
  }
  let label = "\(Campaign.work(of: spec.spawns))w \(spec.spawns.count)b \(String(format: "%.2f", spec.speed))x m\(spec.meterMax)\(spec.gates > 0 ? " g\(spec.gates)" : "")\(spec.isBoss ? " BOSS\(spec.bossPhases)" : "")"
  print(String(format: "%-3d ", lv) + label.padding(toLength: 26, withPad: " ", startingAt: 0) + cells + String(format: "%3.0fs %d", t / 40, stuck))
}
