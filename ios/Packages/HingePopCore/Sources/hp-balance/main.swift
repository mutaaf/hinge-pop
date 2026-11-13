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
//   --difficulty overdrive   plays Overdrive instead of Normal
//   --ratio       Normal vs Overdrive: h2 on both, e3.5 on Overdrive, per level and per realm, with the ratio.
//                 Runs adapt to the win rate (`--runs` is the floor), so rare wins are still counted well.
//   --calibrate   finds each level's Overdrive heat for the target ratio and prints the table for Difficulty.swift
//   --grid / --fine  with --calibrate: scan heats (whole range, or ±0.12 around the current one) for levels
//                 whose win rate doesn't fall smoothly with pace
//   --seed-base B seeds B+1...B+N (calibration uses its own seeds, so a later sweep is an honest check)
func timeToHinge(_ g: Game, _ b: Bubble) -> Double {
  let pos = g.vertical ? b.x : b.y, v = g.vertical ? b.vx : b.vy, gap = g.hinge - pos
  return gap * v > 0 ? gap / v : .infinity
}
let argv = CommandLine.arguments
let duo = argv.contains("--duo")
func option(_ name: String) -> String? { argv.firstIndex(of: name).flatMap { $0 + 1 < argv.count ? argv[$0 + 1] : nil } }
let difficulty = option("--difficulty").flatMap(Difficulty.init(rawValue:)) ?? .normal
let seedBase = option("--seed-base").flatMap(UInt64.init) ?? 0
/// `--heat H` plays Overdrive at one heat everywhere instead of the calibrated table (for probing).
let fixedHeat = option("--heat").flatMap(Double.init)
/// `--no-villains` plays without villain bubbles, for before/after comparisons.
let baseTuning: Tuning = { var t = Tuning(); t.villains = !CommandLine.arguments.contains("--no-villains"); return t }()

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
    case .villainArrived(let k, _, _, _): key = "v+\(k.rawValue)"
    case .villainStruck(let k, _, _, _, _, _): key = "vhit-\(k.rawValue)"
    case .villainDoom(let k, _, _, _, _): key = "vdoom-\(k.rawValue)"
    case .villainBusted: key = "vbust"
    case .villainEscaped: key = "vdodge"
    default: break
    }
    if let key { reasonLock.lock(); reasons[key, default: 0] += 1; reasonLock.unlock() }
  }
}
/// `--meta` keeps a `RunLog` of each run, for challenge and grade rates.
let meta = argv.contains("--meta")
func play(_ n: Int, kind: String, rate: Double, seed: UInt64, w: Double = 390, h: Double = 760, difficulty: Difficulty = difficulty, heat: Double? = nil) -> Game {
  var log = RunLog()
  return play(n, kind: kind, rate: rate, seed: seed, w: w, h: h, log: &log, difficulty: difficulty, heat: heat)
}
func play(_ n: Int, kind: String, rate: Double, seed: UInt64, w: Double = 390, h: Double = 760, log: inout RunLog, difficulty: Difficulty = difficulty, heat: Double? = nil) -> Game {
  var r = SplitMix(seed: seed)
  let g = duo
    ? Game(mode: .campaign(n), width: 1300, height: 900, top: 70, vertical: true, hinge: 650, tuning: baseTuning, seed: seed, difficulty: difficulty, heat: heat)
    : Game(mode: .campaign(n), width: w, height: h, top: 70, tuning: baseTuning, seed: seed, difficulty: difficulty, heat: heat)
  g.foldPlay = duo
  var next = 0.8 + 0.4 * r.unit()
  let dark = g.spec.has(.blackout)
  let expert = kind == "expert", blind = kind == "blind"
  let miss = expert ? 0.08 : 0.15, stray = expert ? 0.15 : 0.33, sees = expert ? 0.85 : 0.5, snaps = expert ? 0.6 : 0.33
  // Villains: how often a player waits rather than touch a bubble a villain is sitting on, and how often they
  // spot a villain for what it is (a Mimic passes for a golden bubble now and then; a careless glance misses others).
  let wary = expert ? 0.95 : 0.85
  // Decided once per villain, the first time it's seen: a player fooled by one stays fooled.
  var spotted: [Int: Bool] = [:]
  func spots(_ v: Villain, _ r: inout SplitMix) -> Bool {
    if blind { return false }
    if let known = spotted[v.id] { return known }
    let p = v.kind == .mimic ? (expert ? 0.97 : 0.88) : v.kind == .phantom ? (expert ? 0.99 : 0.95) : (expert ? 0.995 : 0.98)
    let seen = r.unit() < p
    spotted[v.id] = seen
    return seen
  }
  while g.status == .playing && g.time < 300 {
    g.step(1.0 / 60)
    if why { tally(g.events) }
    if meta { log.note(g.events, at: g.time) }
    g.events.removeAll(keepingCapacity: true)
    guard kind != "idle", g.status == .playing, g.ready <= 0, g.time >= next else { continue }
    next = g.time + (1 / rate) * (0.7 + r.unit() * 0.6)
    if r.unit() < miss { continue }
    if let p = g.pickups.first, r.unit() < 0.5 { g.collect(p); continue }
    // A person sees a guest about half the time, and sees a boss winding up about half the time.
    if let v = g.visitors.first(where: { $0.presence > 0.35 && $0.x > 0 && $0.x < g.w }), r.unit() < 0.25 { g.catchVisitor(v.id); continue }
    if let boss = g.bubbles.first(where: { $0.bossWindup > 0 }), r.unit() < sees { touch(g, boss, &r); continue }
    // While everything's frozen a villain shatters for points; an alert player cashes in.
    if !blind, g.freeze > 0.4, let v = g.villains.first(where: { $0.solid }), r.unit() < (expert ? 0.6 : 0.2) { g.strike(v); continue }
    // Once it's ready, they snap about a third of the time a big bubble is close to the line.
    if g.players[0].snapLeft <= 0, r.unit() < snaps, g.bubbles.contains(where: { $0.size == 0 && $0.kind != .boss && abs((g.vertical ? $0.x : $0.y) - g.hinge) < 100 }) { if duo { g.clap() } else { g.snap(along: 100) }; continue }
    // An expert also whips a menace or brute off the line for points.
    if expert, g.players[0].snapLeft <= 0, r.unit() < 0.3, g.villains.contains(where: { $0.solid && $0.tier != .doom && abs((g.vertical ? $0.x : $0.y) - g.hinge) < 100 }) { if duo { g.clap() } else { g.snap(along: 100) }; continue }
    // People only aim at what they can see: fogged and out-of-phase bubbles are skipped. In the dark they
    // can make out a faint outline, so they tap at it, which lights it for the next touch.
    var seen = dark ? g.bubbles : g.bubbles.filter { g.visibility($0) >= 0.4 && $0.presence >= 0.5 }
    // Villains they don't recognise look like any other bubble, so they may go for one.
    let unseen = g.villains.filter { $0.solid && !spots($0, &r) }
    if !blind {
      let foes = g.villains.filter { $0.solid }
      seen = seen.filter { b in !foes.contains { hypot($0.x - b.x, $0.y - b.y) < $0.r + b.r * 0.7 } || r.unit() > wary }
    }
    let lure = blind ? g.villains.filter { $0.solid } : unseen
    guard !seen.isEmpty || !lure.isEmpty else { continue }
    if !lure.isEmpty, r.unit() < Double(lure.count) / Double(lure.count + max(1, seen.count)) * (blind ? 1 : 0.5) {
      let v = lure[r.int(lure.count)]
      if blind || kind == "slicer" {
        let a = r.unit() * 6.283, len = 120 * g.scale
        var skip = Set<Int>()
        g.slice(fromX: v.x - cos(a) * len, fromY: v.y - sin(a) * len, toX: v.x + cos(a) * len, toY: v.y + sin(a) * len, skip: &skip)
      } else { g.strike(v) }
      continue
    }
    guard !seen.isEmpty else { continue }
    let target: Bubble = r.unit() < stray ? seen[r.int(seen.count)] : seen.min { timeToHinge(g, $0) < timeToHinge(g, $1) }!
    if blind {
      // Straight strokes through the target, whatever else is in the way.
      let a = r.unit() * 6.283, len = 120 * g.scale
      var skip = Set<Int>()
      g.slice(fromX: target.x - cos(a) * len, fromY: target.y - sin(a) * len, toX: target.x + cos(a) * len, toY: target.y + sin(a) * len, skip: &skip)
      g.illuminate(x: target.x, y: target.y)
    } else if kind == "slicer" {
      // A wary slicer picks a line that misses the villains.
      var a = r.unit() * 6.283
      let len = 120 * g.scale
      for _ in 0..<6 {
        let from = (target.x - cos(a) * len, target.y - sin(a) * len), to = (target.x + cos(a) * len, target.y + sin(a) * len)
        let blocked = g.villains.contains { v in
          guard v.solid else { return false }
          let dx = to.0 - from.0, dy = to.1 - from.1, t = max(0, min(1, ((v.x - from.0) * dx + (v.y - from.1) * dy) / (dx * dx + dy * dy)))
          return hypot(v.x - (from.0 + dx * t), v.y - (from.1 + dy * t)) <= v.r + 12
        }
        if !blocked || r.unit() > wary { break }
        a = r.unit() * 6.283
      }
      var skip = Set<Int>()
      let from = (target.x - cos(a) * len, target.y - sin(a) * len)
      g.slice(fromX: from.0, fromY: from.1, toX: target.x, toY: target.y, skip: &skip)
      g.illuminate(x: target.x, y: target.y)
      g.slice(fromX: target.x, fromY: target.y, toX: target.x + cos(a) * len, toY: target.y + sin(a) * len, skip: &skip)
    } else {
      touch(g, target, &r)
    }
  }
  if why { tally(g.events) }
  log.close(g)
  if why, g.status == .lost { reasonLock.lock(); reasons["lost-\(g.lostTo?.rawValue ?? "meter")", default: 0] += 1; reasonLock.unlock() }
  return g
}

