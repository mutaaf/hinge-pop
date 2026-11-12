import XCTest
@testable import HingePopCore

final class DifficultyTests: XCTestCase {
  func testOverdriveIsStrictlyHarderOnEveryLevel() {
    let tn = Tuning(), to = Overdrive.tuning(tn)
    XCTAssertLessThan(to.comboWindow, tn.comboWindow)
    XCTAssertLessThan(to.overtimeBase, tn.overtimeBase)
    XCTAssertGreaterThan(to.overtimeGain, tn.overtimeGain)
    XCTAssertGreaterThan(to.bossHitsPerPhase, tn.bossHitsPerPhase)
    for n in 1...Campaign.finalAuthored {
      let normal = Campaign.level(n), hot = Campaign.level(n, difficulty: .overdrive)
      XCTAssertEqual(hot, Campaign.level(n, difficulty: .overdrive), "level \(n) is deterministic")
      XCTAssertEqual(normal, Campaign.level(n, difficulty: .normal), "Normal is the level unchanged")
      XCTAssertGreaterThan(hot.speed, normal.speed, "level \(n) runs faster")
      XCTAssertLessThanOrEqual(hot.meterMax, normal.meterMax)
      XCTAssertGreaterThanOrEqual(Campaign.work(of: hot.spawns), Campaign.work(of: normal.spawns), "level \(n)")
      XCTAssertGreaterThanOrEqual(hot.spawns.filter(\.champion).count, normal.spawns.filter(\.champion).count)
      XCTAssertEqual(hot.isBoss, normal.isBoss)
      XCTAssertEqual(hot.twists, normal.twists)
      if !normal.isBoss { XCTAssertGreaterThan(hot.surge, normal.surge, "level \(n) has a bigger surge") }
      if normal.spawns.contains(where: { $0.size == 0 || $0.kind == .boss }) {
        XCTAssertTrue(hot.spawns.contains { $0.size == 0 || $0.kind == .boss }, "level \(n) still can't be won by watching")
      }
      if (Worlds.world(ofLevel: n)?.number ?? 1) == 1 { XCTAssertFalse(hot.spawns.contains(where: \.champion), "no crowns in world 1") }
      XCTAssertGreaterThan(Par.score(hot, tuning: to), 0)
    }
  }

  func testTheCalibrationCoversTheCampaign() {
    XCTAssertEqual(Overdrive.calibration.count, Campaign.finalAuthored)
    for n in 1...Campaign.finalAuthored { XCTAssertGreaterThanOrEqual(Overdrive.heat(n), Overdrive.minHeat) }
    XCTAssertGreaterThan(Overdrive.heat(5000), Overdrive.minHeat, "Infinity runs hot too")
  }

  func testOnlyTheCampaignRunsHot() {
    let hot = Game(mode: .campaign(12), width: 390, height: 760, top: 70, difficulty: .overdrive)
    XCTAssertEqual(hot.difficulty, .overdrive)
    XCTAssertEqual(hot.spec, Campaign.level(12, difficulty: .overdrive))
    XCTAssertLessThan(hot.tuning.comboWindow, Tuning().comboWindow)
    XCTAssertLessThan(hot.overtimeAt, .infinity)
    for mode: GameMode in [.arcade(seed: 3), .daily(year: 2026, month: 11, day: 12), .versus, .sandbox] {
      let g = Game(mode: mode, width: 390, height: 760, top: 70, difficulty: .overdrive)
      XCTAssertEqual(g.difficulty, .normal)
      XCTAssertEqual(g.tuning.comboWindow, Tuning().comboWindow)
    }
  }

  /// A quick, fixed-seed check that Overdrive lands near 70% fewer wins for a 2 taps/s player. The full
  /// 800-level sweep (`hp-balance --ratio --range 1-800`) is the source of truth; this catches a broken transform.
  func testOverdriveWinsAboutSeventyPercentLess() {
    let levels = [1, 3, 15, 42]
    var normal = 0, hot = 0
    for n in levels {
      for s in 1...60 {
        if Bot.play(n, seed: UInt64(s), .normal) { normal += 1 }
        if Bot.play(n, seed: UInt64(s), .overdrive) { hot += 1 }
      }
    }
    XCTAssertGreaterThan(normal, 0)
    let ratio = Double(hot) / Double(normal)
    XCTAssertGreaterThan(ratio, 0.18, "Overdrive wins \(hot) to Normal's \(normal)")
    XCTAssertLessThan(ratio, 0.45, "Overdrive wins \(hot) to Normal's \(normal)")
  }

