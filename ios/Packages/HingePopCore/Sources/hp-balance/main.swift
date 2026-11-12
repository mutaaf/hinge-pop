import Foundation
import HingePopCore

// Bots that play like people. Humans miss, react late and don't always see the most urgent bubble:
// "human" makes `rate` touches a second, 15% miss and a third go to a random bubble. "slicer" is the same
// person swiping, with each stroke a straight line through their target. "expert" is a strong player: it misses
// 8%, picks the wrong bubble 15% of the time, and catches wind-ups and snaps far more reliably.
//
// Usage:
//   hp-balance [levels...]                 every bot, 40 runs each, one row per level
//   hp-balance --range 81-800 --realms     sweep a range with the quick bots and print a per-realm table
//   --runs N      runs per bot (default 40, or 16 with --range)
//   --bots LIST   e.g. idle,h2,s1.5,e3.5 (h = human, s = slicer, e = expert)
//   --duo         plays an iPhone Duo held like a book, with page play on
//   --quiet       skip the per-level rows
func timeToHinge(_ g: Game, _ b: Bubble) -> Double {
  let pos = g.vertical ? b.x : b.y, v = g.vertical ? b.vx : b.vy, gap = g.hinge - pos
  return gap * v > 0 ? gap / v : .infinity
}
let argv = CommandLine.arguments
let duo = argv.contains("--duo")
func option(_ name: String) -> String? { argv.firstIndex(of: name).flatMap { $0 + 1 < argv.count ? argv[$0 + 1] : nil } }

/// `--why` counts what cost the meter: crossings by size, boss slams and dashes.
let why = argv.contains("--why")
var reasons: [String: Int] = [:]
let reasonLock = NSLock()
func tally(_ events: [GameEvent]) {
  for e in events {
    var key: String?
    switch e {
    case .crossed(_, _, _, let size, _): key = "cross\(size)"
    case .bossSlam: key = "slam"
    case .shieldLost: key = "shieldLost"
    case .bossWindup: key = "windup"
    case .bossStagger: key = "stagger"
    case .overtime: key = "overtime"
    case .feverStart: key = "fever"
    case .surge: key = "surge"
    case .bossShed: key = "shed"
    case .championCrack: key = "champion"
    default: break
    }
    if let key { reasonLock.lock(); reasons[key, default: 0] += 1; reasonLock.unlock() }
  }
}
func play(_ n: Int, kind: String, rate: Double, seed: UInt64, w: Double = 390, h: Double = 760) -> Game {
  var r = SplitMix(seed: seed)
  let g = duo
    ? Game(mode: .campaign(n), width: 1300, height: 900, top: 70, vertical: true, hinge: 650, seed: seed)
    : Game(mode: .campaign(n), width: w, height: h, top: 70, seed: seed)
  g.foldPlay = duo
  var next = 0.8 + 0.4 * r.unit()
  let dark = g.spec.has(.blackout)
  let expert = kind == "expert"
  let miss = expert ? 0.08 : 0.15, stray = expert ? 0.15 : 0.33, sees = expert ? 0.85 : 0.5, snaps = expert ? 0.6 : 0.33
  while g.status == .playing && g.time < 300 {
    g.step(1.0 / 60)
    if why { tally(g.events) }
    g.events.removeAll(keepingCapacity: true)
    guard kind != "idle", g.status == .playing, g.ready <= 0, g.time >= next else { continue }
    next = g.time + (1 / rate) * (0.7 + r.unit() * 0.6)
    if r.unit() < miss { continue }
    if let p = g.pickups.first, r.unit() < 0.5 { g.collect(p); continue }
    // A person sees a guest about half the time, and sees a boss winding up about half the time.
    if let v = g.visitors.first(where: { $0.presence > 0.35 && $0.x > 0 && $0.x < g.w }), r.unit() < 0.25 { g.catchVisitor(v.id); continue }
    if let boss = g.bubbles.first(where: { $0.bossWindup > 0 }), r.unit() < sees { touch(g, boss, &r); continue }
    // Once it's ready, they snap about a third of the time a big bubble is close to the line.
    if g.players[0].snapLeft <= 0, r.unit() < snaps, g.bubbles.contains(where: { $0.size == 0 && $0.kind != .boss && abs((g.vertical ? $0.x : $0.y) - g.hinge) < 100 }) { if duo { g.clap() } else { g.snap(along: 100) }; continue }
    // People only aim at what they can see: fogged and out-of-phase bubbles are skipped. In the dark they
    // can make out a faint outline, so they tap at it, which lights it for the next touch.
    let seen = dark ? g.bubbles : g.bubbles.filter { g.visibility($0) >= 0.4 && $0.presence >= 0.5 }
    guard !seen.isEmpty else { continue }
    let target: Bubble = r.unit() < stray ? seen[r.int(seen.count)] : seen.min { timeToHinge(g, $0) < timeToHinge(g, $1) }!
    if kind == "slicer" {
      let a = r.unit() * 6.283, len = 120 * g.scale
      var skip = Set<Int>()
      let from = (target.x - cos(a) * len, target.y - sin(a) * len)
      g.slice(fromX: from.0, fromY: from.1, toX: target.x, toY: target.y, skip: &skip)
      g.illuminate(x: target.x, y: target.y)
      g.slice(fromX: target.x, fromY: target.y, toX: target.x + cos(a) * len, toY: target.y + sin(a) * len, skip: &skip)
    } else {
      touch(g, target, &r)
    }
  }
  return g
}