/// A tap where a person would put it: on a shielded boss, the open side most of the time.
func touch(_ g: Game, _ b: Bubble, _ r: inout SplitMix) {
  let open = b.kind == .boss && r.unit() < 0.8 ? b.shieldAngle + .pi : r.unit() * 6.283
  let at = (b.x + cos(open) * b.r * 0.6, b.y + sin(open) * b.r * 0.6)
  // The finger lands where it lands: on a villain sitting over the bubble, that's who gets touched.
  if let v = g.hitVillain(x: at.0, y: at.1) { g.strike(v); return }
  g.tap(b, atX: at.0, atY: at.1)
  g.illuminate(x: b.x, y: b.y)
}

let allBots: [(String, Double)] = [("idle", 0), ("human", 1), ("human", 1.5), ("human", 2), ("human", 3), ("slicer", 1), ("slicer", 1.5), ("slicer", 2), ("expert", 3.5)]
func parseBots(_ s: String) -> [(String, Double)] {
  s.split(separator: ",").map { t in
    if t == "idle" { return ("idle", 0) }
    return (t.hasPrefix("s") ? "slicer" : t.hasPrefix("e") ? "expert" : t.hasPrefix("b") ? "blind" : "human", Double(t.dropFirst()) ?? 2)
  }
}
let ranged = option("--range")
let levels: [Int] = {
  if let ranged {
    let parts = ranged.split(separator: "-").compactMap { Int($0) }
    return parts.count == 2 ? Array(parts[0]...parts[1]) : parts
  }
  let given = argv.dropFirst().filter { !$0.hasPrefix("-") && Int($0) != nil && !["--runs", "--bots", "--seed-base", "--max-runs", "--heat", "--want", "--difficulty"].contains(argv[argv.firstIndex(of: $0)! - 1]) }.compactMap { Int($0) }
  return given.isEmpty ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 20, 21, 23, 25, 27, 29, 30, 31, 33, 35, 37, 39, 40, 41, 43, 45, 47, 49, 50, 55, 60, 75, 100, 150] : given
}()
let bots = option("--bots").map(parseBots) ?? (ranged != nil ? parseBots("idle,h2,e3.5") : allBots)
let runs = option("--runs").flatMap(Int.init) ?? (ranged != nil ? 16 : 40)
let quiet = argv.contains("--quiet")

