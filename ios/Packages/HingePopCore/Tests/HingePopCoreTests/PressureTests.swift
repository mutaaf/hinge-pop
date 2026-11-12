import XCTest
@testable import HingePopCore

/// Overtime, fever, champions, surges, boss sheds and the star rule.
final class PressureTests: XCTestCase {
  func game(_ n: Int, _ t: Tuning = Tuning()) -> Game {
    let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70, tuning: t)
    g.ready = 0
    return g
  }

  /// Steps with everything held still and the shields topped up, so only the clock moves.
  func hold(_ g: Game, until done: (Game) -> Bool, limit: Double = 120, _ seen: ((GameEvent) -> Void)? = nil) {
    while !done(g) && g.time < limit && g.status == .playing {
      for b in g.bubbles { b.vx = 0; b.vy = 0 }
      g.step(1.0 / 60)
      for e in g.events { seen?(e) }
      g.events.removeAll()
      g.players[0].shields = g.tuning.shields; g.players[0].meter = 0
    }
  }

  func still() -> Tuning { var t = Tuning(); t.recover = [0, 0, 0, 0]; return t }

  // MARK: Overtime

  func testStallingPastParSpeedsEverythingUpStepByStep() {
    let t = still()
    let g = game(25, t)
    XCTAssertTrue(g.overtimeAt.isFinite)
    XCTAssertEqual(g.overtime, 0)
    XCTAssertEqual(g.overtimeIn, g.overtimeAt, accuracy: 0.001)
    XCTAssertEqual(g.overtimeSpeed, 1)
    let b = g.bubbles[0], calm = g.cruise(b)
    var steps: [Int] = []
    hold(g, until: { $0.time > $0.overtimeAt - 0.1 }) { e in if case .overtime(let s) = e { steps.append(s) } }
    XCTAssertEqual(steps, [], "nothing changes inside par")
    XCTAssertEqual(g.cruise(b), calm, accuracy: 1e-9)
    hold(g, until: { $0.time > $0.overtimeAt + t.overtimeEvery * Double(t.overtimeSteps + 1) }) { e in if case .overtime(let s) = e { steps.append(s) } }
    XCTAssertEqual(steps, Array(1...t.overtimeSteps), "one event per step, and it stops at the cap")
    XCTAssertEqual(g.overtime, t.overtimeSteps)
    XCTAssertEqual(g.overtimeIn, 0)
    XCTAssertEqual(g.cruise(b), calm * (1 + t.overtimeGain * Double(t.overtimeSteps)), accuracy: 1e-6)
    XCTAssertEqual(g.status, .playing, "overtime never ends a level by itself")
  }

  func testParGrowsWithTheWorkAndOnlyCampaignAndDailyHaveOne() {
    XCTAssertGreaterThan(game(29).overtimeAt, game(21).overtimeAt)
    XCTAssertGreaterThan(game(800).overtimeAt, game(10).overtimeAt, "a long boss gets a long par")
    XCTAssertTrue(Game(mode: .daily(year: 2026, month: 11, day: 11), width: 390, height: 760).overtimeAt.isFinite)
    for mode: GameMode in [.arcade(seed: 1), .versus, .sandbox] {
      let g = Game(mode: mode, width: 844, height: 390, top: 60)
      XCTAssertFalse(g.overtimeAt.isFinite, "\(mode)")
      XCTAssertEqual(g.overtimeIn, 0)
    }
  }

  // MARK: Fever

  func testAFullComboStartsAFeverThatPaysDoubleSlowsBubblesAndBurnsOut() {
    let t = Tuning()
    let g = game(25)
    g.clearScene()
    let anchor = g.add(.basic, size: 0, x: 100, y: 200, angle: 0, speed: 0)
    let calm = g.cruise(anchor)
    let first = g.add(.basic, size: 2, x: 200, y: 200, angle: 0, speed: 0)
    let second = g.add(.basic, size: 2, x: 300, y: 200, angle: 0, speed: 0)
    g.players[0].combo = t.comboMax - t.comboStep; g.players[0].comboT = 1
    XCTAssertEqual(g.feverLeft, 0)
    g.tap(first)
    XCTAssertTrue(g.events.contains(.feverStart(player: 0)))
    XCTAssertEqual(g.feverLeft, t.feverTime)
    XCTAssertEqual(g.players[0].fevers, 1)
    XCTAssertEqual(g.cruise(anchor), calm * t.feverSlow, accuracy: 1e-9, "bubbles slow during a fever")
    let before = g.players[0].score
    g.tap(second)
    XCTAssertEqual(g.players[0].score - before, Int((Double(t.points[2]) * t.comboMax * t.feverPoints).rounded()), "a fever pays double")
    // The combo holds through the fever, then it's spent.
    g.events.removeAll()
    var ended = false
    for _ in 0..<Int((t.feverTime + 0.5) * 60) where !ended {
      XCTAssertEqual(g.players[0].combo, t.comboMax)
      g.step(1.0 / 60)
      ended = g.events.contains(.feverEnd(player: 0))
      g.players[0].shields = 3; g.players[0].meter = 0
    }
    XCTAssertTrue(ended)
    XCTAssertEqual(g.feverLeft, 0)
    XCTAssertEqual(g.players[0].combo, 1)
    XCTAssertEqual(g.cruise(anchor), calm, accuracy: 1e-9)
  }

  func testACrossingPutsAFeverOut() {
    let g = game(25)
    g.clearScene()
    g.add(.basic, size: 0, x: 100, y: 120, angle: 0, speed: 0)
    let pop = g.add(.basic, size: 2, x: 200, y: 200, angle: 0, speed: 0)
    let runner = g.add(.basic, size: 1, x: 300, y: 200, angle: 0, speed: 0)
    g.players[0].combo = g.tuning.comboMax - g.tuning.comboStep; g.players[0].comboT = 1
    g.tap(pop)
    XCTAssertGreaterThan(g.feverLeft, 0)
    g.events.removeAll()
    runner.grace = 0
    runner.y = g.hinge - 1; runner.vy = 600
    g.step(1.0 / 60)
    XCTAssertTrue(g.events.contains(.feverEnd(player: 0)))
    XCTAssertEqual(g.feverLeft, 0)
    XCTAssertEqual(g.players[0].combo, 1)
  }

  func testPracticeNeverStartsAFever() {
    let g = Game(mode: .sandbox, width: 390, height: 760, top: 70)
    g.ready = 0
    let b = g.add(.basic, size: 2, x: 200, y: 200, angle: 0, speed: 0)
    g.add(.basic, size: 0, x: 100, y: 200, angle: 0, speed: 0)
    g.players[0].combo = g.tuning.comboMax
    g.tap(b)
    XCTAssertEqual(g.feverLeft, 0)
  }

  // MARK: Stars

  func testThreeStarsMeanNoShieldLostFewCrossingsAndInsidePar() {
    func clear(_ g: Game) { while let b = g.bubbles.first, g.status == .playing { g.tap(b) } }
    let fast = game(1)
    clear(fast)
    XCTAssertEqual(fast.stars, 3)

    let slow = game(1, still())
    hold(slow, until: { $0.overtime > 0 })
    XCTAssertEqual(slow.players[0].shieldsLost, 0)
    clear(slow)
    XCTAssertEqual(slow.status, .won)
    XCTAssertEqual(slow.stars, 2, "past par is no longer near-flawless")

    let bruised = game(1)
    bruised.players[0].shieldsLost = 1
    clear(bruised)
    XCTAssertEqual(bruised.stars, 2)

    let leaky = game(1)
    leaky.players[0].crossings = 3
    clear(leaky)
    XCTAssertEqual(leaky.stars, 2, "three crossings is not near-flawless")

    let battered = game(1)
    battered.players[0].shieldsLost = 2
    clear(battered)
    XCTAssertEqual(battered.stars, 1)
  }

  // MARK: Champions

  func testChampionsTakeAnExtraHitMoveFasterAndAreNeverBig() {
    for n in 1...800 {
      for s in Campaign.level(n).spawns where s.champion {
        XCTAssertNotEqual(s.size, 0, "level \(n): a big one is never crowned")
        XCTAssertNotEqual(s.kind, .boss)
      }
    }
    XCTAssertTrue((81...800).contains { Campaign.level($0).spawns.contains(where: \.champion) })
    XCTAssertTrue((11...80).contains { Campaign.level($0).spawns.contains(where: \.champion) }, "realm 1 has champions too")
    XCTAssertFalse((1...10).contains { Campaign.level($0).spawns.contains(where: \.champion) }, "but not while it's teaching")
    var plain = Campaign.level(57).spawns
    let crowned = plain.firstIndex(where: \.champion)!
    let weight = Campaign.work(of: plain)
    plain[crowned].champion = false
    XCTAssertEqual(Campaign.work(of: plain), weight - 1, "a crown is one more tap of work")

    guard let n = (81...800).first(where: { n in game(n).bubbles.contains(where: \.champion) }) else { return XCTFail("no champion on screen anywhere") }
    let g = game(n)
    let b = g.bubbles.first(where: \.champion)!
    let twin = g.add(b.kind, size: b.size, x: 50, y: 120, angle: 0, speed: 0)
    XCTAssertEqual(g.cruise(b), g.cruise(twin) * g.tuning.championSpeed, accuracy: 1e-6)
    let layers = b.armor
    XCTAssertEqual(layers, g.tuning.championArmor + (b.kind == .armored ? 1 : 0))
    let size = b.size
    for left in stride(from: layers - 1, through: 0, by: -1) {
      g.events.removeAll()
      g.tap(b)
      XCTAssertTrue(g.events.contains { if case .championCrack(_, _, _, _, let a) = $0 { a == left } else { false } })
      XCTAssertEqual(b.size, size, "a crack never changes its size")
    }
    g.tap(b)
    XCTAssertFalse(g.bubbles.contains { $0 === b }, "then it splits like any other")
  }

  // MARK: Surge

  func testASurgeIsAnnouncedThenLandsAndTheLevelWaitsForIt() {
    let n = 25
    let spec = Campaign.level(n)
    XCTAssertGreaterThan(spec.surge, 0)
    let g = game(n)
    XCTAssertGreaterThanOrEqual(g.bubblesToCome, spec.surge)
    var log: [GameEvent] = []
    var bigsAfterSurge = 0
    while g.status == .playing && g.time < 120 {
      if let b = g.bubbles.first(where: { g.canTouch($0) }) { g.tap(b) }
      g.step(1.0 / 60)
      log += g.events.filter {
        switch $0 { case .surgeWarning, .surge, .finished: true; default: false }
      }
      if log.contains(where: { if case .surge = $0 { true } else { false } }) {
        bigsAfterSurge = max(bigsAfterSurge, g.bubbles.filter { $0.size == 0 }.count)
      }
      g.events.removeAll()
      g.players[0].shields = 3
    }
    XCTAssertEqual(g.status, .won)
    XCTAssertEqual(log, [.surgeWarning(count: spec.surge), .surge(count: spec.surge), .finished], "warned, landed, and only then won")
    XCTAssertLessThanOrEqual(bigsAfterSurge, 2, "a surge only brings small ones")
  }

  func testASurgeWarnsBeforeItLands() {
    let g = game(25, still())
    // Clear everything but one big, so the arena thins and the surge is announced rather than rushed in.
    let keep = g.bubbles.first { $0.size == 0 }!
    var warnedAt: Double?, landedAt: Double?, arrived = 0
    while landedAt == nil && g.time < 90 && g.status == .playing {
      let ids = Set(g.bubbles.map(\.id))
      if warnedAt == nil, let b = g.bubbles.first(where: { $0 !== keep }) { g.tap(b) }
      for b in g.bubbles { b.vx = 0; b.vy = 0 }
      g.step(1.0 / 60)
      for e in g.events {
        if case .surgeWarning = e { warnedAt = g.time; XCTAssertGreaterThan(g.surgeIn, 0) }
        if case .surge = e { landedAt = g.time; arrived = g.bubbles.filter { !ids.contains($0.id) && $0.size == 2 }.count }
      }
      g.events.removeAll()
      g.players[0].shields = 3
    }
    XCTAssertNotNil(warnedAt)
    XCTAssertNotNil(landedAt)
    if let warnedAt, let landedAt { XCTAssertEqual(landedAt - warnedAt, g.tuning.surgeWarn, accuracy: 0.05) }
    XCTAssertEqual(g.surgeIn, 0)
    XCTAssertEqual(arrived, g.spec.surge)
  }

  // MARK: Bosses

  func testABossInItsLastPhaseShedsSmallPiecesTowardTheLine() {
    let g = game(10)
    let boss = g.bubbles.first { $0.kind == .boss }!
    var sheds = 0
    hold(g, until: { _ in false }, limit: 10) { e in if case .bossShed = e { sheds += 1 } }
    XCTAssertEqual(sheds, 0, "no sheds before the last phase")
    while boss.bossPhase < g.spec.bossPhases - 1 && g.time < 200 {
      g.step(g.tuning.bossGuard + 0.01); g.tap(boss)
      g.players[0].shields = 3; g.players[0].meter = 0
    }
    XCTAssertEqual(boss.bossPhase, g.spec.bossPhases - 1)
    let before = Set(g.bubbles.map(\.id))
    let start = g.time
    hold(g, until: { _ in false }, limit: start + g.tuning.bossShedEvery + 0.5) { e in if case .bossShed = e { sheds += 1 } }
    XCTAssertGreaterThanOrEqual(sheds, 1)
    let shed = g.bubbles.filter { !before.contains($0.id) && $0.kind == .basic }
    XCTAssertTrue(shed.allSatisfy { $0.size == 2 }, "only small pieces")
  }

  func testLaterRealmsBringLongerBossFights() {
    XCTAssertLessThan(game(90).bossHitsPerPhase, game(790).bossHitsPerPhase)
  }
}