/// A tap where a person would put it: on a shielded boss, the open side most of the time.
func touch(_ g: Game, _ b: Bubble, _ r: inout SplitMix) {
  let open = b.kind == .boss && r.unit() < 0.8 ? b.shieldAngle + .pi : r.unit() * 6.283
  g.tap(b, atX: b.x + cos(open) * b.r * 0.6, atY: b.y + sin(open) * b.r * 0.6)
  g.illuminate(x: b.x, y: b.y)
}

let allBots: [(String, Double)] = [("idle", 0), ("human", 1), ("human", 1.5), ("human", 2), ("human", 3), ("slicer", 1), ("slicer", 1.5), ("slicer", 2), ("expert", 3.5)]
func parseBots(_ s: String) -> [(String, Double)] {
  s.split(separator: ",").map { t in
    if t == "idle" { return ("idle", 0) }
    return (t.hasPrefix("s") ? "slicer" : t.hasPrefix("e") ? "expert" : "human", Double(t.dropFirst()) ?? 2)
  }
}
let ranged = option("--range")
let levels: [Int] = {
  if let ranged {
    let parts = ranged.split(separator: "-").compactMap { Int($0) }
    return parts.count == 2 ? Array(parts[0]...parts[1]) : parts
  }
  let given = argv.dropFirst().filter { !$0.hasPrefix("-") && Int($0) != nil && !["--runs", "--bots"].contains(argv[argv.firstIndex(of: $0)! - 1]) }.compactMap { Int($0) }
  return given.isEmpty ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 20, 21, 23, 25, 27, 29, 30, 31, 33, 35, 37, 39, 40, 41, 43, 45, 47, 49, 50, 55, 60, 75, 100, 150] : given
}()
let bots = option("--bots").map(parseBots) ?? (ranged != nil ? parseBots("idle,h2,e3.5") : allBots)
let runs = option("--runs").flatMap(Int.init) ?? (ranged != nil ? 16 : 40)
let quiet = argv.contains("--quiet")

struct Row { var wins: [Int]; var stuck = 0; var time = 0.0; var three = 0; var overtime = 0; var proThree = 0 }
var rows = [Row](repeating: Row(wins: []), count: levels.count)
let lock = NSLock()
DispatchQueue.concurrentPerform(iterations: levels.count) { i in
  let lv = levels[i]
  var row = Row(wins: [])
  for (kind, rate) in bots {
    var wins = 0
    for s in 1...runs {
      let g = play(lv, kind: kind, rate: rate, seed: UInt64(s))
      if g.status == .won { wins += 1 }
      if g.status == .playing { row.stuck += 1 }
      if kind == "human" && rate == 2 {
        row.time += g.time
        if g.stars == 3 { row.three += 1 }
        if g.overtime > 0 { row.overtime += 1 }
      }
      if kind == "expert" && g.stars == 3 { row.proThree += 1 }
    }
    row.wins.append(Int((Double(wins) / Double(runs) * 100).rounded()))
  }
  lock.lock(); rows[i] = row; lock.unlock()
}