/// Wins out of `count` runs from seed `from`+1, for one bot at one difficulty (and heat, when calibrating).
func wins(_ lv: Int, _ bot: (String, Double), from: UInt64, count: Int, _ d: Difficulty, heat: Double? = nil) -> Int {
  var w = 0
  for s in 1...max(1, count) where play(lv, kind: bot.0, rate: bot.1, seed: from + UInt64(s), difficulty: d, heat: heat).status == .won { w += 1 }
  return w
}
/// How many runs give about `want` Overdrive wins at a Normal win rate `p` (between `runs` and `--max-runs`).
let maxRuns = option("--max-runs").flatMap(Int.init) ?? 6000
func runsFor(_ p: Double, want: Double) -> Int { min(maxRuns, max(runs, Int((want / max(0.004, Overdrive.targetRatio * p)).rounded(.up)))) }

// Calibration: per level, bisect Overdrive's heat until h2 wins `targetRatio`× Normal's, on seeds of its own.
// Prints the table for `Overdrive.calibration`. Exits when done.
if argv.contains("--calibrate") {
  let h2 = ("human", 2.0), base: UInt64 = 1_000_000 + seedBase
  let want = Double(option("--want").flatMap(Int.init) ?? 120)
  var heats = [Double](repeating: 0, count: levels.count)
  var notes = [String](repeating: "", count: levels.count)
  let clock = Date()
  DispatchQueue.concurrentPerform(iterations: levels.count) { i in
    let lv = levels[i]
    let probe = wins(lv, h2, from: base, count: runs, .normal)
    let n = runsFor(Double(probe) / Double(runs), want: want)
    let normal = Double(probe + (n > runs ? wins(lv, h2, from: base + UInt64(runs), count: n - runs, .normal) : 0)) / Double(n)
    let target = Overdrive.targetRatio * normal
    let rate = { (h: Double, count: Int) in Double(wins(lv, h2, from: base, count: count, .overdrive, heat: h)) / Double(count) }
    // --grid: for levels whose win rate doesn't fall smoothly with pace (some bosses), scan heats on every run,
    // smooth over neighbours, and take the closest to the target.
    // --fine scans ±0.12 around the level's current heat in hundredths instead.
    if argv.contains("--grid") || argv.contains("--fine") {
      let fine = argv.contains("--fine"), now = Overdrive.heat(lv), w = fine ? 2 : 1
      let grid = fine ? stride(from: max(Overdrive.minHeat, now - 0.12), through: now + 0.12, by: 0.01).map { $0 } : stride(from: Overdrive.minHeat, through: 2.5, by: 0.06).map { $0 }
      let rates = grid.map { rate($0, n) }
      let smooth = rates.indices.map { j in rates[max(0, j - w)...min(rates.count - 1, j + w)].reduce(0, +) / Double(min(rates.count - 1, j + w) - max(0, j - w) + 1) }
      // --raw picks by the rate at the heat itself, for levels whose rate jumps between neighbouring heats.
      let pick = argv.contains("--raw") ? rates : smooth
      let best = pick.indices.min { abs(pick[$0] - target) < abs(pick[$1] - target) }!
      heats[i] = grid[best]
      notes[i] = String(format: "%d n%.3f target %.3f heat %.3f (smoothed %.3f, raw %.3f) runs %d", lv, normal, target, grid[best], smooth[best], rates[best], n)
      return
    }
    // Coarse: bracket and bisect on a sixth of the runs.
    let m = max(runs, n / 6)
    var lo = Overdrive.minHeat, hi = 0.5
    let floorRate = rate(lo, n)
    if floorRate <= target { heats[i] = lo; notes[i] = String(format: "%d n%.3f od%.3f (floor) runs %d", lv, normal, floorRate, n); return }
    while rate(hi, m) > target && hi < 2.5 { lo = hi; hi = min(2.55, hi * 1.6) }
    for _ in 0..<6 { let mid = (lo + hi) / 2; if rate(mid, m) > target { lo = mid } else { hi = mid } }
    // Fine: two full-run points either side, then interpolate in logit space and refine once.
    func logit(_ p: Double) -> Double { let q = min(0.995, max(0.002, p)); return log(q / (1 - q)) }
    let guess = (lo + hi) / 2
    var a = (h: max(Overdrive.minHeat, guess - 0.06), r: 0.0), b = (h: min(2.55, guess + 0.06), r: 0.0)
    a.r = rate(a.h, n); b.r = rate(b.h, n)
    func cross(_ a: (h: Double, r: Double), _ b: (h: Double, r: Double)) -> Double {
      let la = logit(a.r), lb = logit(b.r), lt = logit(target)
      guard abs(la - lb) > 1e-6 else { return (a.h + b.h) / 2 }
      return a.h + (lt - la) * (b.h - a.h) / (lb - la)
    }
    var h = min(2.55, max(Overdrive.minHeat, cross(a, b)))
    let c = (h: h, r: rate(h, n))
    // Keep the point that brackets best with the new one and interpolate again.
    let other = (c.r > target) == (a.r > target) ? b : a
    h = min(2.55, max(Overdrive.minHeat, cross(c, other)))
    heats[i] = h
    notes[i] = String(format: "%d n%.3f target %.3f heat %.3f (a %.2f:%.3f b %.2f:%.3f c %.2f:%.3f) runs %d", lv, normal, target, h, a.h, a.r, b.h, b.r, c.h, c.r, n)
  }
  if !quiet { notes.forEach { print($0) } }
  print("// calibrated \(levels.first!)-\(levels.last!) in \(Int(Date().timeIntervalSince(clock)))s")
  print(heats.map { String(min(255, max(0, Int(($0 * Overdrive.heatScale).rounded())))) }.joined(separator: ","))
  if argv.contains("--grid") || argv.contains("--fine") { print(zip(levels, heats).map { "\($0)=\(min(255, Int(($1 * Overdrive.heatScale).rounded())))" }.joined(separator: " ")) }
  exit(0)
}