  func testOldSavesLoadAsNormal() throws {
    var old = GameProgress()
    old.record(level: 1, stars: 2, score: 500)
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
    json.removeValue(forKey: "difficultyChoice")
    json.removeValue(forKey: "overdriveLog")
    var loaded = try JSONDecoder().decode(GameProgress.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertEqual(loaded.difficulty, .normal)
    XCTAssertFalse(loaded.clearedOnOverdrive(1))
    XCTAssertEqual(loaded.stars[1], 2)
    loaded.difficulty = .overdrive
    let back = try JSONDecoder().decode(GameProgress.self, from: JSONEncoder().encode(loaded))
    XCTAssertEqual(back.difficulty, .overdrive)
  }

  func testOverdriveClearsShareOneProgression() {
    var p = GameProgress()
    let news = p.record(level: 1, stars: 2, score: 900, grade: .b, earned: [true, false, false], difficulty: .overdrive)
    XCTAssertTrue(news.firstOverdrive)
    XCTAssertTrue(p.clearedOnOverdrive(1))
    XCTAssertEqual(p.unlocked, 2, "an Overdrive clear opens the next level like any other")
    XCTAssertEqual(p.stars[1], 2)
    XCTAssertEqual(p.grade(1), .b)
    let again = p.record(level: 1, stars: 1, score: 100, grade: .d, earned: [false, false, false], difficulty: .overdrive)
    XCTAssertFalse(again.firstOverdrive)
    p.record(level: 2, stars: 3, score: 900, grade: .a, earned: [false, false, false])
    XCTAssertFalse(p.clearedOnOverdrive(2))
    XCTAssertEqual(p.overdriveClears, 1)
  }
}

/// The 2 taps/s human from hp-balance, trimmed: 15% miss, a third of touches on a random bubble.
enum Bot {
  static func play(_ n: Int, seed: UInt64, _ d: Difficulty) -> Bool {
    var r = SplitMix(seed: seed)
    let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70, seed: seed, difficulty: d)
    var next = 0.8 + 0.4 * r.unit()
    while g.status == .playing && g.time < 300 {
      g.step(1.0 / 60)
      g.events.removeAll(keepingCapacity: true)
      guard g.status == .playing, g.ready <= 0, g.time >= next else { continue }
      next = g.time + 0.5 * (0.7 + r.unit() * 0.6)
      if r.unit() < 0.15 { continue }
      if let p = g.pickups.first, r.unit() < 0.5 { g.collect(p); continue }
      if let v = g.visitors.first(where: { $0.presence > 0.35 && $0.x > 0 && $0.x < g.w }), r.unit() < 0.25 { g.catchVisitor(v.id); continue }
      if let boss = g.bubbles.first(where: { $0.bossWindup > 0 }), r.unit() < 0.5 { touch(g, boss, &r); continue }
      if g.players[0].snapLeft <= 0, r.unit() < 0.33, g.bubbles.contains(where: { $0.size == 0 && $0.kind != .boss && abs($0.y - g.hinge) < 100 }) { g.snap(along: 100); continue }
      let seen = g.spec.has(.blackout) ? g.bubbles : g.bubbles.filter { g.visibility($0) >= 0.4 && $0.presence >= 0.5 }
      guard !seen.isEmpty else { continue }
      let target = r.unit() < 0.33 ? seen[r.int(seen.count)] : seen.min { eta(g, $0) < eta(g, $1) }!
      touch(g, target, &r)
    }
    return g.status == .won
  }
  static func eta(_ g: Game, _ b: Bubble) -> Double {
    let gap = g.hinge - b.y
    return gap * b.vy > 0 ? gap / b.vy : .infinity
  }
  static func touch(_ g: Game, _ b: Bubble, _ r: inout SplitMix) {
    let open = b.kind == .boss && r.unit() < 0.8 ? b.shieldAngle + .pi : r.unit() * 6.283
    g.tap(b, atX: b.x + cos(open) * b.r * 0.6, atY: b.y + sin(open) * b.r * 0.6)
    g.illuminate(x: b.x, y: b.y)
  }
}