func label(_ b: (String, Double)) -> String { "\(b.0.prefix(1))\(b.1 == 0 ? "" : String(format: "%g", b.1))" }
if !quiet {
  print("win% over \(runs) runs    lv  spec                            " + bots.map { label($0).padding(toLength: 6, withPad: " ", startingAt: 0) }.joined() + "time  par  3*% ot% e3* stuck")
  for (i, lv) in levels.enumerated() {
    let spec = Campaign.level(lv)
    let tw = spec.twists.map { String($0.rawValue.prefix(4)) }.joined(separator: "+")
    let text = "\(Campaign.work(of: spec.spawns))w \(spec.spawns.count)b \(String(format: "%.2f", spec.speed))x m\(spec.meterMax)\(spec.gates > 0 ? " g\(spec.gates)" : "")\(spec.isBoss ? " B\(spec.bossPhases)\(spec.boss.rawValue.prefix(3))" : "") \(tw)"
    let par = Game(mode: .campaign(lv), width: 390, height: 760, top: 70).overtimeAt
    let pct = { (n: Int) in Int((Double(n) / Double(runs) * 100).rounded()) }
    print(String(format: "%-3d ", lv) + text.padding(toLength: 32, withPad: " ", startingAt: 0) + rows[i].wins.map { String(format: "%-6d", $0) }.joined() + String(format: "%3.0fs %4.0fs %3d %3d %3d  %d", rows[i].time / Double(runs), par, pct(rows[i].three), pct(rows[i].overtime), pct(rows[i].proThree), rows[i].stuck))
  }
}

// The per-realm table: the human at 2 taps/s (or the fastest human asked for), the expert on each realm's last
// world, and the idle bot's best.
if argv.contains("--realms") {
  let hi = bots.firstIndex { $0.0 == "human" && $0.1 == 2 } ?? bots.lastIndex { $0.0 == "human" } ?? bots.count - 1
  let idle = bots.firstIndex { $0.0 == "idle" }
  let pro = bots.lastIndex { $0.0 == "expert" }
  func avg(_ xs: [Int]) -> String { xs.isEmpty ? "  -" : String(format: "%3.0f", Double(xs.reduce(0, +)) / Double(xs.count)) }
  print("\nper realm, \(label(bots[hi])) win%    k1   k2  k3-8   k9  boss  last-world  e:last  idle-max  worst-level")
  for realm in Worlds.realms {
    var first: [Int] = [], second: [Int] = [], mid: [Int] = [], nine: [Int] = [], boss: [Int] = [], last: [Int] = [], proLast: [Int] = [], idleMax = 0
    var worst = (lv: 0, win: 101)
    for (i, lv) in levels.enumerated() {
      guard let w = Worlds.world(ofLevel: lv), w.realm == realm.number else { continue }
      let k = (lv - 1) % 10 + 1, win = rows[i].wins[hi]
      if let idle { idleMax = max(idleMax, rows[i].wins[idle]) }
      if w.number % 8 == 0 { last.append(win); if let pro { proLast.append(rows[i].wins[pro]) } }
      else if k == 1 { first.append(win) } else if k == 2 { second.append(win) } else if k <= 8 { mid.append(win) } else if k == 9 { nine.append(win) }
      if k == 10 { boss.append(win) }
      if win < worst.win { worst = (lv, win) }
    }
    guard !(first + second + mid + nine + boss + last).isEmpty else { continue }
    print(String(format: "%2d %@", realm.number, realm.name.padding(toLength: 14, withPad: " ", startingAt: 0)) + "     \(avg(first))  \(avg(second))  \(avg(mid))  \(avg(nine))   \(avg(boss))      \(avg(last))     \(avg(proLast))       \(String(format: "%3d", idleMax))       \(worst.lv):\(worst.win)")
  }
}
if why { print(reasons.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")) }