// Ratio mode: Normal and Overdrive side by side. Exits when done.
if argv.contains("--ratio") {
  let h2 = ("human", 2.0), pro = ("expert", 3.5), want = Double(option("--want").flatMap(Int.init) ?? 150)
  struct R { var normal = 0.0, od = 0.0, pro = 0.0, proNormal = 0.0, idle = 0, runs = 0 }
  var out = [R](repeating: R(), count: levels.count)
  let rlock = NSLock()
  DispatchQueue.concurrentPerform(iterations: levels.count) { i in
    let lv = levels[i]
    let probe = wins(lv, h2, from: seedBase, count: runs, .normal)
    let n = runsFor(Double(probe) / Double(runs), want: want)
    var r = R()
    r.runs = n
    r.normal = Double(probe + (n > runs ? wins(lv, h2, from: seedBase + UInt64(runs), count: n - runs, .normal) : 0)) / Double(n)
    r.od = Double(wins(lv, h2, from: seedBase, count: n, .overdrive, heat: fixedHeat)) / Double(n)
    r.pro = Double(wins(lv, pro, from: seedBase, count: runs, .overdrive, heat: fixedHeat)) / Double(runs)
    r.proNormal = Double(wins(lv, pro, from: seedBase, count: runs, .normal)) / Double(runs)
    r.idle = wins(lv, ("idle", 0), from: seedBase, count: 4, .overdrive)
    rlock.lock(); out[i] = r; rlock.unlock()
  }
  let ratio = { (r: R) in r.normal > 0 ? r.od / r.normal : 0 }
  if !quiet {
    print("lv   normal-h2  overdrive-h2  ratio  e3.5-od  e3.5-n  runs")
    for (i, lv) in levels.enumerated() {
      let r = out[i]
      print(String(format: "%-4d %6.1f      %6.1f       %.2f   %5.1f    %5.1f  %d", lv, r.normal * 100, r.od * 100, ratio(r), r.pro * 100, r.proNormal * 100, r.runs))
    }
  }
  print("\nper realm          normal-h2  overdrive-h2  ratio  ratio-range  e3.5-od  e3.5-od-min")
  for realm in Worlds.realms {
    let idx = levels.indices.filter { Worlds.world(ofLevel: levels[$0])?.realm == realm.number }
    guard !idx.isEmpty else { continue }
    let rs = idx.map { out[$0] }
    let avg = { (f: (R) -> Double) in rs.map(f).reduce(0, +) / Double(rs.count) }
    let ratios = rs.map(ratio)
    print(String(format: "%2d %@  %6.1f      %6.1f       %.2f   %.2f-%.2f    %5.1f    %5.1f", realm.number, realm.name.padding(toLength: 14, withPad: " ", startingAt: 0), avg { $0.normal } * 100, avg { $0.od } * 100, avg(ratio), ratios.min()!, ratios.max()!, avg { $0.pro } * 100, rs.map(\.pro).min()! * 100))
  }
  let all = out.map(ratio)
  let worst = levels.indices.sorted { abs(all[$0] - Overdrive.targetRatio) > abs(all[$1] - Overdrive.targetRatio) }.prefix(8)
  print(String(format: "\nall: avg ratio %.3f, per-level %.2f-%.2f, outside 0.22-0.38: %d of %d, idle wins %d, e3.5-od zero on %d levels, below 30%% on %d",
               all.reduce(0, +) / Double(all.count), all.min()!, all.max()!, all.filter { $0 < 0.22 || $0 > 0.38 }.count, all.count, out.map(\.idle).reduce(0, +), out.filter { $0.pro == 0 }.count, out.filter { $0.pro < 0.3 }.count))
  print("furthest from target: " + worst.map { String(format: "%d:%.2f (n%.0f od%.1f)", levels[$0], all[$0], out[$0].normal * 100, out[$0].od * 100) }.joined(separator: "  "))
  exit(0)
}

// The meta table: how often bots earn each challenge and each grade. Exits when done.
if meta {
  let metaBots = option("--bots").map(parseBots) ?? parseBots("h2,h3,s2")
  var out = [String](repeating: "", count: levels.count)
  let mlock = NSLock()
  DispatchQueue.concurrentPerform(iterations: levels.count) { i in
    let lv = levels[i], spec = Campaign.level(lv, difficulty: difficulty), list = Challenges.for(level: lv), par = difficulty == .overdrive ? Par.score(spec, tuning: Overdrive.tuning(Tuning())) : Par.score(spec)
    var line = String(format: "%-4d w%-3d x%.2f par %-7d ", lv, Campaign.work(of: spec.spawns), spec.speed, par)
    for (kind, rate) in metaBots {
      var wins = 0, earned = [Int](repeating: 0, count: list.count), grades = [Int](repeating: 0, count: 5), ratio = 0.0, t = 0.0, extra = 0.0, combo = 0.0
      for s in 1...runs {
        var log = RunLog()
        _ = play(lv, kind: kind, rate: rate, seed: UInt64(s), log: &log)
        guard log.won else { continue }
        wins += 1; t += log.time; extra += Double(log.springs + log.warps); combo += log.bestCombo
        ratio += Double(log.score) / Double(par)
        for (j, ok) in Challenges.evaluate(list, log).enumerated() where ok { earned[j] += 1 }
        grades[Par.grade(score: log.score, par: par).rawValue] += 1
      }
      let pct = { (x: Int) in Int((Double(x) / Double(runs) * 100).rounded()) }
      line += "| \(label((kind, rate))) w\(pct(wins)) c\(earned.map { String(pct($0)) }.joined(separator: "/")) S\(pct(grades[4]))A\(pct(grades[3]))B\(pct(grades[2])) r\(String(format: "%.2f", wins > 0 ? ratio / Double(wins) : 0)) t\(Int(wins > 0 ? t / Double(wins) : 0)) x\(String(format: "%.1f", combo / Double(max(1, wins)))) sw\(Int(extra / Double(max(1, wins)))) "
    }
    line += " " + list.map(\.title).joined(separator: "; ")
    mlock.lock(); out[i] = line; mlock.unlock()
  }
  out.forEach { print($0) }
  exit(0)
}

struct Row { var wins: [Int]; var stuck = 0; var time = 0.0; var three = 0; var overtime = 0; var proThree = 0 }
var rows = [Row](repeating: Row(wins: []), count: levels.count)
let lock = NSLock()
DispatchQueue.concurrentPerform(iterations: levels.count) { i in
  let lv = levels[i]
  var row = Row(wins: [])
  for (kind, rate) in bots {
    var wins = 0
    for s in 1...runs {
      let g = play(lv, kind: kind, rate: rate, seed: seedBase + UInt64(s))
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
    let spec = Campaign.level(lv, difficulty: difficulty)
    let tw = spec.twists.map { String($0.rawValue.prefix(4)) }.joined(separator: "+")
    let text = "\(Campaign.work(of: spec.spawns))w \(spec.spawns.count)b \(String(format: "%.2f", spec.speed))x m\(spec.meterMax)\(spec.gates > 0 ? " g\(spec.gates)" : "")\(spec.isBoss ? " B\(spec.bossPhases)\(spec.boss.rawValue.prefix(3))" : "") \(tw)"
    let par = Game(mode: .campaign(lv), width: 390, height: 760, top: 70, difficulty: difficulty).overtimeAt
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
  let blindBot = bots.firstIndex { $0.0 == "blind" }
  func avg(_ xs: [Int]) -> String { xs.isEmpty ? "  -" : String(format: "%3.0f", Double(xs.reduce(0, +)) / Double(xs.count)) }
  print("\nper realm, \(label(bots[hi])) win%    k1   k2  k3-8   k9  boss  last-world  e:last  idle-max  worst-level" + (blindBot != nil ? "  blind(avg/max)" : ""))
  for realm in Worlds.realms {
    var first: [Int] = [], second: [Int] = [], mid: [Int] = [], nine: [Int] = [], boss: [Int] = [], last: [Int] = [], proLast: [Int] = [], idleMax = 0
    var worst = (lv: 0, win: 101)
    var blindWins: [Int] = []
    for (i, lv) in levels.enumerated() {
      guard let w = Worlds.world(ofLevel: lv), w.realm == realm.number else { continue }
      if let blindBot { blindWins.append(rows[i].wins[blindBot]) }
      let k = (lv - 1) % 10 + 1, win = rows[i].wins[hi]
      if let idle { idleMax = max(idleMax, rows[i].wins[idle]) }
      if w.number % 8 == 0 { last.append(win); if let pro { proLast.append(rows[i].wins[pro]) } }
      else if k == 1 { first.append(win) } else if k == 2 { second.append(win) } else if k <= 8 { mid.append(win) } else if k == 9 { nine.append(win) }
      if k == 10 { boss.append(win) }
      if win < worst.win { worst = (lv, win) }
    }
    guard !(first + second + mid + nine + boss + last).isEmpty else { continue }
    print(String(format: "%2d %@", realm.number, realm.name.padding(toLength: 14, withPad: " ", startingAt: 0)) + "     \(avg(first))  \(avg(second))  \(avg(mid))  \(avg(nine))   \(avg(boss))      \(avg(last))     \(avg(proLast))       \(String(format: "%3d", idleMax))       \(worst.lv):\(worst.win)" + (blindBot != nil ? "      \(avg(blindWins))/\(blindWins.max() ?? 0)" : ""))
  }
}
if why { print(reasons.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")) }
